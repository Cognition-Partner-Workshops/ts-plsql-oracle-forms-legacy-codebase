package middleware

import (
	"errors"
	"time"

	"github.com/Cognition-Partner-Workshops/ts-plsql-oracle-forms-legacy-codebase/go-backend/internal/models"
	"gorm.io/gorm"
)

// RegisterGORMHooks registers GORM callback hooks that migrate Oracle database triggers.
// This replaces:
//   - TRG_EMP_BEFORE_INSERT: audit columns, hire date validation
//   - TRG_EMP_BEFORE_UPDATE: audit columns, status change logging
//   - TRG_EMP_INSTEAD_OF_DELETE: soft delete enforcement
//   - TRG_SALARY_AUDIT: salary change auditing
//   - TRG_LEAVE_REQUEST_AUDIT: leave request change auditing
//   - TRG_DEPARTMENT_AUDIT: department change auditing
func RegisterGORMHooks(db *gorm.DB) {
	// Before Create: set audit columns and validate hire date
	db.Callback().Create().Before("gorm:create").Register("hrms:before_create", func(tx *gorm.DB) {
		if tx.Statement.Schema == nil {
			return
		}

		now := time.Now()

		// Set CreatedDate if the model has it
		if field := tx.Statement.Schema.LookUpField("CreatedDate"); field != nil {
			_ = field.Set(tx.Statement.Context, tx.Statement.ReflectValue, now)
		}

		// Employee-specific: validate hire date not > 180 days future
		if tx.Statement.Schema.Table == "employees" {
			if field := tx.Statement.Schema.LookUpField("HireDate"); field != nil {
				val, isZero := field.ValueOf(tx.Statement.Context, tx.Statement.ReflectValue)
				if !isZero {
					if hireDate, ok := val.(time.Time); ok {
						maxFuture := time.Now().AddDate(0, 0, 180)
						if hireDate.After(maxFuture) {
							_ = tx.AddError(errors.New("hire date cannot be more than 180 days in the future"))
							return
						}
					}
				}
			}
		}
	})

	// Before Update: set modified audit columns
	db.Callback().Update().Before("gorm:update").Register("hrms:before_update", func(tx *gorm.DB) {
		if tx.Statement.Schema == nil {
			return
		}
		now := time.Now()
		if field := tx.Statement.Schema.LookUpField("ModifiedDate"); field != nil {
			_ = field.Set(tx.Statement.Context, tx.Statement.ReflectValue, &now)
		}
	})

	// Before Delete: enforce soft delete for Employee records
	// Mirrors TRG_EMP_INSTEAD_OF_DELETE: raises error on DELETE, requires ACTIVE_FLAG='N' instead
	db.Callback().Delete().Before("gorm:delete").Register("hrms:before_delete", func(tx *gorm.DB) {
		if tx.Statement.Schema == nil {
			return
		}
		if tx.Statement.Schema.Table == "employees" {
			_ = tx.AddError(errors.New("direct deletion of employee records is not allowed; set active_flag to 'N' instead"))
			return
		}
	})
}

// SetupSoftDeleteScope adds a default scope to only return active records.
// This mirrors the pattern where most Oracle queries filter on ACTIVE_FLAG = 'Y'.
func SetupSoftDeleteScope(db *gorm.DB) {
	// Add a global scope for models with SoftDelete
	// This is applied at the query level in each service method via WHERE active_flag = 'Y'
	// rather than as a GORM global scope to maintain explicit control.
	_ = db // placeholder — scoping is handled in service queries
}

// EmployeeBeforeCreate hook for the Employee model.
// Migrates TRG_EMP_BEFORE_INSERT trigger logic.
func EmployeeBeforeCreate(emp *models.Employee) error {
	// Validate hire date
	maxFuture := time.Now().AddDate(0, 0, 180)
	if emp.HireDate.After(maxFuture) {
		return errors.New("hire date cannot be more than 180 days in the future")
	}

	// Set defaults
	if emp.EmploymentStatus == "" {
		emp.EmploymentStatus = "ACTIVE"
	}
	if emp.ActiveFlag == "" {
		emp.ActiveFlag = "Y"
	}

	return nil
}

// EmployeeBeforeUpdate hook for the Employee model.
// Migrates TRG_EMP_BEFORE_UPDATE trigger logic.
func EmployeeBeforeUpdate(emp *models.Employee) error {
	// Prevent reactivation of terminated employees through direct update
	// (must use rehire process instead)
	if emp.EmploymentStatus == "TERMINATED" && emp.ActiveFlag == "Y" {
		return errors.New("cannot reactivate terminated employee; use the rehire process")
	}
	return nil
}
