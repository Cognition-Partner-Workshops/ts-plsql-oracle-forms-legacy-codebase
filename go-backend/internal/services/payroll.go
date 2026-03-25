package services

import (
	"errors"
	"fmt"
	"math"
	"time"

	"github.com/Cognition-Partner-Workshops/ts-plsql-oracle-forms-legacy-codebase/go-backend/internal/models"
	"gorm.io/gorm"
)

// PayrollService migrates PKG_PAYROLL — salary management, tax calculations, pay runs.
type PayrollService struct {
	db           *gorm.DB
	audit        *AuditService
	notification *NotificationService
}

// Payroll constants (migrated from PKG_PAYROLL package body constants).
const (
	SSWageBase2024          = 168600.00
	SSRate                  = 0.062
	MedicareRateBase        = 0.0145
	MedicareRateAdditional  = 0.009
	MedicareThreshold       = 200000.00
	StandardDeductionSingle = 14600.00
	StandardDeductionMFJ    = 29200.00
	AllowanceAmount         = 4300.00
)

// NewPayrollService creates a new PayrollService.
func NewPayrollService(db *gorm.DB, audit *AuditService, notification *NotificationService) *PayrollService {
	return &PayrollService{
		db:           db,
		audit:        audit,
		notification: notification,
	}
}

// CreateSalaryRecord creates a new salary record, ending the previous active one.
// Mirrors: PKG_PAYROLL.create_salary_record
func (s *PayrollService) CreateSalaryRecord(empID int64, effectiveDate time.Time, baseSalary float64, reason, user string) (int64, error) {
	var salaryID int64
	err := s.db.Transaction(func(tx *gorm.DB) error {
		// End previous active salary record
		now := time.Now()
		tx.Model(&models.SalaryRecord{}).
			Where("emp_id = ? AND active_flag = 'Y'", empID).
			Updates(map[string]interface{}{
				"end_date":      effectiveDate,
				"active_flag":   "N",
				"modified_by":   user,
				"modified_date": now,
			})

		// Create new salary record
		salary := models.SalaryRecord{
			EmpID:         empID,
			EffectiveDate: effectiveDate,
			BaseSalary:    baseSalary,
			CurrencyCode:  "USD",
			PayFrequency:  "MONTHLY",
			SalaryBasis:   "ANNUAL",
			ChangeReason:  &reason,
			SoftDelete:    models.SoftDelete{ActiveFlag: "Y"},
			BaseModel:     models.BaseModel{CreatedBy: user},
		}
		if err := tx.Create(&salary).Error; err != nil {
			return err
		}
		salaryID = salary.SalaryID

		_ = s.audit.LogAction("SALARY_RECORDS", salaryID, "INSERT", user)
		return nil
	})
	return salaryID, err
}

// GetCurrentSalary returns the current active salary for an employee.
// Mirrors: PKG_PAYROLL.get_current_salary
func (s *PayrollService) GetCurrentSalary(empID int64) (float64, error) {
	var salary models.SalaryRecord
	err := s.db.Where("emp_id = ? AND active_flag = 'Y'", empID).First(&salary).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return 0, nil
		}
		return 0, err
	}
	return salary.BaseSalary, nil
}

// GetSalaryAsOf returns the salary as of a specific date.
// Mirrors: PKG_PAYROLL.get_salary_as_of
func (s *PayrollService) GetSalaryAsOf(empID int64, asOfDate time.Time) (float64, error) {
	var salary models.SalaryRecord
	err := s.db.Where("emp_id = ? AND effective_date <= ? AND (end_date IS NULL OR end_date >= ?)",
		empID, asOfDate, asOfDate).
		Order("effective_date DESC").
		First(&salary).Error
	if err != nil {
		return 0, err
	}
	return salary.BaseSalary, nil
}

