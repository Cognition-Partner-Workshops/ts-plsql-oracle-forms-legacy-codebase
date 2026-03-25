package database

import (
	"fmt"
	"log"
	"time"

	"github.com/Cognition-Partner-Workshops/ts-plsql-oracle-forms-legacy-codebase/go-backend/internal/models"
	"gorm.io/gorm"
)

// SeedData populates the database with initial reference and employee data.
// Mirrors: data/seed/01_reference_data.sql and data/seed/02_employee_data.sql
func SeedData(db *gorm.DB) error {
	// Check if data already exists
	var count int64
	db.Model(&models.Location{}).Count(&count)
	if count > 0 {
		log.Println("Database already seeded, skipping...")
		return nil
	}

	log.Println("Seeding database with reference data...")

	// --- Locations (01_reference_data.sql) ---
	locations := []models.Location{
		{LocationCode: "NYC", LocationName: "New York Office", AddressLine1: strPtr("350 Fifth Avenue"), City: strPtr("New York"), StateProvince: strPtr("NY"), PostalCode: strPtr("10118"), CountryCode: strPtr("US"), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{LocationCode: "SF", LocationName: "San Francisco Office", AddressLine1: strPtr("555 California Street"), City: strPtr("San Francisco"), StateProvince: strPtr("CA"), PostalCode: strPtr("94104"), CountryCode: strPtr("US"), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{LocationCode: "CHI", LocationName: "Chicago Office", AddressLine1: strPtr("233 S Wacker Drive"), City: strPtr("Chicago"), StateProvince: strPtr("IL"), PostalCode: strPtr("60606"), CountryCode: strPtr("US"), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{LocationCode: "ATL", LocationName: "Atlanta Office", AddressLine1: strPtr("191 Peachtree Street"), City: strPtr("Atlanta"), StateProvince: strPtr("GA"), PostalCode: strPtr("30303"), CountryCode: strPtr("US"), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{LocationCode: "DAL", LocationName: "Dallas Office", AddressLine1: strPtr("2200 Ross Avenue"), City: strPtr("Dallas"), StateProvince: strPtr("TX"), PostalCode: strPtr("75201"), CountryCode: strPtr("US"), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
	}
	for i := range locations {
		db.Create(&locations[i])
	}

	// --- Job Grades (01_reference_data.sql) ---
	grades := []models.JobGrade{
		{GradeCode: "G1", GradeName: "Entry Level", GradeLevel: 1, MinSalary: 30000, MaxSalary: 45000, MidpointSalary: float64Ptr(37500), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{GradeCode: "G2", GradeName: "Junior", GradeLevel: 2, MinSalary: 40000, MaxSalary: 60000, MidpointSalary: float64Ptr(50000), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{GradeCode: "G3", GradeName: "Mid-Level", GradeLevel: 3, MinSalary: 55000, MaxSalary: 80000, MidpointSalary: float64Ptr(67500), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{GradeCode: "G4", GradeName: "Senior", GradeLevel: 4, MinSalary: 70000, MaxSalary: 100000, MidpointSalary: float64Ptr(85000), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{GradeCode: "G5", GradeName: "Lead", GradeLevel: 5, MinSalary: 90000, MaxSalary: 130000, MidpointSalary: float64Ptr(110000), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{GradeCode: "G6", GradeName: "Manager", GradeLevel: 6, MinSalary: 100000, MaxSalary: 150000, MidpointSalary: float64Ptr(125000), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{GradeCode: "G7", GradeName: "Senior Manager", GradeLevel: 7, MinSalary: 120000, MaxSalary: 180000, MidpointSalary: float64Ptr(150000), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{GradeCode: "G8", GradeName: "Director", GradeLevel: 8, MinSalary: 150000, MaxSalary: 220000, MidpointSalary: float64Ptr(185000), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{GradeCode: "G9", GradeName: "Vice President", GradeLevel: 9, MinSalary: 180000, MaxSalary: 280000, MidpointSalary: float64Ptr(230000), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{GradeCode: "G10", GradeName: "C-Suite", GradeLevel: 10, MinSalary: 250000, MaxSalary: 500000, MidpointSalary: float64Ptr(375000), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
	}
	for i := range grades {
		db.Create(&grades[i])
	}

	// --- Departments (01_reference_data.sql) ---
	departments := []models.Department{
		{DeptCode: "EXEC", DeptName: "Executive Office", CostCenter: strPtr("CC-1000"), LocationCode: strPtr("NYC"), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{DeptCode: "HR", DeptName: "Human Resources", CostCenter: strPtr("CC-2000"), LocationCode: strPtr("NYC"), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{DeptCode: "FIN", DeptName: "Finance", CostCenter: strPtr("CC-3000"), LocationCode: strPtr("NYC"), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{DeptCode: "ENG", DeptName: "Engineering", CostCenter: strPtr("CC-4000"), LocationCode: strPtr("SF"), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{DeptCode: "SALES", DeptName: "Sales", CostCenter: strPtr("CC-5000"), LocationCode: strPtr("CHI"), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{DeptCode: "MKT", DeptName: "Marketing", CostCenter: strPtr("CC-6000"), LocationCode: strPtr("NYC"), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{DeptCode: "OPS", DeptName: "Operations", CostCenter: strPtr("CC-7000"), LocationCode: strPtr("ATL"), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{DeptCode: "IT", DeptName: "Information Technology", CostCenter: strPtr("CC-8000"), LocationCode: strPtr("SF"), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{DeptCode: "LEGAL", DeptName: "Legal", CostCenter: strPtr("CC-9000"), LocationCode: strPtr("NYC"), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{DeptCode: "CS", DeptName: "Customer Support", CostCenter: strPtr("CC-10000"), LocationCode: strPtr("DAL"), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
	}
	for i := range departments {
		db.Create(&departments[i])
	}

	// Set parent departments
	db.Model(&models.Department{}).Where("dept_code IN ('HR','FIN','LEGAL')", ).Update("parent_dept_id", departments[0].DeptID)

	// --- Job Titles (01_reference_data.sql) ---
	jobTitles := []models.JobTitle{
		{JobCode: "CEO", JobTitle: "Chief Executive Officer", GradeID: grades[9].GradeID, EEOCategory: strPtr("Officials and Managers"), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{JobCode: "CFO", JobTitle: "Chief Financial Officer", GradeID: grades[9].GradeID, EEOCategory: strPtr("Officials and Managers"), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{JobCode: "CTO", JobTitle: "Chief Technology Officer", GradeID: grades[9].GradeID, EEOCategory: strPtr("Officials and Managers"), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{JobCode: "VP_ENG", JobTitle: "VP of Engineering", GradeID: grades[8].GradeID, EEOCategory: strPtr("Officials and Managers"), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{JobCode: "VP_SALES", JobTitle: "VP of Sales", GradeID: grades[8].GradeID, EEOCategory: strPtr("Officials and Managers"), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{JobCode: "DIR_HR", JobTitle: "Director of HR", GradeID: grades[7].GradeID, EEOCategory: strPtr("Officials and Managers"), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{JobCode: "DIR_FIN", JobTitle: "Director of Finance", GradeID: grades[7].GradeID, EEOCategory: strPtr("Officials and Managers"), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{JobCode: "MGR_ENG", JobTitle: "Engineering Manager", GradeID: grades[6].GradeID, EEOCategory: strPtr("Officials and Managers"), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{JobCode: "SR_ENG", JobTitle: "Senior Software Engineer", GradeID: grades[4].GradeID, EEOCategory: strPtr("Professionals"), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{JobCode: "SWE", JobTitle: "Software Engineer", GradeID: grades[3].GradeID, EEOCategory: strPtr("Professionals"), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{JobCode: "JR_SWE", JobTitle: "Junior Software Engineer", GradeID: grades[1].GradeID, EEOCategory: strPtr("Professionals"), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{JobCode: "HR_MGR", JobTitle: "HR Manager", GradeID: grades[5].GradeID, EEOCategory: strPtr("Officials and Managers"), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{JobCode: "HR_SPEC", JobTitle: "HR Specialist", GradeID: grades[2].GradeID, EEOCategory: strPtr("Professionals"), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{JobCode: "ACCT", JobTitle: "Accountant", GradeID: grades[2].GradeID, EEOCategory: strPtr("Professionals"), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{JobCode: "SR_ACCT", JobTitle: "Senior Accountant", GradeID: grades[3].GradeID, EEOCategory: strPtr("Professionals"), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{JobCode: "SALES_REP", JobTitle: "Sales Representative", GradeID: grades[2].GradeID, EEOCategory: strPtr("Sales Workers"), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{JobCode: "SALES_MGR", JobTitle: "Sales Manager", GradeID: grades[5].GradeID, EEOCategory: strPtr("Officials and Managers"), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{JobCode: "MKT_SPEC", JobTitle: "Marketing Specialist", GradeID: grades[2].GradeID, EEOCategory: strPtr("Professionals"), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{JobCode: "SYS_ADMIN", JobTitle: "System Administrator", GradeID: grades[3].GradeID, EEOCategory: strPtr("Technicians"), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{JobCode: "INTERN", JobTitle: "Intern", GradeID: grades[0].GradeID, EEOCategory: strPtr("Service Workers"), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
	}
	for i := range jobTitles {
		db.Create(&jobTitles[i])
	}

	// --- Leave Types (01_reference_data.sql) ---
	leaveTypes := []models.LeaveType{
		{LeaveTypeCode: "ANNUAL", LeaveTypeName: "Annual Leave", AccrualFlag: "Y", AccrualRate: float64Ptr(1.25), AccrualFrequency: strPtr("MONTHLY"), MaxBalance: float64Ptr(30), CarryoverMax: float64Ptr(5), CarryoverExpiry: intPtr(3), RequiresApproval: "Y", MinTenureDays: 0, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{LeaveTypeCode: "SICK", LeaveTypeName: "Sick Leave", AccrualFlag: "Y", AccrualRate: float64Ptr(0.834), AccrualFrequency: strPtr("MONTHLY"), MaxBalance: float64Ptr(15), CarryoverMax: float64Ptr(10), RequiresApproval: "Y", MinTenureDays: 0, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{LeaveTypeCode: "PERSONAL", LeaveTypeName: "Personal Leave", AccrualFlag: "N", MaxBalance: float64Ptr(3), RequiresApproval: "Y", MinTenureDays: 90, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{LeaveTypeCode: "MATERNITY", LeaveTypeName: "Maternity Leave", AccrualFlag: "N", MaxBalance: float64Ptr(60), RequiresApproval: "Y", MinTenureDays: 365, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{LeaveTypeCode: "PATERNITY", LeaveTypeName: "Paternity Leave", AccrualFlag: "N", MaxBalance: float64Ptr(10), RequiresApproval: "Y", MinTenureDays: 365, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{LeaveTypeCode: "BEREAVEMENT", LeaveTypeName: "Bereavement Leave", AccrualFlag: "N", MaxBalance: float64Ptr(5), RequiresApproval: "N", MinTenureDays: 0, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{LeaveTypeCode: "JURY", LeaveTypeName: "Jury Duty", AccrualFlag: "N", MaxBalance: float64Ptr(10), RequiresApproval: "N", MinTenureDays: 0, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{LeaveTypeCode: "UNPAID", LeaveTypeName: "Unpaid Leave", AccrualFlag: "N", RequiresApproval: "Y", MinTenureDays: 0, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
	}
	for i := range leaveTypes {
		db.Create(&leaveTypes[i])
	}

	// --- Holidays (01_reference_data.sql) ---
	holidays := []models.Holiday{
		{HolidayName: "New Year's Day", HolidayDate: time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{HolidayName: "Martin Luther King Jr. Day", HolidayDate: time.Date(2024, 1, 15, 0, 0, 0, 0, time.UTC), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{HolidayName: "Presidents' Day", HolidayDate: time.Date(2024, 2, 19, 0, 0, 0, 0, time.UTC), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{HolidayName: "Memorial Day", HolidayDate: time.Date(2024, 5, 27, 0, 0, 0, 0, time.UTC), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{HolidayName: "Independence Day", HolidayDate: time.Date(2024, 7, 4, 0, 0, 0, 0, time.UTC), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{HolidayName: "Labor Day", HolidayDate: time.Date(2024, 9, 2, 0, 0, 0, 0, time.UTC), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{HolidayName: "Thanksgiving", HolidayDate: time.Date(2024, 11, 28, 0, 0, 0, 0, time.UTC), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{HolidayName: "Christmas Day", HolidayDate: time.Date(2024, 12, 25, 0, 0, 0, 0, time.UTC), SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
	}
	for i := range holidays {
		db.Create(&holidays[i])
	}

	// --- Pay Elements (01_reference_data.sql) ---
	payElements := []models.PayElement{
		{ElementCode: "BASE_PAY", ElementName: "Base Pay", ElementType: "EARNING", CalculationType: "FLAT", PretaxFlag: "N", GLAccountCode: strPtr("5100"), PriorityOrder: 1, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{ElementCode: "OVERTIME", ElementName: "Overtime Pay", ElementType: "EARNING", CalculationType: "HOURS", PretaxFlag: "N", GLAccountCode: strPtr("5110"), PriorityOrder: 2, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{ElementCode: "BONUS", ElementName: "Performance Bonus", ElementType: "EARNING", CalculationType: "FLAT", PretaxFlag: "N", GLAccountCode: strPtr("5120"), PriorityOrder: 3, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{ElementCode: "COMMISSION", ElementName: "Sales Commission", ElementType: "EARNING", CalculationType: "PERCENTAGE", DefaultPct: float64Ptr(5.0), PretaxFlag: "N", GLAccountCode: strPtr("5130"), PriorityOrder: 4, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{ElementCode: "401K", ElementName: "401(k) Contribution", ElementType: "DEDUCTION", CalculationType: "PERCENTAGE", DefaultPct: float64Ptr(6.0), PretaxFlag: "Y", GLAccountCode: strPtr("2100"), PriorityOrder: 10, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{ElementCode: "HEALTH_INS", ElementName: "Health Insurance", ElementType: "BENEFIT", CalculationType: "FLAT", DefaultAmount: float64Ptr(450.00), PretaxFlag: "Y", GLAccountCode: strPtr("2110"), PriorityOrder: 11, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{ElementCode: "DENTAL_INS", ElementName: "Dental Insurance", ElementType: "BENEFIT", CalculationType: "FLAT", DefaultAmount: float64Ptr(75.00), PretaxFlag: "Y", GLAccountCode: strPtr("2120"), PriorityOrder: 12, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{ElementCode: "VISION_INS", ElementName: "Vision Insurance", ElementType: "BENEFIT", CalculationType: "FLAT", DefaultAmount: float64Ptr(25.00), PretaxFlag: "Y", GLAccountCode: strPtr("2130"), PriorityOrder: 13, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{ElementCode: "LIFE_INS", ElementName: "Life Insurance", ElementType: "BENEFIT", CalculationType: "FLAT", DefaultAmount: float64Ptr(35.00), PretaxFlag: "N", GLAccountCode: strPtr("2140"), PriorityOrder: 14, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{ElementCode: "PARKING", ElementName: "Parking Deduction", ElementType: "DEDUCTION", CalculationType: "FLAT", DefaultAmount: float64Ptr(100.00), PretaxFlag: "Y", GLAccountCode: strPtr("2200"), PriorityOrder: 20, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
	}
	for i := range payElements {
		db.Create(&payElements[i])
	}

	// --- System Parameters (01_reference_data.sql) ---
	sysParams := []models.SystemParameter{
		{Category: "SYSTEM", ParamName: "COMPANY_NAME", ParamValue: strPtr("HRMS Corporation"), DataType: "VARCHAR", SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{Category: "SYSTEM", ParamName: "FISCAL_YEAR_START", ParamValue: strPtr("10"), DataType: "NUMBER", SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{Category: "PAYROLL", ParamName: "DEFAULT_PAY_FREQUENCY", ParamValue: strPtr("MONTHLY"), DataType: "VARCHAR", SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{Category: "PAYROLL", ParamName: "SS_WAGE_BASE", ParamValue: strPtr("168600"), DataType: "NUMBER", SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{Category: "LEAVE", ParamName: "MAX_CONSECUTIVE_DAYS", ParamValue: strPtr("15"), DataType: "NUMBER", SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{Category: "SECURITY", ParamName: "SESSION_TIMEOUT_MIN", ParamValue: strPtr("30"), DataType: "NUMBER", SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{Category: "SECURITY", ParamName: "MAX_LOGIN_ATTEMPTS", ParamValue: strPtr("5"), DataType: "NUMBER", SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{Category: "NOTIFICATION", ParamName: "SMTP_HOST", ParamValue: strPtr("smtp.internal.company.com"), DataType: "VARCHAR", SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{Category: "NOTIFICATION", ParamName: "SMTP_PORT", ParamValue: strPtr("25"), DataType: "NUMBER", SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{Category: "NOTIFICATION", ParamName: "SMTP_FROM", ParamValue: strPtr("hrms-noreply@company.com"), DataType: "VARCHAR", SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
	}
	for i := range sysParams {
		db.Create(&sysParams[i])
	}

	// --- Lookup Values (01_reference_data.sql) ---
	lookups := []models.LookupValue{
		{LookupType: "EMPLOYMENT_STATUS", LookupCode: "ACTIVE", LookupValue: "Active", DisplayOrder: 1, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{LookupType: "EMPLOYMENT_STATUS", LookupCode: "TERMINATED", LookupValue: "Terminated", DisplayOrder: 2, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{LookupType: "EMPLOYMENT_STATUS", LookupCode: "ON_LEAVE", LookupValue: "On Leave", DisplayOrder: 3, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{LookupType: "EMPLOYMENT_STATUS", LookupCode: "SUSPENDED", LookupValue: "Suspended", DisplayOrder: 4, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{LookupType: "EMPLOYMENT_TYPE", LookupCode: "FULL_TIME", LookupValue: "Full Time", DisplayOrder: 1, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{LookupType: "EMPLOYMENT_TYPE", LookupCode: "PART_TIME", LookupValue: "Part Time", DisplayOrder: 2, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{LookupType: "EMPLOYMENT_TYPE", LookupCode: "CONTRACT", LookupValue: "Contract", DisplayOrder: 3, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{LookupType: "EMPLOYMENT_TYPE", LookupCode: "INTERN", LookupValue: "Intern", DisplayOrder: 4, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{LookupType: "GENDER", LookupCode: "M", LookupValue: "Male", DisplayOrder: 1, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{LookupType: "GENDER", LookupCode: "F", LookupValue: "Female", DisplayOrder: 2, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{LookupType: "GENDER", LookupCode: "O", LookupValue: "Other", DisplayOrder: 3, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{LookupType: "MARITAL_STATUS", LookupCode: "SINGLE", LookupValue: "Single", DisplayOrder: 1, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{LookupType: "MARITAL_STATUS", LookupCode: "MARRIED", LookupValue: "Married", DisplayOrder: 2, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{LookupType: "MARITAL_STATUS", LookupCode: "DIVORCED", LookupValue: "Divorced", DisplayOrder: 3, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
	}
	for i := range lookups {
		db.Create(&lookups[i])
	}

	// --- Tax Brackets (01_reference_data.sql — 2024 Federal) ---
	taxBrackets := []models.TaxBracket{
		// Single
		{TaxYear: 2024, TaxType: "FEDERAL", FilingStatus: "SINGLE", BracketMin: 0, BracketMax: 11600, TaxRate: 0.10, BaseTax: 0, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{TaxYear: 2024, TaxType: "FEDERAL", FilingStatus: "SINGLE", BracketMin: 11600, BracketMax: 47150, TaxRate: 0.12, BaseTax: 1160, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{TaxYear: 2024, TaxType: "FEDERAL", FilingStatus: "SINGLE", BracketMin: 47150, BracketMax: 100525, TaxRate: 0.22, BaseTax: 5426, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{TaxYear: 2024, TaxType: "FEDERAL", FilingStatus: "SINGLE", BracketMin: 100525, BracketMax: 191950, TaxRate: 0.24, BaseTax: 17169, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{TaxYear: 2024, TaxType: "FEDERAL", FilingStatus: "SINGLE", BracketMin: 191950, BracketMax: 243725, TaxRate: 0.32, BaseTax: 39111, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{TaxYear: 2024, TaxType: "FEDERAL", FilingStatus: "SINGLE", BracketMin: 243725, BracketMax: 609350, TaxRate: 0.35, BaseTax: 55679, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{TaxYear: 2024, TaxType: "FEDERAL", FilingStatus: "SINGLE", BracketMin: 609350, BracketMax: 999999999, TaxRate: 0.37, BaseTax: 183648, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		// Married Filing Jointly
		{TaxYear: 2024, TaxType: "FEDERAL", FilingStatus: "MARRIED_JOINT", BracketMin: 0, BracketMax: 23200, TaxRate: 0.10, BaseTax: 0, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{TaxYear: 2024, TaxType: "FEDERAL", FilingStatus: "MARRIED_JOINT", BracketMin: 23200, BracketMax: 94300, TaxRate: 0.12, BaseTax: 2320, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{TaxYear: 2024, TaxType: "FEDERAL", FilingStatus: "MARRIED_JOINT", BracketMin: 94300, BracketMax: 201050, TaxRate: 0.22, BaseTax: 10852, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{TaxYear: 2024, TaxType: "FEDERAL", FilingStatus: "MARRIED_JOINT", BracketMin: 201050, BracketMax: 383900, TaxRate: 0.24, BaseTax: 34337, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{TaxYear: 2024, TaxType: "FEDERAL", FilingStatus: "MARRIED_JOINT", BracketMin: 383900, BracketMax: 487450, TaxRate: 0.32, BaseTax: 78221, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{TaxYear: 2024, TaxType: "FEDERAL", FilingStatus: "MARRIED_JOINT", BracketMin: 487450, BracketMax: 731200, TaxRate: 0.35, BaseTax: 111357, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
		{TaxYear: 2024, TaxType: "FEDERAL", FilingStatus: "MARRIED_JOINT", BracketMin: 731200, BracketMax: 999999999, TaxRate: 0.37, BaseTax: 196670, SoftDelete: models.SoftDelete{ActiveFlag: "Y"}, BaseModel: models.BaseModel{CreatedBy: "SYSTEM"}},
	}
	for i := range taxBrackets {
		db.Create(&taxBrackets[i])
	}

	log.Println("Seeding employee data...")
	seedEmployees(db, departments, jobTitles)

	log.Println("Database seeding complete.")
	return nil
}

func seedEmployees(db *gorm.DB, depts []models.Department, jobs []models.JobTitle) {
	// Create employees matching 02_employee_data.sql
	type empSeed struct {
		firstName      string
		lastName       string
		email          string
		gender         string
		deptIdx        int
		jobIdx         int
		hireDate       time.Time
		empType        string
		locationCode   string
		salary         float64
		managerEmpIdx  int // -1 = no manager, otherwise index into employees slice
	}

	seeds := []empSeed{
		{"John", "Smith", "john.smith@company.com", "M", 0, 0, time.Date(2015, 3, 15, 0, 0, 0, 0, time.UTC), "FULL_TIME", "NYC", 350000, -1},            // CEO
		{"Sarah", "Johnson", "sarah.johnson@company.com", "F", 2, 1, time.Date(2016, 7, 1, 0, 0, 0, 0, time.UTC), "FULL_TIME", "NYC", 280000, 0},          // CFO
		{"Michael", "Chen", "michael.chen@company.com", "M", 3, 2, time.Date(2016, 1, 15, 0, 0, 0, 0, time.UTC), "FULL_TIME", "SF", 300000, 0},            // CTO
		{"Emily", "Williams", "emily.williams@company.com", "F", 1, 5, time.Date(2017, 4, 1, 0, 0, 0, 0, time.UTC), "FULL_TIME", "NYC", 175000, 0},        // Dir HR
		{"David", "Brown", "david.brown@company.com", "M", 3, 3, time.Date(2017, 9, 1, 0, 0, 0, 0, time.UTC), "FULL_TIME", "SF", 220000, 2},               // VP Eng
		{"Jessica", "Davis", "jessica.davis@company.com", "F", 4, 4, time.Date(2018, 1, 15, 0, 0, 0, 0, time.UTC), "FULL_TIME", "CHI", 210000, 0},         // VP Sales
		{"Robert", "Miller", "robert.miller@company.com", "M", 2, 6, time.Date(2018, 6, 1, 0, 0, 0, 0, time.UTC), "FULL_TIME", "NYC", 180000, 1},          // Dir Finance
		{"Jennifer", "Wilson", "jennifer.wilson@company.com", "F", 3, 7, time.Date(2019, 2, 1, 0, 0, 0, 0, time.UTC), "FULL_TIME", "SF", 155000, 4},        // Eng Mgr
		{"James", "Taylor", "james.taylor@company.com", "M", 3, 8, time.Date(2019, 8, 15, 0, 0, 0, 0, time.UTC), "FULL_TIME", "SF", 125000, 7},            // Sr SWE
		{"Amanda", "Anderson", "amanda.anderson@company.com", "F", 3, 9, time.Date(2020, 1, 6, 0, 0, 0, 0, time.UTC), "FULL_TIME", "SF", 95000, 7},         // SWE
		{"Christopher", "Thomas", "chris.thomas@company.com", "M", 3, 10, time.Date(2023, 6, 12, 0, 0, 0, 0, time.UTC), "FULL_TIME", "SF", 55000, 7},       // Jr SWE
		{"Lisa", "Jackson", "lisa.jackson@company.com", "F", 1, 11, time.Date(2019, 5, 1, 0, 0, 0, 0, time.UTC), "FULL_TIME", "NYC", 115000, 3},            // HR Mgr
		{"Daniel", "White", "daniel.white@company.com", "M", 1, 12, time.Date(2021, 3, 15, 0, 0, 0, 0, time.UTC), "FULL_TIME", "NYC", 65000, 11},           // HR Spec
		{"Michelle", "Harris", "michelle.harris@company.com", "F", 2, 13, time.Date(2020, 9, 1, 0, 0, 0, 0, time.UTC), "FULL_TIME", "NYC", 62000, 6},       // Accountant
		{"Kevin", "Martin", "kevin.martin@company.com", "M", 2, 14, time.Date(2019, 4, 15, 0, 0, 0, 0, time.UTC), "FULL_TIME", "NYC", 85000, 6},           // Sr Accountant
		{"Patricia", "Garcia", "patricia.garcia@company.com", "F", 4, 16, time.Date(2020, 2, 1, 0, 0, 0, 0, time.UTC), "FULL_TIME", "CHI", 120000, 5},      // Sales Mgr
		{"Brian", "Martinez", "brian.martinez@company.com", "M", 4, 15, time.Date(2021, 7, 1, 0, 0, 0, 0, time.UTC), "FULL_TIME", "CHI", 60000, 15},        // Sales Rep
		{"Nicole", "Robinson", "nicole.robinson@company.com", "F", 4, 15, time.Date(2022, 1, 15, 0, 0, 0, 0, time.UTC), "FULL_TIME", "DAL", 58000, 15},     // Sales Rep
		{"Steven", "Clark", "steven.clark@company.com", "M", 5, 17, time.Date(2021, 5, 1, 0, 0, 0, 0, time.UTC), "FULL_TIME", "NYC", 62000, 3},             // Mkt Spec
		{"Rachel", "Lewis", "rachel.lewis@company.com", "F", 7, 18, time.Date(2020, 11, 1, 0, 0, 0, 0, time.UTC), "FULL_TIME", "SF", 90000, 2},             // Sys Admin
		{"Matthew", "Lee", "matthew.lee@company.com", "M", 3, 9, time.Date(2022, 4, 1, 0, 0, 0, 0, time.UTC), "FULL_TIME", "SF", 88000, 7},                 // SWE
		{"Angela", "Walker", "angela.walker@company.com", "F", 3, 10, time.Date(2023, 9, 1, 0, 0, 0, 0, time.UTC), "FULL_TIME", "SF", 50000, 7},            // Jr SWE
		{"Thomas", "Hall", "thomas.hall@company.com", "M", 6, 8, time.Date(2020, 3, 15, 0, 0, 0, 0, time.UTC), "FULL_TIME", "ATL", 95000, 3},               // Sr SWE (OPS dept / wrong idx but close)
		{"Laura", "Allen", "laura.allen@company.com", "F", 8, 13, time.Date(2021, 8, 1, 0, 0, 0, 0, time.UTC), "FULL_TIME", "NYC", 68000, 6},               // Accountant (Legal dept)
		{"Ryan", "Young", "ryan.young@company.com", "M", 3, 19, time.Date(2024, 1, 15, 0, 0, 0, 0, time.UTC), "INTERN", "SF", 35000, 7},                    // Intern
	}

	var employees []*models.Employee
	for i, s := range seeds {
		locCode := s.locationCode
		email := s.email
		gender := s.gender
		emp := &models.Employee{
			EmpNumber:        fmt.Sprintf("EMP-%06d", 10001+i),
			FirstName:        s.firstName,
			LastName:         s.lastName,
			Email:            &email,
			Gender:           &gender,
			DeptID:           depts[s.deptIdx].DeptID,
			JobID:            jobs[s.jobIdx].JobID,
			HireDate:         s.hireDate,
			EmploymentType:   s.empType,
			EmploymentStatus: "ACTIVE",
			LocationCode:     &locCode,
			SoftDelete:       models.SoftDelete{ActiveFlag: "Y"},
			BaseModel:        models.BaseModel{CreatedBy: "SYSTEM"},
		}
		db.Create(emp)
		employees = append(employees, emp)
	}

	// Set manager references
	for i, s := range seeds {
		if s.managerEmpIdx >= 0 && s.managerEmpIdx < len(employees) {
			mgrID := employees[s.managerEmpIdx].EmpID
			db.Model(employees[i]).Update("manager_emp_id", mgrID)
		}
	}

	// Create salary records for each employee
	for i, s := range seeds {
		salary := models.SalaryRecord{
			EmpID:         employees[i].EmpID,
			EffectiveDate: s.hireDate,
			BaseSalary:    s.salary,
			CurrencyCode:  "USD",
			PayFrequency:  "MONTHLY",
			SalaryBasis:   "ANNUAL",
			SoftDelete:    models.SoftDelete{ActiveFlag: "Y"},
			BaseModel:     models.BaseModel{CreatedBy: "SYSTEM"},
		}
		db.Create(&salary)
	}
}

func strPtr(s string) *string       { return &s }
func float64Ptr(f float64) *float64 { return &f }
func intPtr(i int) *int             { return &i }
