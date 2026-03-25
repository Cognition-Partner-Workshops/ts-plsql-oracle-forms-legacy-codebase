package database

import (
	"log"

	"github.com/Cognition-Partner-Workshops/ts-plsql-oracle-forms-legacy-codebase/go-backend/internal/models"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// Connect opens a connection to the SQLite database and returns a *gorm.DB.
func Connect(dsn string) (*gorm.DB, error) {
	db, err := gorm.Open(sqlite.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Info),
	})
	if err != nil {
		return nil, err
	}

	// Enable WAL mode for better concurrent read performance
	db.Exec("PRAGMA journal_mode=WAL")
	db.Exec("PRAGMA foreign_keys=ON")

	return db, nil
}

// AutoMigrate runs GORM auto-migration for all HRMS models.
// This creates/updates tables to match the Go struct definitions.
func AutoMigrate(db *gorm.DB) error {
	log.Println("Running database auto-migration...")
	return db.AutoMigrate(
		// Core tables (01_core_tables.sql)
		&models.Location{},
		&models.Department{},
		&models.JobGrade{},
		&models.JobTitle{},
		&models.Employee{},
		&models.EmployeeHistory{},
		&models.EmployeeDependent{},
		&models.EmergencyContact{},

		// Payroll tables (02_payroll_tables.sql)
		&models.SalaryRecord{},
		&models.PayElement{},
		&models.EmployeePayElement{},
		&models.PayPeriod{},
		&models.PayrollRun{},
		&models.PayrollDetail{},
		&models.TaxBracket{},
		&models.EmployeeTaxInfo{},
		&models.EmployeeBankAccount{},

		// Leave tables (03_leave_tables.sql)
		&models.LeaveType{},
		&models.LeaveBalance{},
		&models.LeaveRequest{},
		&models.LeaveAccrualLog{},
		&models.Holiday{},

		// Performance + system tables (04_performance_tables.sql)
		&models.ReviewCycle{},
		&models.PerformanceReview{},
		&models.PerformanceGoal{},
		&models.AuditLog{},
		&models.SystemParameter{},
		&models.NotificationQueue{},
		&models.UserSession{},
		&models.LookupValue{},
	)
}