// CreatePayPeriods generates pay periods for a year.
// Mirrors: PKG_PAYROLL.create_pay_periods (MONTHLY or BIWEEKLY)
func (s *PayrollService) CreatePayPeriods(year int, frequency, user string) (int, error) {
	count := 0
	if frequency == "MONTHLY" {
		for month := 1; month <= 12; month++ {
			startDate := time.Date(year, time.Month(month), 1, 0, 0, 0, 0, time.UTC)
			endDate := startDate.AddDate(0, 1, -1)
			payDate := endDate

			period := models.PayPeriod{
				PeriodName:      fmt.Sprintf("%s %d", startDate.Month().String(), year),
				PayFrequency:    frequency,
				PeriodStartDate: startDate,
				PeriodEndDate:   endDate,
				PayDate:         payDate,
				Status:          "OPEN",
				BaseModel:       models.BaseModel{CreatedBy: user},
			}
			if err := s.db.Create(&period).Error; err != nil {
				return count, err
			}
			count++
		}
	} else if frequency == "BIWEEKLY" {
		startDate := time.Date(year, 1, 1, 0, 0, 0, 0, time.UTC)
		// Find first Friday
		for startDate.Weekday() != time.Friday {
			startDate = startDate.AddDate(0, 0, 1)
		}
		startDate = startDate.AddDate(0, 0, -13) // Go back to start of biweekly period

		for startDate.Year() <= year {
			endDate := startDate.AddDate(0, 0, 13)
			payDate := endDate.AddDate(0, 0, 5) // Pay 5 days after period end

			if endDate.Year() > year {
				break
			}

			period := models.PayPeriod{
				PeriodName:      fmt.Sprintf("BW %s - %s", startDate.Format("Jan 02"), endDate.Format("Jan 02")),
				PayFrequency:    frequency,
				PeriodStartDate: startDate,
				PeriodEndDate:   endDate,
				PayDate:         payDate,
				Status:          "OPEN",
				BaseModel:       models.BaseModel{CreatedBy: user},
			}
			if err := s.db.Create(&period).Error; err != nil {
				return count, err
			}
			count++
			startDate = endDate.AddDate(0, 0, 1)
		}
	}
	return count, nil
}

// CreatePayrollRun creates a new payroll run for a pay period.
// Mirrors: PKG_PAYROLL.create_payroll_run
func (s *PayrollService) CreatePayrollRun(periodID int64, runType, user string) (int64, error) {
	run := models.PayrollRun{
		PeriodID:      periodID,
		RunType:       runType,
		RunDate:       time.Now(),
		Status:        "PENDING",
		SubmittedBy:   &user,
		SubmittedDate: timePtr(time.Now()),
		BaseModel:     models.BaseModel{CreatedBy: user},
	}
	if err := s.db.Create(&run).Error; err != nil {
		return 0, err
	}
	return run.RunID, nil
}

// CalculatePayroll processes payroll for all active employees in a run.
// Mirrors: PKG_PAYROLL.calculate_payroll
func (s *PayrollService) CalculatePayroll(runID int64, user string) error {
	return s.db.Transaction(func(tx *gorm.DB) error {
		var run models.PayrollRun
		if err := tx.Preload("Period").Where("run_id = ?", runID).First(&run).Error; err != nil {
			return err
		}

		if run.Status != "PENDING" {
			return errors.New("payroll run must be in PENDING status")
		}

		// Update status to PROCESSING
		tx.Model(&run).Update("status", "PROCESSING")

		// Get all active employees
		var employees []models.Employee
		tx.Where("employment_status = 'ACTIVE'").Find(&employees)

		empCount := 0
		errCount := 0
		totalGross := 0.0
		totalDeductions := 0.0
		totalNet := 0.0

		for _, emp := range employees {
			gross, deductions, net, err := s.calculateEmployeePay(tx, runID, emp.EmpID, run.Period, user)
			if err != nil {
				errCount++
				continue
			}
			empCount++
			totalGross += gross
			totalDeductions += deductions
			totalNet += net
		}

		// Update run totals
		tx.Model(&run).Updates(map[string]interface{}{
			"status":           "CALCULATED",
			"employee_count":   empCount,
			"error_count":      errCount,
			"total_gross":      math.Round(totalGross*100) / 100,
			"total_deductions": math.Round(totalDeductions*100) / 100,
			"total_net":        math.Round(totalNet*100) / 100,
			"modified_by":      user,
			"modified_date":    time.Now(),
		})

		_ = s.audit.LogAction("PAYROLL_RUNS", runID, "CALCULATE", user)
		return nil
	})
}

