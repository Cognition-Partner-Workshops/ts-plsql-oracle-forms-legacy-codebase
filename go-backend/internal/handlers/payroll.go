package handlers

import (
	"net/http"
	"strconv"
	"time"

	"github.com/Cognition-Partner-Workshops/ts-plsql-oracle-forms-legacy-codebase/go-backend/internal/services"
	"github.com/gin-gonic/gin"
)

// PayrollHandler handles payroll endpoints.
// Replaces HRMS_PAYROLL.xml Oracle Form.
type PayrollHandler struct {
	payroll *services.PayrollService
}

// NewPayrollHandler creates a new PayrollHandler.
func NewPayrollHandler(payroll *services.PayrollService) *PayrollHandler {
	return &PayrollHandler{payroll: payroll}
}

// GetCurrentSalary returns the current salary for an employee.
// GET /api/payroll/salary/:emp_id
func (h *PayrollHandler) GetCurrentSalary(c *gin.Context) {
	empID, err := strconv.ParseInt(c.Param("emp_id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid employee ID"})
		return
	}

	salary, err := h.payroll.GetCurrentSalary(empID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "no active salary record found"})
		return
	}

	c.JSON(http.StatusOK, salary)
}

// CreateSalaryRecord creates a new salary record.
// POST /api/payroll/salary
func (h *PayrollHandler) CreateSalaryRecord(c *gin.Context) {
	var req struct {
		EmpID         int64   `json:"emp_id" binding:"required"`
		BaseSalary    float64 `json:"base_salary" binding:"required"`
		CurrencyCode  string  `json:"currency_code"`
		PayFrequency  string  `json:"pay_frequency"`
		SalaryBasis   string  `json:"salary_basis"`
		EffectiveDate string  `json:"effective_date"`
		Reason        string  `json:"reason"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	effDate := time.Now()
	if req.EffectiveDate != "" {
		parsed, err := time.Parse("2006-01-02", req.EffectiveDate)
		if err == nil {
			effDate = parsed
		}
	}
	if req.CurrencyCode == "" {
		req.CurrencyCode = "USD"
	}
	if req.PayFrequency == "" {
		req.PayFrequency = "MONTHLY"
	}
	if req.SalaryBasis == "" {
		req.SalaryBasis = "ANNUAL"
	}

	user := c.GetString("username")
	if user == "" {
		user = "SYSTEM"
	}

	id, err := h.payroll.CreateSalaryRecord(req.EmpID, effDate, req.BaseSalary, req.Reason, user)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"salary_id": id})
}

// CreatePayPeriods creates pay periods for a year.
// POST /api/payroll/periods
func (h *PayrollHandler) CreatePayPeriods(c *gin.Context) {
	var req struct {
		Year      int    `json:"year" binding:"required"`
		Frequency string `json:"frequency"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if req.Frequency == "" {
		req.Frequency = "MONTHLY"
	}

	user := c.GetString("username")
	if user == "" {
		user = "SYSTEM"
	}

	count, err := h.payroll.CreatePayPeriods(req.Year, req.Frequency, user)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"periods_created": count})
}

// CreatePayrollRun creates a payroll run for a period.
// POST /api/payroll/runs
func (h *PayrollHandler) CreatePayrollRun(c *gin.Context) {
	var req struct {
		PeriodID int64 `json:"period_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	user := c.GetString("username")
	if user == "" {
		user = "SYSTEM"
	}

	runID, err := h.payroll.CreatePayrollRun(req.PeriodID, "REGULAR", user)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"run_id": runID})
}

// CalculatePayroll processes payroll for a run.
// POST /api/payroll/runs/:run_id/calculate
func (h *PayrollHandler) CalculatePayroll(c *gin.Context) {
	runID, err := strconv.ParseInt(c.Param("run_id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid run ID"})
		return
	}

	user := c.GetString("username")
	if user == "" {
		user = "SYSTEM"
	}

	if err := h.payroll.CalculatePayroll(runID, user); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "payroll calculated"})
}

// ApprovePayroll approves a payroll run.
// POST /api/payroll/runs/:run_id/approve
func (h *PayrollHandler) ApprovePayroll(c *gin.Context) {
	runID, err := strconv.ParseInt(c.Param("run_id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid run ID"})
		return
	}

	user := c.GetString("username")
	if user == "" {
		user = "SYSTEM"
	}

	if err := h.payroll.ApprovePayroll(runID, user); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "payroll approved"})
}

// GetPayslip returns payroll details for an employee in a run.
// GET /api/payroll/runs/:run_id/payslip/:emp_id
func (h *PayrollHandler) GetPayslip(c *gin.Context) {
	runID, err := strconv.ParseInt(c.Param("run_id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid run ID"})
		return
	}
	empID, err := strconv.ParseInt(c.Param("emp_id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid employee ID"})
		return
	}

	details, err := h.payroll.GetPayslip(runID, empID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "payslip not found"})
		return
	}

	c.JSON(http.StatusOK, details)
}

// GetYTDEarnings returns year-to-date earnings for an employee.
// GET /api/payroll/ytd/:emp_id?year=2024
func (h *PayrollHandler) GetYTDEarnings(c *gin.Context) {
	empID, err := strconv.ParseInt(c.Param("emp_id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid employee ID"})
		return
	}

	year, _ := strconv.Atoi(c.DefaultQuery("year", strconv.Itoa(time.Now().Year())))
	earnings := h.payroll.GetYTDEarnings(empID, year)

	c.JSON(http.StatusOK, gin.H{"emp_id": empID, "year": year, "ytd_earnings": earnings})
}
