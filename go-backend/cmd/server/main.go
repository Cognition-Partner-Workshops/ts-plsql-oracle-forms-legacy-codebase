package main

import (
	"log"

	"github.com/Cognition-Partner-Workshops/ts-plsql-oracle-forms-legacy-codebase/go-backend/internal/config"
	"github.com/Cognition-Partner-Workshops/ts-plsql-oracle-forms-legacy-codebase/go-backend/internal/database"
	"github.com/Cognition-Partner-Workshops/ts-plsql-oracle-forms-legacy-codebase/go-backend/internal/handlers"
	"github.com/Cognition-Partner-Workshops/ts-plsql-oracle-forms-legacy-codebase/go-backend/internal/middleware"
	"github.com/Cognition-Partner-Workshops/ts-plsql-oracle-forms-legacy-codebase/go-backend/internal/services"
	"github.com/gin-gonic/gin"
)

func main() {
	// Load configuration
	cfg := config.Load()

	// Connect to database
	db, err := database.Connect(cfg.DatabaseDSN)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	// Run auto-migration
	if err := database.AutoMigrate(db); err != nil {
		log.Fatalf("Failed to migrate database: %v", err)
	}

	// Register GORM hooks (migrated Oracle triggers)
	middleware.RegisterGORMHooks(db)

	// Seed reference data
	if err := database.SeedData(db); err != nil {
		log.Fatalf("Failed to seed database: %v", err)
	}

	// Initialize services (mirrors PL/SQL package initialization order)
	commonSvc := services.NewCommonService(db)
	auditSvc := services.NewAuditService(db)
	validationSvc := services.NewValidationService(db)
	notificationSvc := services.NewNotificationService(db, cfg.SMTPHost, cfg.SMTPPort, cfg.SMTPFrom)
	securitySvc := services.NewSecurityService(db, auditSvc, cfg.EncryptionKey, cfg.SessionTimeout)
	payrollSvc := services.NewPayrollService(db, auditSvc, notificationSvc)
	employeeSvc := services.NewEmployeeService(db, auditSvc, notificationSvc, validationSvc)
	leaveSvc := services.NewLeaveService(db, auditSvc, notificationSvc)
	performanceSvc := services.NewPerformanceService(db, auditSvc, notificationSvc)
	reportingSvc := services.NewReportingService(db, commonSvc)
	integrationSvc := services.NewIntegrationService(db, auditSvc, commonSvc)

	// Initialize handlers
	authHandler := handlers.NewAuthHandler(securitySvc)
	employeeHandler := handlers.NewEmployeeHandler(employeeSvc)
	payrollHandler := handlers.NewPayrollHandler(payrollSvc)
	leaveHandler := handlers.NewLeaveHandler(leaveSvc)
	performanceHandler := handlers.NewPerformanceHandler(performanceSvc)
	reportingHandler := handlers.NewReportingHandler(reportingSvc, integrationSvc)
	adminHandler := handlers.NewAdminHandler(db)

	// Setup Gin router
	r := gin.Default()

	// Health check
	r.GET("/api/health", adminHandler.HealthCheck)

	// Auth routes (no auth middleware)
	auth := r.Group("/api/auth")
	{
		auth.POST("/login", authHandler.Login)
		auth.POST("/logout", authHandler.Logout)
		auth.POST("/change-password", authHandler.ChangePassword)
	}

	// Protected API routes
	api := r.Group("/api")
	api.Use(middleware.AuthMiddleware(securitySvc))
	api.Use(middleware.AuditMiddleware(auditSvc))

	// Admin / lookup routes (replacing Oracle Forms LOVs)
	admin := api.Group("/admin")
	{
		admin.GET("/departments", adminHandler.GetDepartments)
		admin.GET("/job-titles", adminHandler.GetJobTitles)
		admin.GET("/job-grades", adminHandler.GetJobGrades)
		admin.GET("/locations", adminHandler.GetLocations)
		admin.GET("/leave-types", adminHandler.GetLeaveTypes)
		admin.GET("/lookups", adminHandler.GetLookupValues)
		admin.GET("/holidays", adminHandler.GetHolidays)
		admin.GET("/pay-elements", adminHandler.GetPayElements)
	}

	// Employee routes (replacing HRMS_EMPLOYEE.xml form)
	employees := api.Group("/employees")
	{
		employees.POST("", employeeHandler.Create)
		employees.GET("", employeeHandler.Search)
		employees.GET("/:id", employeeHandler.Get)
		employees.PUT("/:id", employeeHandler.Update)
		employees.POST("/:id/transfer", employeeHandler.Transfer)
		employees.POST("/:id/promote", employeeHandler.Promote)
		employees.POST("/:id/terminate", employeeHandler.Terminate)
		employees.POST("/:id/rehire", employeeHandler.Rehire)
		employees.GET("/:id/direct-reports", employeeHandler.GetDirectReports)
		employees.GET("/:id/org-chart", employeeHandler.GetOrgChart)
		employees.GET("/:id/history", employeeHandler.GetHistory)
		employees.GET("/:id/dependents", employeeHandler.GetDependents)
		employees.GET("/:id/emergency-contacts", employeeHandler.GetEmergencyContacts)
	}

	// Payroll routes (replacing HRMS_PAYROLL.xml form)
	payroll := api.Group("/payroll")
	{
		payroll.GET("/salary/:emp_id", payrollHandler.GetCurrentSalary)
		payroll.POST("/salary", payrollHandler.CreateSalaryRecord)
		payroll.POST("/periods", payrollHandler.CreatePayPeriods)
		payroll.POST("/runs", payrollHandler.CreatePayrollRun)
		payroll.POST("/runs/:run_id/calculate", payrollHandler.CalculatePayroll)
		payroll.POST("/runs/:run_id/approve", payrollHandler.ApprovePayroll)
		payroll.GET("/runs/:run_id/payslip/:emp_id", payrollHandler.GetPayslip)
		payroll.GET("/ytd/:emp_id", payrollHandler.GetYTDEarnings)
	}

	// Leave routes (replacing HRMS_LEAVE.xml form)
	leave := api.Group("/leave")
	{
		leave.POST("/requests", leaveHandler.SubmitRequest)
		leave.POST("/requests/:id/approve", leaveHandler.ApproveRequest)
		leave.POST("/requests/:id/reject", leaveHandler.RejectRequest)
		leave.POST("/requests/:id/cancel", leaveHandler.CancelRequest)
		leave.GET("/balances/:emp_id", leaveHandler.GetBalances)
		leave.GET("/pending/:approver_id", leaveHandler.GetPendingRequests)
		leave.GET("/calendar/:manager_id", leaveHandler.GetTeamCalendar)
		leave.POST("/accrual", leaveHandler.RunAccrual)
		leave.POST("/carryover", leaveHandler.ProcessCarryover)
	}

	// Performance routes (replacing HRMS_PERFORMANCE.xml form)
	performance := api.Group("/performance")
	{
		performance.POST("/cycles", performanceHandler.CreateReviewCycle)
		performance.POST("/cycles/:id/open", performanceHandler.OpenReviewCycle)
		performance.POST("/cycles/:id/generate", performanceHandler.GenerateReviews)
		performance.GET("/cycles/:id/distribution", performanceHandler.GetRatingDistribution)
		performance.GET("/reviews/:id", performanceHandler.GetReview)
		performance.POST("/reviews/:id/self-assessment", performanceHandler.SubmitSelfAssessment)
		performance.POST("/reviews/:id/manager-review", performanceHandler.SubmitManagerReview)
		performance.POST("/reviews/:id/acknowledge", performanceHandler.AcknowledgeReview)
		performance.GET("/reviews/team/:manager_id", performanceHandler.GetTeamReviews)
		performance.POST("/goals", performanceHandler.AddGoal)
		performance.PUT("/goals/:id/progress", performanceHandler.UpdateGoalProgress)
		performance.GET("/goals/:emp_id", performanceHandler.GetGoals)
	}

	// Reports routes (replacing Oracle Reports .rdf files)
	reports := api.Group("/reports")
	{
		reports.GET("/headcount", reportingHandler.Headcount)
		reports.GET("/compensation", reportingHandler.CompensationSummary)
		reports.GET("/turnover", reportingHandler.Turnover)
		reports.GET("/new-hires", reportingHandler.NewHires)
		reports.GET("/payroll-summary", reportingHandler.PayrollSummary)
		reports.GET("/eeo", reportingHandler.EEOCompliance)
		reports.GET("/leave-utilization", reportingHandler.LeaveUtilization)
		reports.GET("/gl-journal", reportingHandler.GLJournal)
		reports.GET("/gl-journal/csv", reportingHandler.GLJournalCSV)
		reports.GET("/benefits-feed", reportingHandler.BenefitsFeed)
	}

	// Start server
	log.Printf("HRMS Go Backend starting on port %s", cfg.ServerPort)
	if err := r.Run(":" + cfg.ServerPort); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