// calculateEmployeePay calculates pay for a single employee.
// Mirrors: PKG_PAYROLL.calculate_employee_pay
func (s *PayrollService) calculateEmployeePay(tx *gorm.DB, runID, empID int64, period *models.PayPeriod, user string) (gross, deductions, net float64, err error) {
	if period == nil {
		return 0, 0, 0, errors.New("pay period is nil")
	}

	// Get current salary
	var salary models.SalaryRecord
	if err := tx.Where("emp_id = ? AND active_flag = 'Y'", empID).First(&salary).Error; err != nil {
		return 0, 0, 0, fmt.Errorf("no active salary for employee %d", empID)
	}

	// Calculate gross pay (monthly = annual / 12)
	grossPay := salary.BaseSalary / 12.0

	// Add earnings detail
	s.addPayrollDetail(tx, runID, empID, 1, "EARNING", grossPay, user) // Base pay element ID=1

	// Get tax info
	var taxInfo models.EmployeeTaxInfo
	taxYear := period.PeriodEndDate.Year()
	if err := tx.Where("emp_id = ? AND tax_year = ? AND active_flag = 'Y'", empID, taxYear).First(&taxInfo).Error; err != nil {
		// Default tax info
		taxInfo = models.EmployeeTaxInfo{
			FilingStatus:      "SINGLE",
			FederalAllowances: 1,
		}
	}

	// Get YTD earnings
	ytdEarnings := s.getYTDEarnings(tx, empID, taxYear)

	// Calculate federal tax
	annualSalary := salary.BaseSalary
	federalTax := s.CalculateFederalTax(annualSalary, taxInfo.FilingStatus, taxInfo.FederalAllowances) / 12.0
	s.addPayrollDetail(tx, runID, empID, 100, "TAX", -federalTax, user)

	// Calculate state tax
	stateCode := "NY" // default
	if taxInfo.StateCode != nil {
		stateCode = *taxInfo.StateCode
	}
	stateTax := s.CalculateStateTax(annualSalary, stateCode) / 12.0
	s.addPayrollDetail(tx, runID, empID, 101, "TAX", -stateTax, user)

	// Calculate FICA (Social Security)
	ficaTax := s.CalculateFICA(grossPay, ytdEarnings)
	s.addPayrollDetail(tx, runID, empID, 102, "TAX", -ficaTax, user)

	// Calculate Medicare
	medicareTax := s.CalculateMedicare(grossPay, ytdEarnings)
	s.addPayrollDetail(tx, runID, empID, 103, "TAX", -medicareTax, user)

	// Process employee-specific deductions/benefits
	var empElements []models.EmployeePayElement
	tx.Preload("PayElement").
		Where("emp_id = ? AND active_flag = 'Y' AND effective_date <= ? AND (end_date IS NULL OR end_date >= ?)",
			empID, period.PeriodEndDate, period.PeriodStartDate).
		Find(&empElements)

	otherDeductions := 0.0
	for _, elem := range empElements {
		if elem.PayElement == nil {
			continue
		}
		pe := elem.PayElement
		if pe.ElementType == "DEDUCTION" || pe.ElementType == "BENEFIT" {
			var deductionAmt float64
			if elem.OverrideAmount != nil {
				deductionAmt = *elem.OverrideAmount
			} else if elem.Amount != nil {
				deductionAmt = *elem.Amount
			} else if elem.Percentage != nil {
				deductionAmt = grossPay * (*elem.Percentage / 100.0)
			} else if pe.DefaultAmount != nil {
				deductionAmt = *pe.DefaultAmount
			} else if pe.DefaultPct != nil {
				deductionAmt = grossPay * (*pe.DefaultPct / 100.0)
			}
			if deductionAmt > 0 {
				s.addPayrollDetail(tx, runID, empID, pe.ElementID, pe.ElementType, -deductionAmt, user)
				otherDeductions += deductionAmt
			}
		}
	}

	totalDeductions := federalTax + stateTax + ficaTax + medicareTax + otherDeductions
	netPay := grossPay - totalDeductions

	return grossPay, totalDeductions, netPay, nil
}

// addPayrollDetail inserts a payroll detail record.
func (s *PayrollService) addPayrollDetail(tx *gorm.DB, runID, empID, elementID int64, elementType string, amount float64, user string) {
	detail := models.PayrollDetail{
		RunID:       runID,
		EmpID:       empID,
		ElementID:   elementID,
		ElementType: elementType,
		Amount:      math.Round(amount*100) / 100,
		Status:      "CALCULATED",
		BaseModel:   models.BaseModel{CreatedBy: user},
	}
	tx.Create(&detail)
}

