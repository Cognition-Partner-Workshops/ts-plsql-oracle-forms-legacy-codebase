package services

import (
	"fmt"
	"sync/atomic"
	"time"

	"github.com/Cognition-Partner-Workshops/ts-plsql-oracle-forms-legacy-codebase/go-backend/internal/models"
	"gorm.io/gorm"
)

// EmployeeService migrates PKG_EMPLOYEE — employee CRUD, lifecycle management.
type EmployeeService struct {
	db           *gorm.DB
	audit        *AuditService
	notification *NotificationService
	validation   *ValidationService
	empNumSeq    int64
}

// NewEmployeeService creates a new EmployeeService.
func NewEmployeeService(db *gorm.DB, audit *AuditService, notification *NotificationService, validation *ValidationService) *EmployeeService {
	svc := &EmployeeService{
		db:           db,
		audit:        audit,
		notification: notification,
		validation:   validation,
	}
	// Initialize sequence from DB max
	var maxNum int64
	db.Model(&models.Employee{}).Select("COALESCE(MAX(emp_id), 10000)").Scan(&maxNum)
	svc.empNumSeq = maxNum
	return svc
}

// generateEmpNumber generates a unique employee number (EMP-NNNNNN).
// Mirrors: PKG_EMPLOYEE.generate_emp_number
// Fixed: uses atomic counter instead of MAX()+1 race condition from original.
func (s *EmployeeService) generateEmpNumber() string {
	num := atomic.AddInt64(&s.empNumSeq, 1)
	return fmt.Sprintf("EMP-%06d", num)
}

// CreateEmployee creates a new employee record.
// Mirrors: PKG_EMPLOYEE.create_employee
func (s *EmployeeService) CreateEmployee(emp *models.Employee, baseSalary float64, user string) (int64, error) {
	// Validate
	if err := s.validation.ValidateEmployee(emp); err != nil {
		return 0, err
	}
	if err := s.validation.ValidateDepartment(emp.DeptID); err != nil {
		return 0, err
	}
	if err := s.validation.ValidateJobTitle(emp.JobID); err != nil {
		return 0, err
	}
	if emp.ManagerEmpID != nil {
		if err := s.validation.ValidateManager(*emp.ManagerEmpID, 0); err != nil {
			return 0, err
		}
	}
	if baseSalary > 0 {
		if err := s.validation.ValidateSalary(baseSalary, emp.JobID); err != nil {
			return 0, err
		}
	}

	return emp.EmpID, s.db.Transaction(func(tx *gorm.DB) error {
		// Generate employee number
		emp.EmpNumber = s.generateEmpNumber()
		emp.EmploymentStatus = "ACTIVE"
		emp.ActiveFlag = "Y"
		emp.CreatedBy = user

		if err := tx.Create(emp).Error; err != nil {
			return err
		}

		// Create salary record
		if baseSalary > 0 {
			salary := models.SalaryRecord{
				EmpID:         emp.EmpID,
				EffectiveDate: emp.HireDate,
				BaseSalary:    baseSalary,
				CurrencyCode:  "USD",
				PayFrequency:  "MONTHLY",
				SalaryBasis:   "ANNUAL",
				SoftDelete:    models.SoftDelete{ActiveFlag: "Y"},
				BaseModel:     models.BaseModel{CreatedBy: user},
			}
			if err := tx.Create(&salary).Error; err != nil {
				return err
			}
		}

		// Log history
		s.logHistory(tx, emp.EmpID, "HIRE", emp.HireDate, nil, &emp.DeptID, nil, &emp.JobID, nil, emp.ManagerEmpID, nil, nil, user)

		// Audit
		_ = s.audit.LogAction("EMPLOYEES", emp.EmpID, "INSERT", user)

		// Send notification
		emailType := "EMAIL"
		subject := "New Employee Created"
		body := fmt.Sprintf("Employee %s %s has been created with employee number %s.", emp.FirstName, emp.LastName, emp.EmpNumber)
		refTable := "EMPLOYEES"
		_ = s.notification.SendNotification(nil, emp.Email, emailType, subject, body, 5, &refTable, &emp.EmpID, user)

		return nil
	})
}

// GetEmployee retrieves an employee by ID with related data.
// Mirrors: PKG_EMPLOYEE.get_employee
func (s *EmployeeService) GetEmployee(empID int64) (*models.Employee, error) {
	var emp models.Employee
	err := s.db.Preload("Department").Preload("Job.Grade").Preload("Manager").
		Where("emp_id = ?", empID).First(&emp).Error
	if err != nil {
		return nil, err
	}
	return &emp, nil
}

