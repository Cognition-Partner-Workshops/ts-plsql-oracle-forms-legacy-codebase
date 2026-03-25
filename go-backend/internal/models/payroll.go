package models

import "time"

// SalaryRecord mirrors HRMS.SALARY_RECORDS table.
type SalaryRecord struct {
	SalaryID      int64      `gorm:"column:salary_id;primaryKey;autoIncrement" json:"salary_id"`
	EmpID         int64      `gorm:"column:emp_id;not null;index" json:"emp_id"`
	EffectiveDate time.Time  `gorm:"column:effective_date;not null" json:"effective_date"`
	EndDate       *time.Time `gorm:"column:end_date" json:"end_date,omitempty"`
	BaseSalary    float64    `gorm:"column:base_salary;type:decimal(12,2);not null" json:"base_salary"`
	CurrencyCode  string     `gorm:"column:currency_code;size:3;default:'USD'" json:"currency_code"`
	PayFrequency  string     `gorm:"column:pay_frequency;size:20;default:'MONTHLY'" json:"pay_frequency"`
	SalaryBasis   string     `gorm:"column:salary_basis;size:20;default:'ANNUAL'" json:"salary_basis"`
	ChangeReason  *string    `gorm:"column:change_reason;size:100" json:"change_reason,omitempty"`
	ChangePct     *float64   `gorm:"column:change_pct;type:decimal(5,2)" json:"change_pct,omitempty"`
	SoftDelete
	BaseModel
}

func (SalaryRecord) TableName() string { return "salary_records" }

// PayElement mirrors HRMS.PAY_ELEMENTS table.
type PayElement struct {
	ElementID        int64    `gorm:"column:element_id;primaryKey;autoIncrement" json:"element_id"`
	ElementCode      string   `gorm:"column:element_code;size:20;uniqueIndex;not null" json:"element_code"`
	ElementName      string   `gorm:"column:element_name;size:100;not null" json:"element_name"`
	ElementType      string   `gorm:"column:element_type;size:20;not null" json:"element_type"`
	CalculationType  string   `gorm:"column:calculation_type;size:20;not null" json:"calculation_type"`
	DefaultAmount    *float64 `gorm:"column:default_amount;type:decimal(12,2)" json:"default_amount,omitempty"`
	DefaultPct       *float64 `gorm:"column:default_percentage;type:decimal(5,2)" json:"default_percentage,omitempty"`
	PretaxFlag       string   `gorm:"column:pretax_flag;type:char(1);default:'N'" json:"pretax_flag"`
	GLAccountCode    *string  `gorm:"column:gl_account_code;size:30" json:"gl_account_code,omitempty"`
	PriorityOrder    int      `gorm:"column:priority_order;default:100" json:"priority_order"`
	SoftDelete
	BaseModel
}

func (PayElement) TableName() string { return "pay_elements" }

// EmployeePayElement mirrors HRMS.EMPLOYEE_PAY_ELEMENTS table.
type EmployeePayElement struct {
	EmpElementID   int64      `gorm:"column:emp_element_id;primaryKey;autoIncrement" json:"emp_element_id"`
	EmpID          int64      `gorm:"column:emp_id;not null;index" json:"emp_id"`
	ElementID      int64      `gorm:"column:element_id;not null" json:"element_id"`
	Amount         *float64   `gorm:"column:amount;type:decimal(12,2)" json:"amount,omitempty"`
	Percentage     *float64   `gorm:"column:percentage;type:decimal(5,2)" json:"percentage,omitempty"`
	OverrideAmount *float64   `gorm:"column:override_amount;type:decimal(12,2)" json:"override_amount,omitempty"`
	EffectiveDate  time.Time  `gorm:"column:effective_date;not null" json:"effective_date"`
	EndDate        *time.Time `gorm:"column:end_date" json:"end_date,omitempty"`
	SoftDelete
	BaseModel

	PayElement *PayElement `gorm:"foreignKey:ElementID;references:ElementID" json:"pay_element,omitempty"`
}

func (EmployeePayElement) TableName() string { return "employee_pay_elements" }

// PayPeriod mirrors HRMS.PAY_PERIODS table.
type PayPeriod struct {
	PeriodID        int64      `gorm:"column:period_id;primaryKey;autoIncrement" json:"period_id"`
	PeriodName      string     `gorm:"column:period_name;size:50;not null" json:"period_name"`
	PayFrequency    string     `gorm:"column:pay_frequency;size:20;not null" json:"pay_frequency"`
	PeriodStartDate time.Time  `gorm:"column:period_start_date;not null" json:"period_start_date"`
	PeriodEndDate   time.Time  `gorm:"column:period_end_date;not null" json:"period_end_date"`
	PayDate         time.Time  `gorm:"column:pay_date;not null" json:"pay_date"`
	Status          string     `gorm:"column:status;size:20;default:'OPEN'" json:"status"`
	ClosedBy        *string    `gorm:"column:closed_by;size:30" json:"closed_by,omitempty"`
	ClosedDate      *time.Time `gorm:"column:closed_date" json:"closed_date,omitempty"`
	BaseModel
}

func (PayPeriod) TableName() string { return "pay_periods" }

