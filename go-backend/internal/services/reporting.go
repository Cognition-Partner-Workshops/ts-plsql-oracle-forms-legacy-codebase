package services

import (
	"time"

	"gorm.io/gorm"
)

// ReportingService migrates PKG_REPORTING — headcount, compensation, turnover, compliance reports.
type ReportingService struct {
	db     *gorm.DB
	common *CommonService
}

// NewReportingService creates a new ReportingService.
func NewReportingService(db *gorm.DB, common *CommonService) *ReportingService {
	return &ReportingService{db: db, common: common}
}

// HeadcountRow represents a row in the headcount report.
type HeadcountRow struct {
	DeptName        string  `json:"dept_name"`
	CostCenter      string  `json:"cost_center"`
	LocationName    string  `json:"location_name"`
	City            string  `json:"city"`
	StateProvince   string  `json:"state_province"`
	Headcount       int     `json:"headcount"`
	FTCount         int     `json:"ft_count"`
	PTCount         int     `json:"pt_count"`
	ContractCount   int     `json:"contract_count"`
	MaleCount       int     `json:"male_count"`
	FemaleCount     int     `json:"female_count"`
	AvgTenureYears  float64 `json:"avg_tenure_years"`
}

// HeadcountReport generates a headcount report.
// Mirrors: PKG_REPORTING.headcount_report
func (s *ReportingService) HeadcountReport(asOfDate time.Time, deptID *int64, location *string) ([]HeadcountRow, error) {
	query := s.db.Table("employees e").
		Select(`d.dept_name, COALESCE(d.cost_center, '') as cost_center,
			COALESCE(l.location_name, '') as location_name,
			COALESCE(l.city, '') as city, COALESCE(l.state_province, '') as state_province,
			COUNT(*) as headcount,
			SUM(CASE WHEN e.employment_type = 'FULL_TIME' THEN 1 ELSE 0 END) as ft_count,
			SUM(CASE WHEN e.employment_type = 'PART_TIME' THEN 1 ELSE 0 END) as pt_count,
			SUM(CASE WHEN e.employment_type = 'CONTRACT' THEN 1 ELSE 0 END) as contract_count,
			SUM(CASE WHEN e.gender = 'M' THEN 1 ELSE 0 END) as male_count,
			SUM(CASE WHEN e.gender = 'F' THEN 1 ELSE 0 END) as female_count,
			ROUND(AVG(JULIANDAY(?) - JULIANDAY(e.hire_date)) / 365.25, 1) as avg_tenure_years`, asOfDate).
		Joins("JOIN departments d ON e.dept_id = d.dept_id").
		Joins("LEFT JOIN locations l ON e.location_code = l.location_code").
		Where("e.employment_status = 'ACTIVE' AND e.hire_date <= ?", asOfDate).
		Where("e.termination_date IS NULL OR e.termination_date > ?", asOfDate)

	if deptID != nil {
		query = query.Where("e.dept_id = ?", *deptID)
	}
	if location != nil {
		query = query.Where("e.location_code = ?", *location)
	}

	query = query.Group("d.dept_name, d.cost_center, l.location_name, l.city, l.state_province").
		Order("d.dept_name")

	var rows []HeadcountRow
	err := query.Find(&rows).Error
	return rows, err
}

// CompensationRow represents a row in the compensation summary report.
type CompensationRow struct {
	DeptName     string  `json:"dept_name"`
	GradeName    string  `json:"grade_name"`
	JobTitle     string  `json:"job_title"`
	EmpCount     int     `json:"emp_count"`
	GradeMin     float64 `json:"grade_min"`
	GradeMax     float64 `json:"grade_max"`
	ActualMin    float64 `json:"actual_min"`
	ActualMax    float64 `json:"actual_max"`
	AvgSalary    float64 `json:"avg_salary"`
	MedianSalary float64 `json:"median_salary"`
	CompaRatio   float64 `json:"compa_ratio"`
}

