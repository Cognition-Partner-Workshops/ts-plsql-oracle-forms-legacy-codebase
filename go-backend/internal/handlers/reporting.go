package handlers

import (
	"net/http"
	"strconv"
	"time"

	"github.com/Cognition-Partner-Workshops/ts-plsql-oracle-forms-legacy-codebase/go-backend/internal/services"
	"github.com/gin-gonic/gin"
)

// ReportingHandler handles reporting endpoints.
// Replaces Oracle Reports (.rdf) and PKG_REPORTING procedures.
type ReportingHandler struct {
	reporting   *services.ReportingService
	integration *services.IntegrationService
}

// NewReportingHandler creates a new ReportingHandler.
func NewReportingHandler(reporting *services.ReportingService, integration *services.IntegrationService) *ReportingHandler {
	return &ReportingHandler{reporting: reporting, integration: integration}
}

// Headcount generates a headcount report.
// GET /api/reports/headcount?as_of=2024-01-01&dept_id=1&location=NYC
func (h *ReportingHandler) Headcount(c *gin.Context) {
	asOf := time.Now()
	if d := c.Query("as_of"); d != "" {
		parsed, err := time.Parse("2006-01-02", d)
		if err == nil {
			asOf = parsed
		}
	}

	var deptID *int64
	if d := c.Query("dept_id"); d != "" {
		v, _ := strconv.ParseInt(d, 10, 64)
		deptID = &v
	}

	var location *string
	if l := c.Query("location"); l != "" {
		location = &l
	}

	rows, err := h.reporting.HeadcountReport(asOf, deptID, location)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, rows)
}

// CompensationSummary generates a compensation summary report.
// GET /api/reports/compensation?dept_id=1&grade_id=1
func (h *ReportingHandler) CompensationSummary(c *gin.Context) {
	var deptID, gradeID *int64
	if d := c.Query("dept_id"); d != "" {
		v, _ := strconv.ParseInt(d, 10, 64)
		deptID = &v
	}
	if g := c.Query("grade_id"); g != "" {
		v, _ := strconv.ParseInt(g, 10, 64)
		gradeID = &v
	}

	rows, err := h.reporting.CompensationSummary(deptID, gradeID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, rows)
}

// Turnover generates a turnover report.
// GET /api/reports/turnover?start=2024-01-01&end=2024-12-31&dept_id=1
func (h *ReportingHandler) Turnover(c *gin.Context) {
	start := c.DefaultQuery("start", time.Now().AddDate(-1, 0, 0).Format("2006-01-02"))
	end := c.DefaultQuery("end", time.Now().Format("2006-01-02"))

	startDate, _ := time.Parse("2006-01-02", start)
	endDate, _ := time.Parse("2006-01-02", end)

	var deptID *int64
	if d := c.Query("dept_id"); d != "" {
		v, _ := strconv.ParseInt(d, 10, 64)
		deptID = &v
	}

	rows, err := h.reporting.TurnoverReport(startDate, endDate, deptID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, rows)
}

// NewHires generates a new hires report.
// GET /api/reports/new-hires?start=2024-01-01&end=2024-12-31&dept_id=1
func (h *ReportingHandler) NewHires(c *gin.Context) {
	start := c.DefaultQuery("start", time.Now().AddDate(0, -3, 0).Format("2006-01-02"))
	end := c.DefaultQuery("end", time.Now().Format("2006-01-02"))

	startDate, _ := time.Parse("2006-01-02", start)
	endDate, _ := time.Parse("2006-01-02", end)

	var deptID *int64
	if d := c.Query("dept_id"); d != "" {
		v, _ := strconv.ParseInt(d, 10, 64)
		deptID = &v
	}

	rows, err := h.reporting.NewHiresReport(startDate, endDate, deptID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, rows)
}

// PayrollSummary generates a payroll summary report.
// GET /api/reports/payroll-summary?period_id=1
func (h *ReportingHandler) PayrollSummary(c *gin.Context) {
	periodID, err := strconv.ParseInt(c.Query("period_id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "period_id is required"})
		return
	}

	rows, err := h.reporting.PayrollSummaryReport(periodID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, rows)
}

// EEOCompliance generates an EEO compliance report.
// GET /api/reports/eeo?as_of=2024-01-01
func (h *ReportingHandler) EEOCompliance(c *gin.Context) {
	asOf := time.Now()
	if d := c.Query("as_of"); d != "" {
		parsed, err := time.Parse("2006-01-02", d)
		if err == nil {
			asOf = parsed
		}
	}

	rows, err := h.reporting.EEOComplianceReport(asOf)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, rows)
}

// LeaveUtilization generates a leave utilization report.
// GET /api/reports/leave-utilization?year=2024&dept_id=1
func (h *ReportingHandler) LeaveUtilization(c *gin.Context) {
	year, _ := strconv.Atoi(c.DefaultQuery("year", strconv.Itoa(time.Now().Year())))

	var deptID *int64
	if d := c.Query("dept_id"); d != "" {
		v, _ := strconv.ParseInt(d, 10, 64)
		deptID = &v
	}

	rows, err := h.reporting.LeaveUtilizationReport(year, deptID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, rows)
}

// GLJournal generates GL journal entries from a payroll run.
// GET /api/reports/gl-journal?run_id=1
func (h *ReportingHandler) GLJournal(c *gin.Context) {
	runID, err := strconv.ParseInt(c.Query("run_id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "run_id is required"})
		return
	}

	entries, err := h.integration.GenerateGLJournal(runID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, entries)
}

// GLJournalCSV exports GL journal as CSV.
// GET /api/reports/gl-journal/csv?run_id=1
func (h *ReportingHandler) GLJournalCSV(c *gin.Context) {
	runID, err := strconv.ParseInt(c.Query("run_id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "run_id is required"})
		return
	}

	csvData, err := h.integration.ExportGLJournalCSV(runID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.Header("Content-Type", "text/csv")
	c.Header("Content-Disposition", "attachment; filename=gl_journal.csv")
	c.String(http.StatusOK, csvData)
}

// BenefitsFeed exports benefits enrollment data.
// GET /api/reports/benefits-feed
func (h *ReportingHandler) BenefitsFeed(c *gin.Context) {
	rows, err := h.integration.GenerateBenefitsFeed()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, rows)
}
