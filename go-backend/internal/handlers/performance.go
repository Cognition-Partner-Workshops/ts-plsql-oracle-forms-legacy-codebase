package handlers

import (
	"net/http"
	"strconv"
	"time"

	"github.com/Cognition-Partner-Workshops/ts-plsql-oracle-forms-legacy-codebase/go-backend/internal/services"
	"github.com/gin-gonic/gin"
)

// PerformanceHandler handles performance review endpoints.
// Replaces HRMS_PERFORMANCE.xml Oracle Form.
type PerformanceHandler struct {
	performance *services.PerformanceService
}

// NewPerformanceHandler creates a new PerformanceHandler.
func NewPerformanceHandler(performance *services.PerformanceService) *PerformanceHandler {
	return &PerformanceHandler{performance: performance}
}

// CreateReviewCycle creates a new review cycle.
// POST /api/performance/cycles
func (h *PerformanceHandler) CreateReviewCycle(c *gin.Context) {
	var req struct {
		CycleName        string  `json:"cycle_name" binding:"required"`
		CycleYear        int     `json:"cycle_year" binding:"required"`
		StartDate        string  `json:"start_date" binding:"required"`
		EndDate          string  `json:"end_date" binding:"required"`
		SelfReviewDue    *string `json:"self_review_due"`
		ManagerReviewDue *string `json:"manager_review_due"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	startDate, err := time.Parse("2006-01-02", req.StartDate)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid start_date"})
		return
	}
	endDate, err := time.Parse("2006-01-02", req.EndDate)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid end_date"})
		return
	}

	var selfDue, mgrDue *time.Time
	if req.SelfReviewDue != nil {
		t, err := time.Parse("2006-01-02", *req.SelfReviewDue)
		if err == nil {
			selfDue = &t
		}
	}
	if req.ManagerReviewDue != nil {
		t, err := time.Parse("2006-01-02", *req.ManagerReviewDue)
		if err == nil {
			mgrDue = &t
		}
	}

	user := c.GetString("username")
	if user == "" {
		user = "SYSTEM"
	}

	cycleID, err := h.performance.CreateReviewCycle(req.CycleName, req.CycleYear, startDate, endDate, selfDue, mgrDue, user)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"cycle_id": cycleID})
}

// OpenReviewCycle opens a review cycle.
// POST /api/performance/cycles/:id/open
func (h *PerformanceHandler) OpenReviewCycle(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid cycle ID"})
		return
	}

	user := c.GetString("username")
	if user == "" {
		user = "SYSTEM"
	}

	if err := h.performance.OpenReviewCycle(id, user); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "review cycle opened"})
}

// GenerateReviews generates reviews for all employees in a cycle.
// POST /api/performance/cycles/:id/generate
func (h *PerformanceHandler) GenerateReviews(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid cycle ID"})
		return
	}

	user := c.GetString("username")
	if user == "" {
		user = "SYSTEM"
	}

	count, err := h.performance.GenerateReviewsForCycle(id, user)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"reviews_created": count})
}

// GetReview returns a single review.
// GET /api/performance/reviews/:id
func (h *PerformanceHandler) GetReview(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid review ID"})
		return
	}

	review, err := h.performance.GetReview(id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "review not found"})
		return
	}

	c.JSON(http.StatusOK, review)
}

// SubmitSelfAssessment submits a self-assessment.
// POST /api/performance/reviews/:id/self-assessment
func (h *PerformanceHandler) SubmitSelfAssessment(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid review ID"})
		return
	}

	var req struct {
		SelfAssessment string `json:"self_assessment" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	user := c.GetString("username")
	if user == "" {
		user = "SYSTEM"
	}

	if err := h.performance.SubmitSelfAssessment(id, req.SelfAssessment, user); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "self-assessment submitted"})
}