// UpdateEmployee updates an employee record.
// Mirrors: PKG_EMPLOYEE.update_employee (partial update: NULL = no change)
func (s *EmployeeService) UpdateEmployee(empID int64, updates map[string]interface{}, user string) error {
	var emp models.Employee
	if err := s.db.Where("emp_id = ?", empID).First(&emp).Error; err != nil {
		return err
	}

	updates["modified_by"] = user
	updates["modified_date"] = time.Now()

	return s.db.Model(&emp).Updates(updates).Error
}

// SearchEmployees searches employees with filters.
// Mirrors: PKG_EMPLOYEE.search_employees
// Fixed: uses parameterized queries instead of string concatenation (SQL injection fix).
func (s *EmployeeService) SearchEmployees(firstName, lastName *string, deptID *int64, status *string, page, pageSize int) ([]models.Employee, int64, error) {
	query := s.db.Model(&models.Employee{})

	if firstName != nil && *firstName != "" {
		query = query.Where("first_name LIKE ?", "%"+*firstName+"%")
	}
	if lastName != nil && *lastName != "" {
		query = query.Where("last_name LIKE ?", "%"+*lastName+"%")
	}
	if deptID != nil && *deptID > 0 {
		query = query.Where("dept_id = ?", *deptID)
	}
	if status != nil && *status != "" {
		query = query.Where("employment_status = ?", *status)
	}

	var total int64
	query.Count(&total)

	var employees []models.Employee
	err := query.Preload("Department").Preload("Job").
		Offset((page - 1) * pageSize).Limit(pageSize).
		Order("last_name, first_name").
		Find(&employees).Error

	return employees, total, err
}

// TransferEmployee transfers an employee to a new department/job/manager/location.
// Mirrors: PKG_EMPLOYEE.transfer_employee
func (s *EmployeeService) TransferEmployee(empID, newDeptID int64, newJobID *int64, newManagerID *int64, newLocation *string, reason, user string) error {
	return s.db.Transaction(func(tx *gorm.DB) error {
		var emp models.Employee
		if err := tx.Where("emp_id = ? AND employment_status = 'ACTIVE'", empID).First(&emp).Error; err != nil {
			return fmt.Errorf("employee not found or not active: %w", err)
		}

		oldDeptID := emp.DeptID
		oldJobID := emp.JobID
		oldManagerID := emp.ManagerEmpID
		oldLocation := emp.LocationCode

		// Validate new department
		if err := s.validation.ValidateDepartment(newDeptID); err != nil {
			return err
		}

		updates := map[string]interface{}{
			"dept_id":       newDeptID,
			"modified_by":   user,
			"modified_date": time.Now(),
		}
		if newJobID != nil {
			updates["job_id"] = *newJobID
		}
		if newManagerID != nil {
			updates["manager_emp_id"] = *newManagerID
		}
		if newLocation != nil {
			updates["location_code"] = *newLocation
		}

		if err := tx.Model(&emp).Updates(updates).Error; err != nil {
			return err
		}

		// Log history
		effectiveJobID := emp.JobID
		if newJobID != nil {
			effectiveJobID = *newJobID
		}
		s.logHistory(tx, empID, "TRANSFER", time.Now(), &oldDeptID, &newDeptID, &oldJobID, &effectiveJobID, oldManagerID, newManagerID, nil, nil, user)

		_ = s.audit.LogAction("EMPLOYEES", empID, "TRANSFER", user)

		// Notify
		subject := "Employee Transfer"
		body := fmt.Sprintf("Employee %s %s has been transferred.", emp.FirstName, emp.LastName)
		refTable := "EMPLOYEES"
		_ = s.notification.SendNotification(&empID, nil, "EMAIL", subject, body, 5, &refTable, &empID, user)

		_ = oldLocation // used for history logging
		return nil
	})
}

