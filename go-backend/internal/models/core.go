package models

import "time"

// Location mirrors HRMS.LOCATIONS table.
type Location struct {
	LocationCode  string  `gorm:"column:location_code;primaryKey;size:10" json:"location_code"`
	LocationName  string  `gorm:"column:location_name;size:100;not null" json:"location_name"`
	AddressLine1  *string `gorm:"column:address_line1;size:200" json:"address_line1,omitempty"`
	AddressLine2  *string `gorm:"column:address_line2;size:200" json:"address_line2,omitempty"`
	City          *string `gorm:"column:city;size:100" json:"city,omitempty"`
	StateProvince *string `gorm:"column:state_province;size:50" json:"state_province,omitempty"`
	PostalCode    *string `gorm:"column:postal_code;size:20" json:"postal_code,omitempty"`
	CountryCode   *string `gorm:"column:country_code;size:3" json:"country_code,omitempty"`
	Phone         *string `gorm:"column:phone;size:30" json:"phone,omitempty"`
	SoftDelete
	BaseModel
}

func (Location) TableName() string { return "locations" }

// Department mirrors HRMS.DEPARTMENTS table.
type Department struct {
	DeptID       int64   `gorm:"column:dept_id;primaryKey;autoIncrement" json:"dept_id"`
	DeptCode     string  `gorm:"column:dept_code;size:20;uniqueIndex" json:"dept_code"`
	DeptName     string  `gorm:"column:dept_name;size:100;not null" json:"dept_name"`
	CostCenter   *string `gorm:"column:cost_center;size:20" json:"cost_center,omitempty"`
	ParentDeptID *int64  `gorm:"column:parent_dept_id" json:"parent_dept_id,omitempty"`
	ManagerEmpID *int64  `gorm:"column:manager_emp_id" json:"manager_emp_id,omitempty"`
	LocationCode *string `gorm:"column:location_code;size:10" json:"location_code,omitempty"`
	SoftDelete
	BaseModel

	ParentDept *Department `gorm:"foreignKey:ParentDeptID;references:DeptID" json:"parent_dept,omitempty"`
	Manager    *Employee   `gorm:"foreignKey:ManagerEmpID;references:EmpID" json:"manager,omitempty"`
}

func (Department) TableName() string { return "departments" }

// JobGrade mirrors HRMS.JOB_GRADES table.
type JobGrade struct {
	GradeID        int64    `gorm:"column:grade_id;primaryKey" json:"grade_id"`
	GradeCode      string   `gorm:"column:grade_code;size:10;uniqueIndex" json:"grade_code"`
	GradeName      string   `gorm:"column:grade_name;size:50;not null" json:"grade_name"`
	GradeLevel     int      `gorm:"column:grade_level;not null" json:"grade_level"`
	MinSalary      float64  `gorm:"column:min_salary;type:decimal(12,2);not null" json:"min_salary"`
	MaxSalary      float64  `gorm:"column:max_salary;type:decimal(12,2);not null" json:"max_salary"`
	MidpointSalary *float64 `gorm:"column:midpoint_salary;type:decimal(12,2)" json:"midpoint_salary,omitempty"`
	SoftDelete
	BaseModel
}

func (JobGrade) TableName() string { return "job_grades" }

// JobTitle mirrors HRMS.JOB_TITLES table.
type JobTitle struct {
	JobID       int64   `gorm:"column:job_id;primaryKey" json:"job_id"`
	JobCode     string  `gorm:"column:job_code;size:20;uniqueIndex" json:"job_code"`
	JobTitle    string  `gorm:"column:job_title;size:100;not null" json:"job_title"`
	GradeID     int64   `gorm:"column:grade_id;not null" json:"grade_id"`
	EEOCategory *string `gorm:"column:eeo_category;size:10" json:"eeo_category,omitempty"`
	SoftDelete
	BaseModel

	Grade *JobGrade `gorm:"foreignKey:GradeID;references:GradeID" json:"grade,omitempty"`
}

func (JobTitle) TableName() string { return "job_titles" }

// Employee mirrors HRMS.EMPLOYEES table.
type Employee struct {
	EmpID             int64      `gorm:"column:emp_id;primaryKey;autoIncrement" json:"emp_id"`
	EmpNumber         string     `gorm:"column:emp_number;size:20;uniqueIndex;not null" json:"emp_number"`
	FirstName         string     `gorm:"column:first_name;size:50;not null" json:"first_name"`
	LastName          string     `gorm:"column:last_name;size:50;not null" json:"last_name"`
	MiddleName        *string    `gorm:"column:middle_name;size:50" json:"middle_name,omitempty"`
	DateOfBirth       *time.Time `gorm:"column:date_of_birth" json:"date_of_birth,omitempty"`
	Gender            *string    `gorm:"column:gender;size:1" json:"gender,omitempty"`
	MaritalStatus     *string    `gorm:"column:marital_status;size:20" json:"marital_status,omitempty"`
	SSNEncrypted      *string    `gorm:"column:ssn_encrypted;size:200" json:"-"`
	Email             *string    `gorm:"column:email;size:100" json:"email,omitempty"`
	PhoneWork         *string    `gorm:"column:phone_work;size:30" json:"phone_work,omitempty"`
	PhoneMobile       *string    `gorm:"column:phone_mobile;size:30" json:"phone_mobile,omitempty"`
	AddressLine1      *string    `gorm:"column:address_line1;size:200" json:"address_line1,omitempty"`
	AddressLine2      *string    `gorm:"column:address_line2;size:200" json:"address_line2,omitempty"`
	City              *string    `gorm:"column:city;size:100" json:"city,omitempty"`
	StateProvince     *string    `gorm:"column:state_province;size:50" json:"state_province,omitempty"`
	PostalCode        *string    `gorm:"column:postal_code;size:20" json:"postal_code,omitempty"`
	CountryCode       *string    `gorm:"column:country_code;size:3" json:"country_code,omitempty"`
	HireDate          time.Time  `gorm:"column:hire_date;not null" json:"hire_date"`
	TerminationDate   *time.Time `gorm:"column:termination_date" json:"termination_date,omitempty"`
	TerminationReason *string    `gorm:"column:termination_reason;size:200" json:"termination_reason,omitempty"`
	DeptID            int64      `gorm:"column:dept_id;not null" json:"dept_id"`
	JobID             int64      `gorm:"column:job_id;not null" json:"job_id"`
	ManagerEmpID      *int64     `gorm:"column:manager_emp_id" json:"manager_emp_id,omitempty"`
	LocationCode      *string    `gorm:"column:location_code;size:10" json:"location_code,omitempty"`
	EmploymentType    string     `gorm:"column:employment_type;size:20;default:'FULL_TIME'" json:"employment_type"`
	EmploymentStatus  string     `gorm:"column:employment_status;size:20;default:'ACTIVE'" json:"employment_status"`
	SoftDelete
	BaseModel

	Department *Department `gorm:"foreignKey:DeptID;references:DeptID" json:"department,omitempty"`
	Job        *JobTitle   `gorm:"foreignKey:JobID;references:JobID" json:"job,omitempty"`
	Manager    *Employee   `gorm:"foreignKey:ManagerEmpID;references:EmpID" json:"manager,omitempty"`
}

