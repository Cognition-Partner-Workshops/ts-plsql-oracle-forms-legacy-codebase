package services

import (
	"encoding/csv"
	"fmt"
	"io"
	"strconv"
	"strings"
	"time"

	"github.com/Cognition-Partner-Workshops/ts-plsql-oracle-forms-legacy-codebase/go-backend/internal/models"
	"gorm.io/gorm"
)

// IntegrationService migrates PKG_INTEGRATION — GL journal, benefits feed, time import.
type IntegrationService struct {
	db     *gorm.DB
	audit  *AuditService
	common *CommonService
}

// NewIntegrationService creates a new IntegrationService.
func NewIntegrationService(db *gorm.DB, audit *AuditService, common *CommonService) *IntegrationService {
	return &IntegrationService{db: db, audit: audit, common: common}
}

// GLJournalEntry represents a general ledger journal entry.
type GLJournalEntry struct {
	AccountCode  string  `json:"account_code"`
	DeptCode     string  `json:"dept_code"`
	DebitAmount  float64 `json:"debit_amount"`
	CreditAmount float64 `json:"credit_amount"`
	Description  string  `json:"description"`
	Reference    string  `json:"reference"`
}

// GenerateGLJournal produces GL journal entries from a payroll run.
// Mirrors: PKG_INTEGRATION.generate_gl_journal
func (s *IntegrationService) GenerateGLJournal(runID int64) ([]GLJournalEntry, error) {
	var entries []GLJournalEntry

	// Get payroll details grouped by department and element
	type row struct {
		DeptCode    string
		GLAccount   string
		ElementType string
		Total       float64
	}
	var rows []row

	err := s.db.Table("payroll_details pd").
		Select(`COALESCE(d.cost_center, CAST(d.dept_id AS TEXT)) as dept_code,
			COALESCE(pe.gl_account_code, 'DEFAULT') as gl_account,
			pd.element_type,
			SUM(pd.amount) as total`).
		Joins("JOIN employees e ON pd.emp_id = e.emp_id").
		Joins("JOIN departments d ON e.dept_id = d.dept_id").
		Joins("LEFT JOIN pay_elements pe ON pd.element_id = pe.element_id").
		Where("pd.run_id = ? AND pd.status != 'ERROR'", runID).
		Group("d.cost_center, d.dept_id, pe.gl_account_code, pd.element_type").
		Find(&rows).Error
	if err != nil {
		return nil, err
	}

	for _, r := range rows {
		entry := GLJournalEntry{
			AccountCode: r.GLAccount,
			DeptCode:    r.DeptCode,
			Reference:   fmt.Sprintf("PR-%d", runID),
		}
		if r.Total >= 0 {
			entry.DebitAmount = r.Total
			entry.Description = fmt.Sprintf("Payroll %s - Dept %s", r.ElementType, r.DeptCode)
		} else {
			entry.CreditAmount = -r.Total
			entry.Description = fmt.Sprintf("Payroll %s - Dept %s", r.ElementType, r.DeptCode)
		}
		entries = append(entries, entry)
	}

	return entries, nil
}

// ExportGLJournalCSV returns GL journal entries as CSV string.
// Mirrors: PKG_INTEGRATION.export_gl_file (replaced UTL_FILE with CSV generation)
func (s *IntegrationService) ExportGLJournalCSV(runID int64) (string, error) {
	entries, err := s.GenerateGLJournal(runID)
	if err != nil {
		return "", err
	}

	var buf strings.Builder
	writer := csv.NewWriter(&buf)
	_ = writer.Write([]string{"AccountCode", "DeptCode", "DebitAmount", "CreditAmount", "Description", "Reference"})

	for _, e := range entries {
		_ = writer.Write([]string{
			e.AccountCode,
			e.DeptCode,
			fmt.Sprintf("%.2f", e.DebitAmount),
			fmt.Sprintf("%.2f", e.CreditAmount),
			e.Description,
			e.Reference,
		})
	}
	writer.Flush()
	return buf.String(), nil
}