// PromoteEmployee promotes an employee with a new job title and salary.
// Mirrors: PKG_EMPLOYEE.promote_employee
func (s *EmployeeService) PromoteEmployee(empID, newJobID int64, newSalary float64, reason, user string) error {
	return s.db.Transaction(func(tx *gorm.DB) error {
		var emp models.Employee
		if err := tx.Where("emp_id = ? AND employment_status = 'ACTIVE'", empID).First(&emp).Error; err != nil {
			return fmt.Errorf("employee not found or not active: %w", err)
		}

		oldJobID := emp.JobID

		// Get old salary
		var oldSalaryRec models.SalaryRecord
		var oldSalary *float64
		if err := tx.Where("emp_id = ? AND active_flag = 'Y'", empID).First(&oldSalaryRec).Error; err == nil {
			oldSalary = &oldSalaryRec.BaseSalary
			// End old salary record
			now := time.Now()
			tx.Model(&oldSalaryRec).Updates(map[string]interface{}{
				"end_date":      now,
				"active_flag":   "N",
				"modified_by":   user,
				"modified_date": now,
			})
		}

		// Update job
		if err := tx.Model(&emp).Updates(map[string]interface{}{
			"job_id":        newJobID,
			"modified_by":   user,
			"modified_date": time.Now(),
		}).Error; err != nil {
			return err
		}

		// Create new salary record
		salary := models.SalaryRecord{
			EmpID:         empID,
			EffectiveDate: time.Now(),
			BaseSalary:    newSalary,
			CurrencyCode:  "USD",
			PayFrequency:  "MONTHLY",
			SalaryBasis:   "ANNUAL",
			ChangeReason:  &reason,
			SoftDelete:    models.SoftDelete{ActiveFlag: "Y"},
			BaseModel:     models.BaseModel{CreatedBy: user},
		}
		if oldSalary != nil && *oldSalary > 0 {
			pct := (newSalary - *oldSalary) / *oldSalary * 100
			salary.ChangePct = &pct
		}
		if err := tx.Create(&salary).Error; err != nil {
			return err
		}

		s.logHistory(tx, empID, "PROMOTION", time.Now(), nil, nil, &oldJobID, &newJobID, nil, nil, oldSalary, &newSalary, user)
		_ = s.audit.LogAction("EMPLOYEES", empID, "PROMOTION", user)

		return nil
	})
}

// TerminateEmployee terminates an employee.
// Mirrors: PKG_EMPLOYEE.terminate_employee
func (s *EmployeeService) TerminateEmployee(empID int64, terminationDate time.Time, reason, user string) error {
	return s.db.Transaction(func(tx *gorm.DB) error {
		var emp models.Employee
		if err := tx.Where("emp_id = ? AND employment_status = 'ACTIVE'", empID).First(&emp).Error; err != nil {
			return fmt.Errorf("employee not found or not active: %w", err)
		}

		// Update employee status
		now := time.Now()
		if err := tx.Model(&emp).Updates(map[string]interface{}{
			"employment_status":  "TERMINATED",
			"termination_date":   terminationDate,
			"termination_reason": reason,
			"active_flag":        "N",
			"modified_by":        user,
			"modified_date":      now,
		}).Error; err != nil {
			return err
		}

		// Cancel pending leave requests
		tx.Model(&models.LeaveRequest{}).
			Where("emp_id = ? AND status = 'PENDING'", empID).
			Updates(map[string]interface{}{
				"status":        "CANCELLED",
				"cancel_reason": "Employee terminated",
				"cancelled_date": now,
				"modified_by":   user,
				"modified_date": now,
			})

		// End active salary records
		tx.Model(&models.SalaryRecord{}).
			Where("emp_id = ? AND active_flag = 'Y'", empID).
			Updates(map[string]interface{}{
				"end_date":      terminationDate,
				"active_flag":   "N",
				"modified_by":   user,
				"modified_date": now,
			})

		// End active pay element assignments
		tx.Model(&models.EmployeePayElement{}).
			Where("emp_id = ? AND active_flag = 'Y'", empID).
			Updates(map[string]interface{}{
				"end_date":      terminationDate,
				"active_flag":   "N",
				"modified_by":   user,
				"modified_date": now,
			})

		s.logHistory(tx, empID, "TERMINATION", terminationDate, nil, nil, nil, nil, nil, nil, nil, nil, user)
		_ = s.audit.LogAction("EMPLOYEES", empID, "TERMINATION", user)

		return nil
	})
}

// RehireEmployee reactivates a terminated employee.
// Mirrors: PKG_EMPLOYEE.rehire_employee
func (s *EmployeeService) RehireEmployee(empID int64, rehireDate time.Time, deptID, jobID int64, salary float64, user string) error {
	return s.db.Transaction(func(tx *gorm.DB) error {
		var emp models.Employee
		if err := tx.Where("emp_id = ? AND employment_status = 'TERMINATED'", empID).First(&emp).Error; err != nil {
			return fmt.Errorf("employee not found or not terminated: %w", err)
		}

		now := time.Now()
		if err := tx.Model(&emp).Updates(map[string]interface{}{
			"employment_status":  "ACTIVE",
			"hire_date":          rehireDate,
			"termination_date":   nil,
			"termination_reason": nil,
			"dept_id":            deptID,
			"job_id":             jobID,
			"active_flag":        "Y",
			"modified_by":        user,
			"modified_date":      now,
		}).Error; err != nil {
			return err
		}

		// Create new salary record
		if salary > 0 {
			salaryRec := models.SalaryRecord{
				EmpID:         empID,
				EffectiveDate: rehireDate,
				BaseSalary:    salary,
				CurrencyCode:  "USD",
				PayFrequency:  "MONTHLY",
				SalaryBasis:   "ANNUAL",
				SoftDelete:    models.SoftDelete{ActiveFlag: "Y"},
				BaseModel:     models.BaseModel{CreatedBy: user},
			}
			if err := tx.Create(&salaryRec).Error; err != nil {
				return err
			}
		}

		s.logHistory(tx, empID, "REHIRE", rehireDate, nil, &deptID, nil, &jobID, nil, nil, nil, &salary, user)
		_ = s.audit.LogAction("EMPLOYEES", empID, "REHIRE", user)

		return nil
	})
}

