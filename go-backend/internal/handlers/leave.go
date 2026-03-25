package handlers

import (
	"net/http"
	"strconv"
	"time"

	"github.com/Cognition-Partner-Workshops/ts-plsql-oracle-forms-legacy-codebase/go-backend/internal/models"
	"github.com/Cognition-Partner-Workshops/ts-plsql-oracle-forms-legacy-codebase/go-backend/internal/services"
	"github.com/gin-gonic/gin"
)

// LeaveHandler handles leave management endpoints.
// Replaces HRMS_LEAVE.xml Oracle Form.
type LeaveHandler struct {
	leave *services.LeaveService
}

// NewLeaveHandler creates a new LeaveHandler.
func NewLeaveHandler(leave *services.LeaveService) *LeaveHandler {
	return &LeaveHandler{leave: leave}
}

// SubmitRequest submits a new leave request.
// POST /api/leave/requests
// Replaces: HRMS_LEAVE form → PKG_LEAVE.submit_leave_request
func (h *LeaveHandler) SubmitRequest(c *gin.Context) {
	var req struct {
		EmpID       int64   `json:"emp_id" binding:"required"`
		LeaveTypeID int64   `json:"leave_type_id" binding:"required"`
		StartDate   string  `json:"start_date" binding:"required"`
		EndDate     string  `json:"end_date" binding:"required"`
		HalfDayFlag string  `json:"half_day_flag"`
		HalfDayPd   *string `json:"half_day_period"`
		Reason      *string `json:"reason"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	startDate, err := time.Parse("2006-01-02", req.StartDate)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid start_date format"})
		return
	}
	endDate, err := time.Parse("2006-01-02", req.EndDate)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid end_date format"})
		return
	}

	leaveReq := &models.LeaveRequest{
		EmpID:       req.EmpID,
		LeaveTypeID: req.LeaveTypeID,
		StartDate:   startDate,
		EndDate:     endDate,
		HalfDayFlag: req.HalfDayFlag,
		HalfDayPeriod: req.HalfDayPd,
		Reason:      req.Reason,
	}

	user := c.GetString("username")
	if user == "" {
		user = "SYSTEM"
	}

	requestID, err := h.leave.SubmitLeaveRequest(leaveReq, user)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"request_id": requestID})
}

// ApproveRequest approves a leave request.
// POST /api/leave/requests/:id/approve
func (h *LeaveHandler) ApproveRequest(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request ID"})
		return
	}

	var req struct {
		Comments string `json:"comments"`
	}
	_ = c.ShouldBindJSON(&req)

	user := c.GetString("username")
	if user == "" {
		user = "SYSTEM"
	}

	if err := h.leave.ApproveLeaveRequest(id, req.Comments, user); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "leave request approved"})
}

// RejectRequest rejects a leave request.
// POST /api/leave/requests/:id/reject
func (h *LeaveHandler) RejectRequest(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request ID"})
		return
	}

	var req struct {
		Comments string `json:"comments" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	user := c.GetString("username")
	if user == "" {
		user = "SYSTEM"
	}

	if err := h.leave.RejectLeaveRequest(id, req.Comments, user); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "leave request rejected"})
}

// CancelRequest cancels a leave request.
// POST /api/leave/requests/:id/cancel
func (h *LeaveHandler) CancelRequest(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request ID"})
		return
	}

	var req struct {
		Reason string `json:"reason" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	user := c.GetString("username")
	if user == "" {
		user = "SYSTEM"
	}

	if err := h.leave.CancelLeaveRequest(id, req.Reason, user); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "leave request cancelled"})
}

// GetBalances returns leave balances for an employee.
// GET /api/leave/balances/:emp_id?year=2024
func (h *LeaveHandler) GetBalances(c *gin.Context) {
	empID, err := strconv.ParseInt(c.Param("emp_id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid employee ID"})
		return
	}

	year, _ := strconv.Atoi(c.DefaultQuery("year", strconv.Itoa(time.Now().Year())))

	balances, err := h.leave.GetLeaveBalances(empID, year)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, balances)
}

// GetPendingRequests returns pending requests for an approver.
// GET /api/leave/pending/:approver_id
func (h *LeaveHandler) GetPendingRequests(c *gin.Context) {
	approverID, err := strconv.ParseInt(c.Param("approver_id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid approver ID"})
		return
	}

	requests, err := h.leave.GetPendingRequests(approverID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, requests)
}

// GetTeamCalendar returns team leave calendar for a manager.
// GET /api/leave/calendar/:manager_id?start=2024-01-01&end=2024-12-31
func (h *LeaveHandler) GetTeamCalendar(c *gin.Context) {
	managerID, err := strconv.ParseInt(c.Param("manager_id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid manager ID"})
		return
	}

	start := c.DefaultQuery("start", time.Now().Format("2006-01-02"))
	end := c.DefaultQuery("end", time.Now().AddDate(0, 1, 0).Format("2006-01-02"))

	startDate, _ := time.Parse("2006-01-02", start)
	endDate, _ := time.Parse("2006-01-02", end)

	calendar, err := h.leave.GetTeamCalendar(managerID, startDate, endDate)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, calendar)
}

// RunAccrual processes monthly leave accrual.
// POST /api/leave/accrual
func (h *LeaveHandler) RunAccrual(c *gin.Context) {
	var req struct {
		AccrualDate string `json:"accrual_date"`
	}
	_ = c.ShouldBindJSON(&req)

	accrualDate := time.Now()
	if req.AccrualDate != "" {
		parsed, err := time.Parse("2006-01-02", req.AccrualDate)
		if err == nil {
			accrualDate = parsed
		}
	}

	user := c.GetString("username")
	if user == "" {
		user = "SYSTEM"
	}

	empCount, totalAccrued, err := h.leave.RunMonthlyAccrual(accrualDate, user)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"employees_processed": empCount,
		"total_accrued":       totalAccrued,
	})
}

// ProcessCarryover processes year-end leave carryover.
// POST /api/leave/carryover
func (h *LeaveHandler) ProcessCarryover(c *gin.Context) {
	var req struct {
		Year int `json:"year" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	user := c.GetString("username")
	if user == "" {
		user = "SYSTEM"
	}

	if err := h.leave.ProcessCarryover(req.Year, user); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "carryover processed"})
}
