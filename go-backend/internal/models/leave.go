package models

import "time"

// LeaveType mirrors HRMS.LEAVE_TYPES table.
type LeaveType struct {
	LeaveTypeID      int64    `gorm:"column:leave_type_id;primaryKey;autoIncrement" json:"leave_type_id"`
	LeaveTypeCode    string   `gorm:"column:leave_type_code;size:20;uniqueIndex;not null" json:"leave_type_code"`
	LeaveTypeName    string   `gorm:"column:leave_type_name;size:100;not null" json:"leave_type_name"`
	AccrualFlag      string   `gorm:"column:accrual_flag;type:char(1);default:'N'" json:"accrual_flag"`
	AccrualRate      *float64 `gorm:"column:accrual_rate;type:decimal(5,3)" json:"accrual_rate,omitempty"`
	AccrualFrequency *string  `gorm:"column:accrual_frequency;size:20" json:"accrual_frequency,omitempty"`
	MaxBalance       *float64 `gorm:"column:max_balance;type:decimal(5,1)" json:"max_balance,omitempty"`
	CarryoverMax     *float64 `gorm:"column:carryover_max;type:decimal(5,1)" json:"carryover_max,omitempty"`
	CarryoverExpiry  *int     `gorm:"column:carryover_expiry" json:"carryover_expiry,omitempty"`
	RequiresApproval string   `gorm:"column:requires_approval;type:char(1);default:'Y'" json:"requires_approval"`
	MinTenureDays    int      `gorm:"column:min_tenure_days;default:0" json:"min_tenure_days"`
	SoftDelete
	BaseModel
}

func (LeaveType) TableName() string { return "leave_types" }

// LeaveBalance mirrors HRMS.LEAVE_BALANCES table.
type LeaveBalance struct {
	BalanceID         int64      `gorm:"column:balance_id;primaryKey;autoIncrement" json:"balance_id"`
	EmpID             int64      `gorm:"column:emp_id;not null;index" json:"emp_id"`
	LeaveTypeID       int64      `gorm:"column:leave_type_id;not null" json:"leave_type_id"`
	CalendarYear      int        `gorm:"column:calendar_year;not null" json:"calendar_year"`
	OpeningBalance    float64    `gorm:"column:opening_balance;type:decimal(5,1);default:0" json:"opening_balance"`
	Accrued           float64    `gorm:"column:accrued;type:decimal(5,1);default:0" json:"accrued"`
	Used              float64    `gorm:"column:used;type:decimal(5,1);default:0" json:"used"`
	Adjustment        float64    `gorm:"column:adjustment;type:decimal(5,1);default:0" json:"adjustment"`
	Pending           float64    `gorm:"column:pending;type:decimal(5,1);default:0" json:"pending"`
	CarryoverFromPrev float64    `gorm:"column:carryover_from_prev;type:decimal(5,1);default:0" json:"carryover_from_prev"`
	CarryoverExpiryDt *time.Time `gorm:"column:carryover_expiry_dt" json:"carryover_expiry_dt,omitempty"`
	BaseModel

	LeaveType *LeaveType `gorm:"foreignKey:LeaveTypeID;references:LeaveTypeID" json:"leave_type,omitempty"`
}

func (LeaveBalance) TableName() string { return "leave_balances" }

// Available returns the available leave balance (virtual column in Oracle).
func (lb LeaveBalance) Available() float64 {
	return lb.OpeningBalance + lb.Accrued - lb.Used + lb.Adjustment - lb.Pending
}

// LeaveRequest mirrors HRMS.LEAVE_REQUESTS table.
type LeaveRequest struct {
	RequestID        int64      `gorm:"column:request_id;primaryKey;autoIncrement" json:"request_id"`
	EmpID            int64      `gorm:"column:emp_id;not null;index" json:"emp_id"`
	LeaveTypeID      int64      `gorm:"column:leave_type_id;not null" json:"leave_type_id"`
	StartDate        time.Time  `gorm:"column:start_date;not null" json:"start_date"`
	EndDate          time.Time  `gorm:"column:end_date;not null" json:"end_date"`
	TotalDays        float64    `gorm:"column:total_days;type:decimal(4,1);not null" json:"total_days"`
	HalfDayFlag      string     `gorm:"column:half_day_flag;type:char(1);default:'N'" json:"half_day_flag"`
	HalfDayPeriod    *string    `gorm:"column:half_day_period;size:10" json:"half_day_period,omitempty"`
	Status           string     `gorm:"column:status;size:20;default:'PENDING'" json:"status"`
	Reason           *string    `gorm:"column:reason;size:4000" json:"reason,omitempty"`
	ApproverEmpID    *int64     `gorm:"column:approver_emp_id" json:"approver_emp_id,omitempty"`
	ApprovalDate     *time.Time `gorm:"column:approval_date" json:"approval_date,omitempty"`
	ApprovalComments *string    `gorm:"column:approval_comments;size:4000" json:"approval_comments,omitempty"`
	CancelReason     *string    `gorm:"column:cancel_reason;size:4000" json:"cancel_reason,omitempty"`
	CancelledDate    *time.Time `gorm:"column:cancelled_date" json:"cancelled_date,omitempty"`
	BaseModel

	Employee  *Employee  `gorm:"foreignKey:EmpID;references:EmpID" json:"employee,omitempty"`
	LeaveType *LeaveType `gorm:"foreignKey:LeaveTypeID;references:LeaveTypeID" json:"leave_type,omitempty"`
}

func (LeaveRequest) TableName() string { return "leave_requests" }

// LeaveAccrualLog mirrors HRMS.LEAVE_ACCRUAL_LOG table.
type LeaveAccrualLog struct {
	AccrualID     int64     `gorm:"column:accrual_id;primaryKey;autoIncrement" json:"accrual_id"`
	EmpID         int64     `gorm:"column:emp_id;not null;index" json:"emp_id"`
	LeaveTypeID   int64     `gorm:"column:leave_type_id;not null" json:"leave_type_id"`
	AccrualDate   time.Time `gorm:"column:accrual_date;not null" json:"accrual_date"`
	AccrualAmount float64   `gorm:"column:accrual_amount;type:decimal(5,3);not null" json:"accrual_amount"`
	CreatedBy     string    `gorm:"column:created_by;size:30;not null" json:"created_by"`
	CreatedDate   time.Time `gorm:"column:created_date;not null;autoCreateTime" json:"created_date"`
}

func (LeaveAccrualLog) TableName() string { return "leave_accrual_log" }

// Holiday mirrors HRMS.HOLIDAYS table.
type Holiday struct {
	HolidayID    int64     `gorm:"column:holiday_id;primaryKey;autoIncrement" json:"holiday_id"`
	HolidayName  string    `gorm:"column:holiday_name;size:100;not null" json:"holiday_name"`
	HolidayDate  time.Time `gorm:"column:holiday_date;not null" json:"holiday_date"`
	LocationCode *string   `gorm:"column:location_code;size:10" json:"location_code,omitempty"`
	SoftDelete
	BaseModel
}

func (Holiday) TableName() string { return "holidays" }
