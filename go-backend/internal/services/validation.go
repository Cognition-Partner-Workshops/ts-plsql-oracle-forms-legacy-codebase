package services

import (
	"errors"
	"fmt"
	"time"

	"github.com/Cognition-Partner-Workshops/ts-plsql-oracle-forms-legacy-codebase/go-backend/internal/models"
	"gorm.io/gorm"
)

// ValidationService migrates PKG_VALIDATION — centralized business rule validation.
type ValidationService struct {
	db *gorm.DB
}

// NewValidationService creates a new ValidationService.
func NewValidationService(db *gorm.DB) *ValidationService {
	return &ValidationService{db: db}
}

// ValidateEmployee validates employee data for creation or update.
// Mirrors: PKG_VALIDATION.validate_employee
func (s *ValidationService) ValidateEmployee(emp *models.Employee) error {
	if emp.FirstName == "" {
		return errors.New("first name is required")
	}
	if emp.LastName == "" {
		return errors.New("last name is required")
	}
	if emp.HireDate.IsZero() {
		return errors.New("hire date is required")
	}
	// Hire date cannot be more than 180 days in the future
	maxFutureDate := time.Now().AddDate(0, 0, 180)
	if emp.HireDate.After(maxFutureDate) {
		return errors.New("hire date cannot be more than 180 days in the future")
	}
	if emp.DeptID == 0 {
		return errors.New("department is required")
	}
	if emp.JobID == 0 {
		return errors.New("job title is required")
	}
	if emp.Email != nil && *emp.Email != "" {
		cs := &CommonService{}
		if !cs.IsValidEmail(*emp.Email) {
			return errors.New("invalid email address format")
		}
	}
	return nil
}

// ValidateDepartment checks that a department exists and is active.
// Mirrors: PKG_EMPLOYEE.validate_dept
func (s *ValidationService) ValidateDepartment(deptID int64) error {
	var dept models.Department
	err := s.db.Where("dept_id = ? AND active_flag = 'Y'", deptID).First(&dept).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return fmt.Errorf("department %d not found or inactive", deptID)
		}
		return err
	}
	return nil
}

// ValidateJobTitle checks that a job title exists and is active.
// Mirrors: PKG_VALIDATION.validate_job
func (s *ValidationService) ValidateJobTitle(jobID int64) error {
	var job models.JobTitle
	err := s.db.Where("job_id = ? AND active_flag = 'Y'", jobID).First(&job).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return fmt.Errorf("job title %d not found or inactive", jobID)
		}
		return err
	}
	return nil
}

// ValidateManager checks that a manager exists, is active, and won't create a circular reporting chain.
// Mirrors: PKG_EMPLOYEE.validate_manager
func (s *ValidationService) ValidateManager(managerID, empID int64) error {
	if managerID == empID {
		return errors.New("employee cannot be their own manager")
	}

	var mgr models.Employee
	err := s.db.Where("emp_id = ? AND employment_status = 'ACTIVE'", managerID).First(&mgr).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return fmt.Errorf("manager %d not found or not active", managerID)
		}
		return err
	}

	// Check for circular reporting (walk up the chain, max 10 levels)
	currentMgrID := mgr.ManagerEmpID
	for i := 0; i < 10; i++ {
		if currentMgrID == nil {
			break
		}
		if *currentMgrID == empID {
			return errors.New("circular reporting chain detected")
		}
		var nextMgr models.Employee
		err := s.db.Select("manager_emp_id").Where("emp_id = ?", *currentMgrID).First(&nextMgr).Error
		if err != nil {
			break
		}
		currentMgrID = nextMgr.ManagerEmpID
	}

	return nil
}

// ValidateSalary checks that a salary is within the grade range.
// Mirrors: PKG_VALIDATION.validate_salary
func (s *ValidationService) ValidateSalary(salary float64, jobID int64) error {
	if salary <= 0 {
		return errors.New("salary must be positive")
	}

	var job models.JobTitle
	err := s.db.Preload("Grade").Where("job_id = ?", jobID).First(&job).Error
	if err != nil {
		return err
	}
	if job.Grade == nil {
		return nil // no grade validation possible
	}

	if salary < job.Grade.MinSalary {
		return fmt.Errorf("salary %.2f is below grade minimum %.2f", salary, job.Grade.MinSalary)
	}
	if salary > job.Grade.MaxSalary*1.1 {
		return fmt.Errorf("salary %.2f exceeds 110%% of grade maximum %.2f", salary, job.Grade.MaxSalary)
	}
	return nil
}

// ValidateLeaveRequest validates a leave request.
// Mirrors: PKG_VALIDATION.validate_leave_request
func (s *ValidationService) ValidateLeaveRequest(req *models.LeaveRequest) error {
	if req.EmpID == 0 {
		return errors.New("employee ID is required")
	}
	if req.LeaveTypeID == 0 {
		return errors.New("leave type is required")
	}
	if req.StartDate.IsZero() || req.EndDate.IsZero() {
		return errors.New("start date and end date are required")
	}
	if req.EndDate.Before(req.StartDate) {
		return errors.New("end date cannot be before start date")
	}
	if req.StartDate.Before(time.Now().AddDate(0, 0, -30)) {
		return errors.New("leave request start date cannot be more than 30 days in the past")
	}
	if req.TotalDays <= 0 {
		return errors.New("total days must be positive")
	}
	return nil
}

// ValidateDateRange checks that a date range is valid.
// Mirrors: PKG_VALIDATION.validate_date_range
func (s *ValidationService) ValidateDateRange(startDate, endDate time.Time) error {
	if endDate.Before(startDate) {
		return errors.New("end date must be on or after start date")
	}
	return nil
}

// ValidateRating checks that a performance rating is within bounds (1.0-5.0).
// Mirrors: PKG_VALIDATION.validate_rating
func (s *ValidationService) ValidateRating(rating float64) error {
	if rating < 1.0 || rating > 5.0 {
		return errors.New("rating must be between 1.0 and 5.0")
	}
	return nil
}