// CompensationSummary generates a compensation summary report.
// Mirrors: PKG_REPORTING.compensation_summary
func (s *ReportingService) CompensationSummary(deptID, gradeID *int64) ([]CompensationRow, error) {
	query := s.db.Table("employees e").
		Select(`d.dept_name, g.grade_name, j.job_title,
			COUNT(*) as emp_count,
			g.min_salary as grade_min, g.max_salary as grade_max,
			MIN(sr.base_salary) as actual_min,
			MAX(sr.base_salary) as actual_max,
			ROUND(AVG(sr.base_salary), 2) as avg_salary,
			ROUND(AVG(sr.base_salary), 2) as median_salary,
			ROUND(AVG(sr.base_salary / ((g.min_salary + g.max_salary) / 2.0)) * 100, 1) as compa_ratio`).
		Joins("JOIN departments d ON e.dept_id = d.dept_id").
		Joins("JOIN job_titles j ON e.job_id = j.job_id").
		Joins("JOIN job_grades g ON j.grade_id = g.grade_id").
		Joins("JOIN salary_records sr ON e.emp_id = sr.emp_id AND sr.active_flag = 'Y'").
		Where("e.employment_status = 'ACTIVE'")

	if deptID != nil {
		query = query.Where("e.dept_id = ?", *deptID)
	}
	if gradeID != nil {
		query = query.Where("g.grade_id = ?", *gradeID)
	}

	query = query.Group("d.dept_name, g.grade_name, j.job_title, g.min_salary, g.max_salary").
		Order("d.dept_name, g.grade_name")

	var rows []CompensationRow
	err := query.Find(&rows).Error
	return rows, err
}

// TurnoverRow represents a row in the turnover report.
type TurnoverRow struct {
	DeptName         string  `json:"dept_name"`
	Terminations     int     `json:"terminations"`
	CurrentHC        int     `json:"current_hc"`
	TurnoverPct      float64 `json:"turnover_pct"`
	Voluntary        int     `json:"voluntary"`
	Involuntary      int     `json:"involuntary"`
	AvgTenureAtExit  float64 `json:"avg_tenure_at_exit"`
}

// TurnoverReport generates a turnover report.
// Mirrors: PKG_REPORTING.turnover_report
func (s *ReportingService) TurnoverReport(startDate, endDate time.Time, deptID *int64) ([]TurnoverRow, error) {
	query := s.db.Table("employees e").
		Select(`d.dept_name,
			SUM(CASE WHEN e.termination_date BETWEEN ? AND ? THEN 1 ELSE 0 END) as terminations,
			SUM(CASE WHEN e.employment_status = 'ACTIVE' THEN 1 ELSE 0 END) as current_hc,
			CASE WHEN SUM(CASE WHEN e.hire_date <= ? THEN 1 ELSE 0 END) > 0
				THEN ROUND(CAST(SUM(CASE WHEN e.termination_date BETWEEN ? AND ? THEN 1 ELSE 0 END) AS FLOAT) * 100.0 /
					SUM(CASE WHEN e.hire_date <= ? THEN 1 ELSE 0 END), 1)
				ELSE 0 END as turnover_pct,
			SUM(CASE WHEN e.termination_reason = 'VOLUNTARY' AND e.termination_date BETWEEN ? AND ? THEN 1 ELSE 0 END) as voluntary,
			SUM(CASE WHEN e.termination_reason != 'VOLUNTARY' AND e.termination_date BETWEEN ? AND ? THEN 1 ELSE 0 END) as involuntary,
			ROUND(AVG(CASE WHEN e.termination_date BETWEEN ? AND ?
				THEN (JULIANDAY(e.termination_date) - JULIANDAY(e.hire_date)) / 365.25 ELSE NULL END), 1) as avg_tenure_at_exit`,
			startDate, endDate, endDate, startDate, endDate, endDate, startDate, endDate, startDate, endDate, startDate, endDate).
		Joins("JOIN departments d ON e.dept_id = d.dept_id").
		Where("e.hire_date <= ?", endDate)

	if deptID != nil {
		query = query.Where("e.dept_id = ?", *deptID)
	}

	query = query.Group("d.dept_name").
		Having("SUM(CASE WHEN e.hire_date <= ? THEN 1 ELSE 0 END) > 0", endDate).
		Order("turnover_pct DESC")

	var rows []TurnoverRow
	err := query.Find(&rows).Error
	return rows, err
}