// SubmitManagerReview submits a manager review with rating.
// POST /api/performance/reviews/:id/manager-review
func (h *PerformanceHandler) SubmitManagerReview(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid review ID"})
		return
	}

	var req struct {
		OverallRating       float64 `json:"overall_rating" binding:"required"`
		ManagerAssessment   string  `json:"manager_assessment" binding:"required"`
		Strengths           *string `json:"strengths"`
		AreasForImprovement *string `json:"areas_for_improvement"`
		DevelopmentPlan     *string `json:"development_plan"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	user := c.GetString("username")
	if user == "" {
		user = "SYSTEM"
	}

	if err := h.performance.SubmitManagerReview(id, req.OverallRating, req.ManagerAssessment, req.Strengths, req.AreasForImprovement, req.DevelopmentPlan, user); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "manager review submitted"})
}

// AcknowledgeReview acknowledges a completed review.
// POST /api/performance/reviews/:id/acknowledge
func (h *PerformanceHandler) AcknowledgeReview(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid review ID"})
		return
	}

	var req struct {
		Comments *string `json:"comments"`
	}
	_ = c.ShouldBindJSON(&req)

	user := c.GetString("username")
	if user == "" {
		user = "SYSTEM"
	}

	if err := h.performance.AcknowledgeReview(id, req.Comments, user); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "review acknowledged"})
}

// GetTeamReviews returns reviews for a manager's team.
// GET /api/performance/reviews/team/:manager_id?cycle_id=1
func (h *PerformanceHandler) GetTeamReviews(c *gin.Context) {
	managerID, err := strconv.ParseInt(c.Param("manager_id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid manager ID"})
		return
	}

	cycleID, err := strconv.ParseInt(c.Query("cycle_id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "cycle_id is required"})
		return
	}

	reviews, err := h.performance.GetTeamReviews(managerID, cycleID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, reviews)
}

// AddGoal adds a goal.
// POST /api/performance/goals
func (h *PerformanceHandler) AddGoal(c *gin.Context) {
	var req struct {
		ReviewID        *int64  `json:"review_id"`
		EmpID           int64   `json:"emp_id" binding:"required"`
		GoalTitle       string  `json:"goal_title" binding:"required"`
		GoalDescription *string `json:"goal_description"`
		GoalCategory    string  `json:"goal_category" binding:"required"`
		WeightPct       float64 `json:"weight_pct"`
		TargetDate      *string `json:"target_date"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var targetDate *time.Time
	if req.TargetDate != nil {
		t, err := time.Parse("2006-01-02", *req.TargetDate)
		if err == nil {
			targetDate = &t
		}
	}

	user := c.GetString("username")
	if user == "" {
		user = "SYSTEM"
	}

	goalID, err := h.performance.AddGoal(req.ReviewID, req.EmpID, req.GoalTitle, req.GoalDescription, req.GoalCategory, req.WeightPct, targetDate, user)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"goal_id": goalID})
}

// UpdateGoalProgress updates a goal's progress.
// PUT /api/performance/goals/:id/progress
func (h *PerformanceHandler) UpdateGoalProgress(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid goal ID"})
		return
	}

	var req struct {
		ProgressPct float64 `json:"progress_pct" binding:"required"`
		Status      *string `json:"status"`
		Comments    *string `json:"comments"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	user := c.GetString("username")
	if user == "" {
		user = "SYSTEM"
	}

	if err := h.performance.UpdateGoalProgress(id, req.ProgressPct, req.Status, req.Comments, user); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "goal progress updated"})
}

// GetGoals returns goals for an employee.
// GET /api/performance/goals/:emp_id?review_id=1
func (h *PerformanceHandler) GetGoals(c *gin.Context) {
	empID, err := strconv.ParseInt(c.Param("emp_id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid employee ID"})
		return
	}

	var reviewID *int64
	if rid := c.Query("review_id"); rid != "" {
		v, _ := strconv.ParseInt(rid, 10, 64)
		reviewID = &v
	}

	goals, err := h.performance.GetGoals(empID, reviewID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, goals)
}

// GetRatingDistribution returns rating distribution for a cycle.
// GET /api/performance/cycles/:id/distribution?dept_id=1
func (h *PerformanceHandler) GetRatingDistribution(c *gin.Context) {
	cycleID, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid cycle ID"})
		return
	}

	var deptID *int64
	if d := c.Query("dept_id"); d != "" {
		v, _ := strconv.ParseInt(d, 10, 64)
		deptID = &v
	}

	dist, err := h.performance.GetRatingDistribution(cycleID, deptID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, dist)
}