func (Employee) TableName() string { return "employees" }

// EmployeeHistory mirrors HRMS.EMPLOYEE_HISTORY table.
type EmployeeHistory struct {
	HistID        int64      `gorm:"column:hist_id;primaryKey;autoIncrement" json:"hist_id"`
	EmpID         int64      `gorm:"column:emp_id;not null;index" json:"emp_id"`
	ChangeType    string     `gorm:"column:change_type;size:30;not null" json:"change_type"`
	EffectiveDate time.Time  `gorm:"column:effective_date;not null" json:"effective_date"`
	OldDeptID     *int64     `gorm:"column:old_dept_id" json:"old_dept_id,omitempty"`
	NewDeptID     *int64     `gorm:"column:new_dept_id" json:"new_dept_id,omitempty"`
	OldJobID      *int64     `gorm:"column:old_job_id" json:"old_job_id,omitempty"`
	NewJobID      *int64     `gorm:"column:new_job_id" json:"new_job_id,omitempty"`
	OldManagerID  *int64     `gorm:"column:old_manager_id" json:"old_manager_id,omitempty"`
	NewManagerID  *int64     `gorm:"column:new_manager_id" json:"new_manager_id,omitempty"`
	OldSalary     *float64   `gorm:"column:old_salary;type:decimal(12,2)" json:"old_salary,omitempty"`
	NewSalary     *float64   `gorm:"column:new_salary;type:decimal(12,2)" json:"new_salary,omitempty"`
	OldLocation   *string    `gorm:"column:old_location;size:10" json:"old_location,omitempty"`
	NewLocation   *string    `gorm:"column:new_location;size:10" json:"new_location,omitempty"`
	ReasonCode    *string    `gorm:"column:reason_code;size:30" json:"reason_code,omitempty"`
	Comments      *string    `gorm:"column:comments;size:4000" json:"comments,omitempty"`
	CreatedBy     string     `gorm:"column:created_by;size:30;not null" json:"created_by"`
	CreatedDate   time.Time  `gorm:"column:created_date;not null;autoCreateTime" json:"created_date"`
}

func (EmployeeHistory) TableName() string { return "employee_history" }

// EmployeeDependent mirrors HRMS.EMPLOYEE_DEPENDENTS table.
type EmployeeDependent struct {
	DependentID  int64      `gorm:"column:dependent_id;primaryKey;autoIncrement" json:"dependent_id"`
	EmpID        int64      `gorm:"column:emp_id;not null;index" json:"emp_id"`
	FirstName    string     `gorm:"column:first_name;size:50;not null" json:"first_name"`
	LastName     string     `gorm:"column:last_name;size:50;not null" json:"last_name"`
	Relationship string     `gorm:"column:relationship;size:30;not null" json:"relationship"`
	DateOfBirth  *time.Time `gorm:"column:date_of_birth" json:"date_of_birth,omitempty"`
	Gender       *string    `gorm:"column:gender;size:1" json:"gender,omitempty"`
	SoftDelete
	BaseModel
}

func (EmployeeDependent) TableName() string { return "employee_dependents" }

// EmergencyContact mirrors HRMS.EMERGENCY_CONTACTS table.
type EmergencyContact struct {
	ContactID    int64   `gorm:"column:contact_id;primaryKey;autoIncrement" json:"contact_id"`
	EmpID        int64   `gorm:"column:emp_id;not null;index" json:"emp_id"`
	ContactName  string  `gorm:"column:contact_name;size:100;not null" json:"contact_name"`
	Relationship string  `gorm:"column:relationship;size:30;not null" json:"relationship"`
	PhonePrimary string  `gorm:"column:phone_primary;size:30;not null" json:"phone_primary"`
	PhoneAlt     *string `gorm:"column:phone_alt;size:30" json:"phone_alt,omitempty"`
	Email        *string `gorm:"column:email;size:100" json:"email,omitempty"`
	IsPrimary    string  `gorm:"column:is_primary;type:char(1);default:'N'" json:"is_primary"`
	SoftDelete
	BaseModel
}

func (EmergencyContact) TableName() string { return "emergency_contacts" }