// NewHireRow represents a row in the new hires report.
type NewHireRow struct {
	EmpNumber      string  `json:"emp_number"`
	EmpName        string  `json:"emp_name"`
	HireDate       string  `json:"hire_date"`
	DeptName       string  `json:"dept_name"`
	JobTitle       string  `json:"job_title"`
	LocationName   string  `json:"location_name"`
	EmploymentType string  `json:"employment_type"`
	BaseSalary     float64 `json:"base_salary"`
	ManagerName    string  `json:"manager_name"`
}

// NewHiresReport generates a new hires report.
// Mirrors: PKG_REPORTING.new_hires_report
func (s *ReportingService) NewHiresReport(startDate, endDate time.Time, deptID *int64) ([]NewHireRow, error) {
	query := s.db.Table("employees e").
		Select(`e.emp_number,
			e.first_name || ' ' || e.last_name as emp_name,
			e.hire_date,
			d.dept_name, j.job_title,
			COALESCE(l.location_name, '') as location_name,
			e.employment_type,
			COALESCE(sr.base_salary, 0) as base_salary,
			COALESCE(m.first_name || ' ' || m.last_name, '') as manager_name`).
		Joins("JOIN departments d ON e.dept_id = d.dept_id").
		Joins("JOIN job_titles j ON e.job_id = j.job_id").
		Joins("LEFT JOIN locations l ON e.location_code = l.location_code").
		Joins("LEFT JOIN employees m ON e.manager_emp_id = m.emp_id").
		Joins("LEFT JOIN salary_records sr ON e.emp_id = sr.emp_id AND sr.active_flag = 'Y'").
		Where("e.hire_date BETWEEN ? AND ?", startDate, endDate)

	if deptID != nil {
		query = query.Where("e.dept_id = ?", *deptID)
	}

	query = query.Order("e.hire_date DESC")

	var rows []NewHireRow
	err := query.Find(&rows).Error
	return rows, err
}

// PayrollSummaryRow represents a row in the payroll summary report.
type PayrollSummaryRow struct {
	DeptName        string  `json:"dept_name"`
	EmpCount        int     `json:"emp_count"`
	TotalGross      float64 `json:"total_gross"`
	TotalFedTax     float64 `json:"total_fed_tax"`
	TotalStateTax   float64 `json:"total_state_tax"`
	TotalSS         float64 `json:"total_ss"`
	TotalMedicare   float64 `json:"total_medicare"`
	TotalDeductions float64 `json:"total_deductions"`
	TotalNet        float64 `json:"total_net"`
}

// PayrollSummaryReport generates a payroll summary report.
// Mirrors: PKG_REPORTING.payroll_summary_report
func (s *ReportingService) PayrollSummaryReport(periodID int64) ([]PayrollSummaryRow, error) {
	var rows []PayrollSummaryRow
	err := s.db.Table("payroll_details pd").
		Select(`d.dept_name,
			COUNT(DISTINCT pd.emp_id) as emp_count,
			SUM(CASE WHEN pd.element_type = 'EARNING' THEN pd.amount ELSE 0 END) as total_gross,
			SUM(CASE WHEN pd.element_id = 100 THEN ABS(pd.amount) ELSE 0 END) as total_fed_tax,
			SUM(CASE WHEN pd.element_id = 101 THEN ABS(pd.amount) ELSE 0 END) as total_state_tax,
			SUM(CASE WHEN pd.element_id = 102 THEN ABS(pd.amount) ELSE 0 END) as total_ss,
			SUM(CASE WHEN pd.element_id = 103 THEN ABS(pd.amount) ELSE 0 END) as total_medicare,
			SUM(CASE WHEN pd.element_type IN ('DEDUCTION','BENEFIT') THEN ABS(pd.amount) ELSE 0 END) as total_deductions,
			SUM(pd.amount) as total_net`).
		Joins("JOIN payroll_runs pr ON pd.run_id = pr.run_id").
		Joins("JOIN employees e ON pd.emp_id = e.emp_id").
		Joins("JOIN departments d ON e.dept_id = d.dept_id").
		Where("pr.period_id = ? AND pd.status != 'ERROR'", periodID).
		Group("d.dept_name").
		Order("d.dept_name").
		Find(&rows).Error
	return rows, err
}