// GetDirectReports returns all direct reports for a manager.
// Mirrors: PKG_EMPLOYEE.get_direct_reports
func (s *EmployeeService) GetDirectReports(managerID int64) ([]models.Employee, error) {
	var employees []models.Employee
	err := s.db.Where("manager_emp_id = ? AND employment_status = 'ACTIVE'", managerID).
		Order("last_name, first_name").
		Find(&employees).Error
	return employees, err
}

// GetOrgChart returns the org chart starting from a given employee.
// Mirrors: PKG_EMPLOYEE.get_org_chart (recursive query)
func (s *EmployeeService) GetOrgChart(rootEmpID int64, maxDepth int) ([]map[string]interface{}, error) {
	var results []map[string]interface{}
	s.buildOrgChart(rootEmpID, 0, maxDepth, &results)
	return results, nil
}

func (s *EmployeeService) buildOrgChart(empID int64, depth, maxDepth int, results *[]map[string]interface{}) {
	if depth > maxDepth {
		return
	}

	var emp models.Employee
	if err := s.db.Preload("Job").Preload("Department").
		Where("emp_id = ?", empID).First(&emp).Error; err != nil {
		return
	}

	entry := map[string]interface{}{
		"emp_id":     emp.EmpID,
		"emp_number": emp.EmpNumber,
		"name":       emp.FirstName + " " + emp.LastName,
		"depth":      depth,
	}
	if emp.Job != nil {
		entry["job_title"] = emp.Job.JobTitle
	}
	if emp.Department != nil {
		entry["dept_name"] = emp.Department.DeptName
	}
	*results = append(*results, entry)

	var reports []models.Employee
	s.db.Where("manager_emp_id = ? AND employment_status = 'ACTIVE'", empID).Find(&reports)
	for _, r := range reports {
		s.buildOrgChart(r.EmpID, depth+1, maxDepth, results)
	}
}

// logHistory records an employee change in the history table.
func (s *EmployeeService) logHistory(tx *gorm.DB, empID int64, changeType string, effectiveDate time.Time,
	oldDeptID, newDeptID *int64, oldJobID, newJobID *int64,
	oldManagerID, newManagerID *int64, oldSalary, newSalary *float64, user string) {

	hist := models.EmployeeHistory{
		EmpID:         empID,
		ChangeType:    changeType,
		EffectiveDate: effectiveDate,
		OldDeptID:     oldDeptID,
		NewDeptID:     newDeptID,
		OldJobID:      oldJobID,
		NewJobID:      newJobID,
		OldManagerID:  oldManagerID,
		NewManagerID:  newManagerID,
		OldSalary:     oldSalary,
		NewSalary:     newSalary,
		CreatedBy:     user,
	}
	tx.Create(&hist)
}

// GetEmployeeHistory retrieves change history for an employee.
func (s *EmployeeService) GetEmployeeHistory(empID int64) ([]models.EmployeeHistory, error) {
	var history []models.EmployeeHistory
	err := s.db.Where("emp_id = ?", empID).Order("effective_date DESC").Find(&history).Error
	return history, err
}

// GetDependents returns dependents for an employee.
func (s *EmployeeService) GetDependents(empID int64) ([]models.EmployeeDependent, error) {
	var deps []models.EmployeeDependent
	err := s.db.Where("emp_id = ? AND active_flag = 'Y'", empID).Find(&deps).Error
	return deps, err
}

// GetEmergencyContacts returns emergency contacts for an employee.
func (s *EmployeeService) GetEmergencyContacts(empID int64) ([]models.EmergencyContact, error) {
	var contacts []models.EmergencyContact
	err := s.db.Where("emp_id = ? AND active_flag = 'Y'", empID).Find(&contacts).Error
	return contacts, err
}