// PayrollRun mirrors HRMS.PAYROLL_RUNS table.
type PayrollRun struct {
	RunID           int64      `gorm:"column:run_id;primaryKey;autoIncrement" json:"run_id"`
	PeriodID        int64      `gorm:"column:period_id;not null" json:"period_id"`
	RunType         string     `gorm:"column:run_type;size:20;default:'REGULAR'" json:"run_type"`
	RunDate         time.Time  `gorm:"column:run_date;not null" json:"run_date"`
	Status          string     `gorm:"column:status;size:20;default:'PENDING'" json:"status"`
	SubmittedBy     *string    `gorm:"column:submitted_by;size:30" json:"submitted_by,omitempty"`
	SubmittedDate   *time.Time `gorm:"column:submitted_date" json:"submitted_date,omitempty"`
	ApprovedBy      *string    `gorm:"column:approved_by;size:30" json:"approved_by,omitempty"`
	ApprovedDate    *time.Time `gorm:"column:approved_date" json:"approved_date,omitempty"`
	EmployeeCount   int        `gorm:"column:employee_count;default:0" json:"employee_count"`
	ErrorCount      int        `gorm:"column:error_count;default:0" json:"error_count"`
	TotalGross      float64    `gorm:"column:total_gross;type:decimal(15,2);default:0" json:"total_gross"`
	TotalDeductions float64    `gorm:"column:total_deductions;type:decimal(15,2);default:0" json:"total_deductions"`
	TotalNet        float64    `gorm:"column:total_net;type:decimal(15,2);default:0" json:"total_net"`
	BaseModel

	Period *PayPeriod `gorm:"foreignKey:PeriodID;references:PeriodID" json:"period,omitempty"`
}

func (PayrollRun) TableName() string { return "payroll_runs" }

// PayrollDetail mirrors HRMS.PAYROLL_DETAILS table.
type PayrollDetail struct {
	DetailID     int64   `gorm:"column:detail_id;primaryKey;autoIncrement" json:"detail_id"`
	RunID        int64   `gorm:"column:run_id;not null;index" json:"run_id"`
	EmpID        int64   `gorm:"column:emp_id;not null;index" json:"emp_id"`
	ElementID    int64   `gorm:"column:element_id;not null" json:"element_id"`
	ElementType  string  `gorm:"column:element_type;size:20;not null" json:"element_type"`
	Amount       float64 `gorm:"column:amount;type:decimal(12,2);not null" json:"amount"`
	Status       string  `gorm:"column:status;size:20;default:'CALCULATED'" json:"status"`
	ErrorMessage *string `gorm:"column:error_message;size:4000" json:"error_message,omitempty"`
	BaseModel
}

func (PayrollDetail) TableName() string { return "payroll_details" }

// TaxBracket mirrors HRMS.TAX_BRACKETS table.
type TaxBracket struct {
	BracketID    int64   `gorm:"column:bracket_id;primaryKey;autoIncrement" json:"bracket_id"`
	TaxYear      int     `gorm:"column:tax_year;not null" json:"tax_year"`
	TaxType      string  `gorm:"column:tax_type;size:20;not null" json:"tax_type"`
	FilingStatus string  `gorm:"column:filing_status;size:30;not null" json:"filing_status"`
	BracketMin   float64 `gorm:"column:bracket_min;type:decimal(12,2);not null" json:"bracket_min"`
	BracketMax   float64 `gorm:"column:bracket_max;type:decimal(12,2)" json:"bracket_max"`
	TaxRate      float64 `gorm:"column:tax_rate;type:decimal(7,4);not null" json:"tax_rate"`
	BaseTax      float64 `gorm:"column:base_tax;type:decimal(12,2);default:0" json:"base_tax"`
	SoftDelete
	BaseModel
}

func (TaxBracket) TableName() string { return "tax_brackets" }

// EmployeeTaxInfo mirrors HRMS.EMPLOYEE_TAX_INFO table.
type EmployeeTaxInfo struct {
	TaxInfoID         int64    `gorm:"column:tax_info_id;primaryKey;autoIncrement" json:"tax_info_id"`
	EmpID             int64    `gorm:"column:emp_id;not null;index" json:"emp_id"`
	TaxYear           int      `gorm:"column:tax_year;not null" json:"tax_year"`
	FilingStatus      string   `gorm:"column:filing_status;size:30;default:'SINGLE'" json:"filing_status"`
	FederalAllowances int      `gorm:"column:federal_allowances;default:0" json:"federal_allowances"`
	StateCode         *string  `gorm:"column:state_code;size:3" json:"state_code,omitempty"`
	StateAllowances   int      `gorm:"column:state_allowances;default:0" json:"state_allowances"`
	AdditionalFedWH   float64  `gorm:"column:additional_fed_wh;type:decimal(12,2);default:0" json:"additional_fed_wh"`
	SoftDelete
	BaseModel
}

func (EmployeeTaxInfo) TableName() string { return "employee_tax_info" }

// EmployeeBankAccount mirrors HRMS.EMPLOYEE_BANK_ACCOUNTS table.
type EmployeeBankAccount struct {
	AccountID     int64   `gorm:"column:account_id;primaryKey;autoIncrement" json:"account_id"`
	EmpID         int64   `gorm:"column:emp_id;not null;index" json:"emp_id"`
	BankName      string  `gorm:"column:bank_name;size:100;not null" json:"bank_name"`
	AccountType   string  `gorm:"column:account_type;size:20;not null" json:"account_type"`
	RoutingNumber string  `gorm:"column:routing_number;size:20;not null" json:"-"`
	AccountNumber string  `gorm:"column:account_number;size:30;not null" json:"-"`
	DepositPct    float64 `gorm:"column:deposit_pct;type:decimal(5,2);default:100" json:"deposit_pct"`
	IsPrimary     string  `gorm:"column:is_primary;type:char(1);default:'Y'" json:"is_primary"`
	SoftDelete
	BaseModel
}

func (EmployeeBankAccount) TableName() string { return "employee_bank_accounts" }