// BenefitsExportRow represents one row in the benefits feed.
type BenefitsExportRow struct {
	EmpNumber     string  `json:"emp_number"`
	SSN           string  `json:"ssn"`
	FirstName     string  `json:"first_name"`
	LastName      string  `json:"last_name"`
	DateOfBirth   string  `json:"date_of_birth"`
	HireDate      string  `json:"hire_date"`
	EmployeeType  string  `json:"employee_type"`
	DeptCode      string  `json:"dept_code"`
	Salary        float64 `json:"salary"`
	DependentCount int    `json:"dependent_count"`
}

// GenerateBenefitsFeed exports benefits enrollment data.
// Mirrors: PKG_INTEGRATION.generate_benefits_feed (replaced ADP-specific format with JSON/CSV)
func (s *IntegrationService) GenerateBenefitsFeed() ([]BenefitsExportRow, error) {
	var rows []BenefitsExportRow

	err := s.db.Table("employees e").
		Select(`e.emp_number, COALESCE(e.ssn_encrypted, '') as ssn,
			e.first_name, e.last_name,
			COALESCE(e.date_of_birth, '') as date_of_birth,
			e.hire_date, e.employment_type,
			COALESCE(d.cost_center, CAST(d.dept_id AS TEXT)) as dept_code,
			COALESCE(sr.base_salary, 0) as salary,
			(SELECT COUNT(*) FROM employee_dependents ed WHERE ed.emp_id = e.emp_id AND ed.active_flag = 'Y') as dependent_count`).
		Joins("JOIN departments d ON e.dept_id = d.dept_id").
		Joins("LEFT JOIN salary_records sr ON e.emp_id = sr.emp_id AND sr.active_flag = 'Y'").
		Where("e.employment_status = 'ACTIVE'").
		Order("e.last_name, e.first_name").
		Find(&rows).Error

	return rows, err
}

// TimeImportRecord represents a time entry to be imported.
type TimeImportRecord struct {
	EmpNumber string  `json:"emp_number"`
	WorkDate  string  `json:"work_date"`
	Hours     float64 `json:"hours"`
	PayCode   string  `json:"pay_code"`
}

// ImportTimeRecords processes imported time records from CSV data.
// Mirrors: PKG_INTEGRATION.import_time_records (replaced UTL_FILE with CSV reader)
func (s *IntegrationService) ImportTimeRecords(csvData io.Reader, user string) (int, int, error) {
	reader := csv.NewReader(csvData)
	// Skip header
	if _, err := reader.Read(); err != nil {
		return 0, 0, fmt.Errorf("failed to read CSV header: %w", err)
	}

	imported := 0
	errCount := 0

	for {
		record, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			errCount++
			continue
		}

		if len(record) < 4 {
			errCount++
			continue
		}

		rec := TimeImportRecord{
			EmpNumber: strings.TrimSpace(record[0]),
			WorkDate:  strings.TrimSpace(record[1]),
			PayCode:   strings.TrimSpace(record[3]),
		}
		hours, err := strconv.ParseFloat(strings.TrimSpace(record[2]), 64)
		if err != nil {
			errCount++
			continue
		}
		rec.Hours = hours

		// Find employee
		var emp models.Employee
		if err := s.db.Where("emp_number = ? AND employment_status = 'ACTIVE'", rec.EmpNumber).First(&emp).Error; err != nil {
			errCount++
			continue
		}

		// Find or create pay element
		var element models.PayElement
		if err := s.db.Where("element_code = ?", rec.PayCode).First(&element).Error; err != nil {
			errCount++
			continue
		}

		// Parse date
		workDate, err := time.Parse("2006-01-02", rec.WorkDate)
		if err != nil {
			errCount++
			continue
		}

		// Create employee pay element record
		amount := rec.Hours * 0 // hours-based; actual rate comes from salary
		empElement := models.EmployeePayElement{
			EmpID:         emp.EmpID,
			ElementID:     element.ElementID,
			Amount:        &amount,
			EffectiveDate: workDate,
			SoftDelete:    models.SoftDelete{ActiveFlag: "Y"},
			BaseModel:     models.BaseModel{CreatedBy: user},
		}
		if err := s.db.Create(&empElement).Error; err != nil {
			errCount++
			continue
		}
		imported++
	}

	return imported, errCount, nil
}