// getYTDEarnings returns year-to-date earnings for an employee.
// Mirrors: PKG_PAYROLL.get_ytd_earnings
func (s *PayrollService) getYTDEarnings(tx *gorm.DB, empID int64, taxYear int) float64 {
	var total float64
	startOfYear := time.Date(taxYear, 1, 1, 0, 0, 0, 0, time.UTC)
	endOfYear := time.Date(taxYear, 12, 31, 23, 59, 59, 0, time.UTC)

	tx.Model(&models.PayrollDetail{}).
		Select("COALESCE(SUM(amount), 0)").
		Joins("JOIN payroll_runs ON payroll_details.run_id = payroll_runs.run_id").
		Joins("JOIN pay_periods ON payroll_runs.period_id = pay_periods.period_id").
		Where("payroll_details.emp_id = ? AND payroll_details.element_type = 'EARNING' AND pay_periods.period_end_date BETWEEN ? AND ?",
			empID, startOfYear, endOfYear).
		Scan(&total)
	return total
}

// CalculateFederalTax computes annual federal income tax using 2024 brackets.
// Mirrors: PKG_PAYROLL.calculate_federal_tax
func (s *PayrollService) CalculateFederalTax(annualSalary float64, filingStatus string, allowances int) float64 {
	// Standard deduction
	standardDeduction := StandardDeductionSingle
	if filingStatus == "MARRIED_JOINT" || filingStatus == "MARRIED_FILING_JOINTLY" {
		standardDeduction = StandardDeductionMFJ
	}

	// Allowance deduction
	allowanceDeduction := float64(allowances) * AllowanceAmount
	taxableIncome := annualSalary - standardDeduction - allowanceDeduction
	if taxableIncome <= 0 {
		return 0
	}

	// 2024 Federal tax brackets
	type bracket struct {
		min, max, rate, baseTax float64
	}

	var brackets []bracket
	if filingStatus == "MARRIED_JOINT" || filingStatus == "MARRIED_FILING_JOINTLY" {
		brackets = []bracket{
			{0, 23200, 0.10, 0},
			{23200, 94300, 0.12, 2320},
			{94300, 201050, 0.22, 10852},
			{201050, 383900, 0.24, 34337},
			{383900, 487450, 0.32, 78221},
			{487450, 731200, 0.35, 111357},
			{731200, math.MaxFloat64, 0.37, 196670},
		}
	} else {
		brackets = []bracket{
			{0, 11600, 0.10, 0},
			{11600, 47150, 0.12, 1160},
			{47150, 100525, 0.22, 5426},
			{100525, 191950, 0.24, 17169},
			{191950, 243725, 0.32, 39111},
			{243725, 609350, 0.35, 55679},
			{609350, math.MaxFloat64, 0.37, 183648},
		}
	}

	for _, b := range brackets {
		if taxableIncome > b.min && taxableIncome <= b.max {
			return b.baseTax + (taxableIncome-b.min)*b.rate
		}
	}

	// Above highest bracket
	last := brackets[len(brackets)-1]
	return last.baseTax + (taxableIncome-last.min)*last.rate
}

// CalculateStateTax computes state income tax (flat rates by state).
// Mirrors: PKG_PAYROLL.calculate_state_tax
func (s *PayrollService) CalculateStateTax(annualSalary float64, stateCode string) float64 {
	stateRates := map[string]float64{
		"CA": 0.0930, "NY": 0.0685, "NJ": 0.0637, "TX": 0.0000,
		"FL": 0.0000, "IL": 0.0495, "PA": 0.0307, "OH": 0.0400,
		"MA": 0.0500, "WA": 0.0000, "CT": 0.0699, "GA": 0.0549,
		"NC": 0.0525, "VA": 0.0575, "MD": 0.0575, "MI": 0.0425,
		"CO": 0.0440, "AZ": 0.0259, "MN": 0.0985, "OR": 0.0990,
	}

	rate, ok := stateRates[stateCode]
	if !ok {
		rate = 0.05 // default 5%
	}
	return annualSalary * rate
}

