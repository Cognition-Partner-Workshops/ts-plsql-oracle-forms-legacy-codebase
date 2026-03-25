package models

import "time"

// AuditLog mirrors HRMS.AUDIT_LOG table.
type AuditLog struct {
	AuditID    int64     `gorm:"column:audit_id;primaryKey;autoIncrement" json:"audit_id"`
	AuditTableName string `gorm:"column:table_name;size:50;not null;index" json:"table_name"`
	RecordID   int64     `gorm:"column:record_id;not null;index" json:"record_id"`
	ActionType string    `gorm:"column:action_type;size:20;not null" json:"action_type"`
	OldValues  *string   `gorm:"column:old_values;type:text" json:"old_values,omitempty"`
	NewValues  *string   `gorm:"column:new_values;type:text" json:"new_values,omitempty"`
	ChangedBy  string    `gorm:"column:changed_by;size:30;not null" json:"changed_by"`
	ChangedDate time.Time `gorm:"column:changed_date;not null;autoCreateTime" json:"changed_date"`
	IPAddress  *string   `gorm:"column:ip_address;size:45" json:"ip_address,omitempty"`
	SessionID  *string   `gorm:"column:session_id;size:100" json:"session_id,omitempty"`
}

func (AuditLog) TableName() string { return "audit_log" }

// SystemParameter mirrors HRMS.SYSTEM_PARAMETERS table.
type SystemParameter struct {
	ParamID    int64   `gorm:"column:param_id;primaryKey;autoIncrement" json:"param_id"`
	Category   string  `gorm:"column:category;size:50;not null" json:"category"`
	ParamName  string  `gorm:"column:param_name;size:100;not null" json:"param_name"`
	ParamValue *string `gorm:"column:param_value;size:4000" json:"param_value,omitempty"`
	DataType   string  `gorm:"column:data_type;size:20;default:'VARCHAR'" json:"data_type"`
	SoftDelete
	BaseModel
}

func (SystemParameter) TableName() string { return "system_parameters" }

// NotificationQueue mirrors HRMS.NOTIFICATION_QUEUE table.
type NotificationQueue struct {
	NotificationID int64      `gorm:"column:notification_id;primaryKey;autoIncrement" json:"notification_id"`
	RecipientEmpID *int64     `gorm:"column:recipient_emp_id" json:"recipient_emp_id,omitempty"`
	RecipientEmail *string    `gorm:"column:recipient_email;size:100" json:"recipient_email,omitempty"`
	NotificationType string  `gorm:"column:notification_type;size:20;default:'EMAIL'" json:"notification_type"`
	Subject        string     `gorm:"column:subject;size:200;not null" json:"subject"`
	Body           string     `gorm:"column:body;type:text;not null" json:"body"`
	Status         string     `gorm:"column:status;size:20;default:'PENDING'" json:"status"`
	Priority       int        `gorm:"column:priority;default:5" json:"priority"`
	RetryCount     int        `gorm:"column:retry_count;default:0" json:"retry_count"`
	ErrorMessage   *string    `gorm:"column:error_message;size:4000" json:"error_message,omitempty"`
	SentDate       *time.Time `gorm:"column:sent_date" json:"sent_date,omitempty"`
	ReferenceTable *string    `gorm:"column:reference_table;size:50" json:"reference_table,omitempty"`
	ReferenceID    *int64     `gorm:"column:reference_id" json:"reference_id,omitempty"`
	BaseModel
}

func (NotificationQueue) TableName() string { return "notification_queue" }

// UserSession mirrors HRMS.USER_SESSIONS table.
type UserSession struct {
	SessionID     int64      `gorm:"column:session_id;primaryKey;autoIncrement" json:"session_id"`
	EmpID         int64      `gorm:"column:emp_id;not null;index" json:"emp_id"`
	Username      string     `gorm:"column:username;size:100;not null" json:"username"`
	LoginTime     time.Time  `gorm:"column:login_time;not null" json:"login_time"`
	LogoutTime    *time.Time `gorm:"column:logout_time" json:"logout_time,omitempty"`
	IPAddress     *string    `gorm:"column:ip_address;size:45" json:"ip_address,omitempty"`
	SessionStatus string     `gorm:"column:session_status;size:20;default:'ACTIVE'" json:"session_status"`
	CreatedDate   time.Time  `gorm:"column:created_date;not null;autoCreateTime" json:"created_date"`
}

func (UserSession) TableName() string { return "user_sessions" }

// LookupValue mirrors HRMS.LOOKUP_VALUES table.
type LookupValue struct {
	LookupID    int64   `gorm:"column:lookup_id;primaryKey;autoIncrement" json:"lookup_id"`
	LookupType  string  `gorm:"column:lookup_type;size:50;not null;index" json:"lookup_type"`
	LookupCode  string  `gorm:"column:lookup_code;size:50;not null" json:"lookup_code"`
	LookupValue string  `gorm:"column:lookup_value;size:200;not null" json:"lookup_value"`
	DisplayOrder int    `gorm:"column:display_order;default:0" json:"display_order"`
	SoftDelete
	BaseModel
}

func (LookupValue) TableName() string { return "lookup_values" }