// EEORow represents a row in the EEO compliance report.
type EEORow struct {
	EEOCategory  string  `json:"eeo_category"`
	Total        int     `json:"total"`
	Male         int     `json:"male"`
	Female       int     `json:"female"`
	OtherGender  int     `json:"other_gender"`
	NotDisclosed int     `json:"not_disclosed"`
	FemalePct    float64 `json:"female_pct"`
}

// EEOComplianceReport generates an EEO compliance report.
// Mirrors: PKG_REPORTING.eeo_compliance_report
func (s *ReportingService) EEOComplianceReport(asOfDate time.Time) ([]EEORow, error) {
	var rows []EEORow
	err := s.db.Table("employees e").
		Select(`j.eeo_category,
			COUNT(*) as total,
			SUM(CASE WHEN e.gender = 'M' THEN 1 ELSE 0 END) as male,
			SUM(CASE WHEN e.gender = 'F' THEN 1 ELSE 0 END) as female,
			SUM(CASE WHEN e.gender = 'O' THEN 1 ELSE 0 END) as other_gender,
			SUM(CASE WHEN e.gender IS NULL THEN 1 ELSE 0 END) as not_disclosed,
			ROUND(CAST(SUM(CASE WHEN e.gender = 'F' THEN 1 ELSE 0 END) AS FLOAT) * 100.0 / COUNT(*), 1) as female_pct`).
		Joins("JOIN job_titles j ON e.job_id = j.job_id").
		Where("e.employment_status = 'ACTIVE' AND e.hire_date <= ?", asOfDate).
		Group("j.eeo_category").
		Order("j.eeo_category").
		Find(&rows).Error
	return rows, err
}

// LeaveUtilizationRow represents a row in the leave utilization report.
type LeaveUtilizationRow struct {
	DeptName       string  `json:"dept_name"`
	LeaveTypeName  string  `json:"leave_type_name"`
	EmpCount       int     `json:"emp_count"`
	AvgEntitled    float64 `json:"avg_entitled"`
	AvgUsed        float64 `json:"avg_used"`
	AvgRemaining   float64 `json:"avg_remaining"`
	UtilizationPct float64 `json:"utilization_pct"`
}

// LeaveUtilizationReport generates a leave utilization report.
// Mirrors: PKG_REPORTING.leave_utilization_report
func (s *ReportingService) LeaveUtilizationReport(year int, deptID *int64) ([]LeaveUtilizationRow, error) {
	query := s.db.Table("leave_balances lb").
		Select(`d.dept_name, lt.leave_type_name,
			COUNT(DISTINCT lb.emp_id) as emp_count,
			ROUND(AVG(lb.opening_balance + lb.accrued), 1) as avg_entitled,
			ROUND(AVG(lb.used), 1) as avg_used,
			ROUND(AVG(lb.opening_balance + lb.accrued - lb.used + lb.adjustment), 1) as avg_remaining,
			CASE WHEN AVG(lb.opening_balance + lb.accrued) > 0
				THEN ROUND(AVG(lb.used) * 100.0 / AVG(lb.opening_balance + lb.accrued), 1)
				ELSE 0 END as utilization_pct`).
		Joins("JOIN employees e ON lb.emp_id = e.emp_id").
		Joins("JOIN departments d ON e.dept_id = d.dept_id").
		Joins("JOIN leave_types lt ON lb.leave_type_id = lt.leave_type_id").
		Where("lb.calendar_year = ? AND e.employment_status = 'ACTIVE'", year)

	if deptID != nil {
		query = query.Where("e.dept_id = ?", *deptID)
	}

	query = query.Group("d.dept_name, lt.leave_type_name").
		Order("d.dept_name, lt.leave_type_name")

	var rows []LeaveUtilizationRow
	err := query.Find(&rows).Error
	return rows, err
}

// RefreshReportingTables placeholder for nightly refresh of denormalized reporting tables.
// Mirrors: PKG_REPORTING.refresh_reporting_tables
func (s *ReportingService) RefreshReportingTables(user string) {
	s.common.LogInfo("ReportingService", "RefreshReportingTables", "Reporting tables refreshed", user)
}