// CalculateFICA computes Social Security tax with wage base cap.
// Mirrors: PKG_PAYROLL.calculate_fica
func (s *PayrollService) CalculateFICA(periodEarnings, ytdEarnings float64) float64 {
	if ytdEarnings >= SSWageBase2024 {
		return 0 // Already hit the cap
	}
	taxableEarnings := periodEarnings
	if ytdEarnings+periodEarnings > SSWageBase2024 {
		taxableEarnings = SSWageBase2024 - ytdEarnings
	}
	return math.Round(taxableEarnings*SSRate*100) / 100
}

// CalculateMedicare computes Medicare tax (base + additional above threshold).
// Mirrors: PKG_PAYROLL.calculate_medicare
func (s *PayrollService) CalculateMedicare(periodEarnings, ytdEarnings float64) float64 {
	baseTax := periodEarnings * MedicareRateBase
	additionalTax := 0.0

	if ytdEarnings+periodEarnings > MedicareThreshold {
		excessEarnings := periodEarnings
		if ytdEarnings < MedicareThreshold {
			excessEarnings = (ytdEarnings + periodEarnings) - MedicareThreshold
		}
		additionalTax = excessEarnings * MedicareRateAdditional
	}

	return math.Round((baseTax+additionalTax)*100) / 100
}

// ApprovePayroll marks a payroll run as approved.
// Mirrors: PKG_PAYROLL.approve_payroll
func (s *PayrollService) ApprovePayroll(runID int64, user string) error {
	now := time.Now()
	result := s.db.Model(&models.PayrollRun{}).
		Where("run_id = ? AND status = 'CALCULATED'", runID).
		Updates(map[string]interface{}{
			"status":        "APPROVED",
			"approved_by":   user,
			"approved_date": now,
			"modified_by":   user,
			"modified_date": now,
		})
	if result.RowsAffected == 0 {
		return errors.New("payroll run not found or not in CALCULATED status")
	}
	_ = s.audit.LogAction("PAYROLL_RUNS", runID, "APPROVE", user)
	return result.Error
}

// ReversePayroll marks a payroll run as reversed.
// Mirrors: PKG_PAYROLL.reverse_payroll
func (s *PayrollService) ReversePayroll(runID int64, user string) error {
	result := s.db.Model(&models.PayrollRun{}).
		Where("run_id = ? AND status IN ('CALCULATED', 'APPROVED')", runID).
		Updates(map[string]interface{}{
			"status":        "REVERSED",
			"modified_by":   user,
			"modified_date": time.Now(),
		})
	if result.RowsAffected == 0 {
		return errors.New("payroll run not found or cannot be reversed")
	}
	_ = s.audit.LogAction("PAYROLL_RUNS", runID, "REVERSE", user)
	return result.Error
}

// GetPayslip returns payroll details for an employee in a specific run.
// Mirrors: PKG_PAYROLL.get_payslip
func (s *PayrollService) GetPayslip(runID, empID int64) ([]models.PayrollDetail, error) {
	var details []models.PayrollDetail
	err := s.db.Where("run_id = ? AND emp_id = ? AND status != 'ERROR'", runID, empID).
		Order("element_type, element_id").
		Find(&details).Error
	return details, err
}

// GetYTDEarnings returns year-to-date earnings for an employee.
// Mirrors: PKG_PAYROLL.get_ytd_earnings (public version)
func (s *PayrollService) GetYTDEarnings(empID int64, taxYear int) float64 {
	return s.getYTDEarnings(s.db, empID, taxYear)
}

// ClosePayPeriod marks a pay period as closed.
// Mirrors: PKG_PAYROLL.close_pay_period
func (s *PayrollService) ClosePayPeriod(periodID int64, user string) error {
	now := time.Now()
	result := s.db.Model(&models.PayPeriod{}).
		Where("period_id = ? AND status = 'OPEN'", periodID).
		Updates(map[string]interface{}{
			"status":        "CLOSED",
			"closed_by":     user,
			"closed_date":   now,
			"modified_by":   user,
			"modified_date": now,
		})
	if result.RowsAffected == 0 {
		return errors.New("pay period not found or not in OPEN status")
	}
	return result.Error
}

func timePtr(t time.Time) *time.Time { return &t }
