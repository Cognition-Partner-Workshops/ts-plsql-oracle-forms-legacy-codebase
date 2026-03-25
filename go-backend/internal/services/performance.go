package services

import (
	"errors"
	"fmt"
	"time"

	"github.com/Cognition-Partner-Workshops/ts-plsql-oracle-forms-legacy-codebase/go-backend/internal/models"
	"gorm.io/gorm"
)

// PerformanceService migrates PKG_PERFORMANCE — review cycles, goal tracking, ratings.
type PerformanceService struct {
	db           *gorm.DB
	audit        *AuditService
	notification *NotificationService
}

// NewPerformanceService creates a new PerformanceService.
func NewPerformanceService(db *gorm.DB, audit *AuditService, notification *NotificationService) *PerformanceService {
	return &PerformanceService{
		db:           db,
		audit:        audit,
		notification: notification,
	}
}

// CreateReviewCycle creates a new performance review cycle.
// Mirrors: PKG_PERFORMANCE.create_review_cycle
func (s *PerformanceService) CreateReviewCycle(cycleName string, cycleYear int, startDate, endDate time.Time, selfReviewDue, managerReviewDue *time.Time, user string) (int64, error) {
	cycle := models.ReviewCycle{
		CycleName:        cycleName,
		CycleYear:        cycleYear,
		StartDate:        startDate,
		EndDate:          endDate,
		SelfReviewDue:    selfReviewDue,
		ManagerReviewDue: managerReviewDue,
		Status:           "DRAFT",
		BaseModel:        models.BaseModel{CreatedBy: user},
	}
	if err := s.db.Create(&cycle).Error; err != nil {
		return 0, err
	}
	_ = s.audit.LogAction("REVIEW_CYCLES", cycle.CycleID, "INSERT", user)
	return cycle.CycleID, nil
}

// OpenReviewCycle opens a draft review cycle.
// Mirrors: PKG_PERFORMANCE.open_review_cycle
func (s *PerformanceService) OpenReviewCycle(cycleID int64, user string) error {
	result := s.db.Model(&models.ReviewCycle{}).
		Where("cycle_id = ? AND status = 'DRAFT'", cycleID).
		Updates(map[string]interface{}{
			"status":        "OPEN",
			"modified_by":   user,
			"modified_date": time.Now(),
		})
	if result.RowsAffected == 0 {
		return errors.New("cannot open cycle - must be in DRAFT status")
	}
	return result.Error
}

// CloseReviewCycle closes a review cycle.
// Mirrors: PKG_PERFORMANCE.close_review_cycle
func (s *PerformanceService) CloseReviewCycle(cycleID int64, user string) error {
	return s.db.Model(&models.ReviewCycle{}).
		Where("cycle_id = ?", cycleID).
		Updates(map[string]interface{}{
			"status":        "CLOSED",
			"modified_by":   user,
			"modified_date": time.Now(),
		}).Error
}

// CreateReview creates a performance review for an employee.
// Mirrors: PKG_PERFORMANCE.create_review
func (s *PerformanceService) CreateReview(cycleID, empID, reviewerEmpID int64, user string) (int64, error) {
	review := models.PerformanceReview{
		CycleID:       cycleID,
		EmpID:         empID,
		ReviewerEmpID: reviewerEmpID,
		ReviewType:    "ANNUAL",
		Status:        "NOT_STARTED",
		BaseModel:     models.BaseModel{CreatedBy: user},
	}
	if err := s.db.Create(&review).Error; err != nil {
		return 0, err
	}

	// Notify employee
	subject := "Performance Review Initiated"
	body := "Your annual performance review has been initiated. Please complete your self-assessment."
	refTable := "PERFORMANCE_REVIEWS"
	_ = s.notification.SendNotification(&empID, nil, "EMAIL", subject, body, 5, &refTable, &review.ReviewID, user)

	return review.ReviewID, nil
}

// SubmitSelfAssessment submits an employee's self-assessment.
// Mirrors: PKG_PERFORMANCE.submit_self_assessment
func (s *PerformanceService) SubmitSelfAssessment(reviewID int64, selfAssessment, user string) error {
	result := s.db.Model(&models.PerformanceReview{}).
		Where("review_id = ? AND status IN ('NOT_STARTED', 'SELF_REVIEW')", reviewID).
		Updates(map[string]interface{}{
			"self_assessment": selfAssessment,
			"status":          "MANAGER_REVIEW",
			"modified_by":     user,
			"modified_date":   time.Now(),
		})
	if result.RowsAffected == 0 {
		return errors.New("review not found or not in correct status")
	}

	// Notify manager
	var review models.PerformanceReview
	if err := s.db.Where("review_id = ?", reviewID).First(&review).Error; err == nil {
		subject := "Self-Assessment Submitted - Ready for Manager Review"
		body := "An employee has completed their self-assessment. Please proceed with the manager review."
		refTable := "PERFORMANCE_REVIEWS"
		_ = s.notification.SendNotification(&review.ReviewerEmpID, nil, "EMAIL", subject, body, 5, &refTable, &reviewID, user)
	}

	return result.Error
}

// SubmitManagerReview submits a manager's review with rating.
// Mirrors: PKG_PERFORMANCE.submit_manager_review
func (s *PerformanceService) SubmitManagerReview(reviewID int64, overallRating float64, managerAssessment string, strengths, improvementAreas, developmentPlan *string, user string) error {
	if overallRating < 1.0 || overallRating > 5.0 {
		return errors.New("rating must be between 1.0 and 5.0")
	}

	// Determine rating label
	ratingLabel := ratingToLabel(overallRating)

	result := s.db.Model(&models.PerformanceReview{}).
		Where("review_id = ?", reviewID).
		Updates(map[string]interface{}{
			"overall_rating":       overallRating,
			"rating_label":         ratingLabel,
			"manager_assessment":   managerAssessment,
			"strengths":            strengths,
			"areas_for_improvement": improvementAreas,
			"development_plan":     developmentPlan,
			"status":               "COMPLETED",
			"modified_by":          user,
			"modified_date":        time.Now(),
		})

	// Notify employee
	var review models.PerformanceReview
	if err := s.db.Where("review_id = ?", reviewID).First(&review).Error; err == nil {
		subject := "Performance Review Completed"
		body := "Your manager has completed your performance review. Please review and acknowledge."
		refTable := "PERFORMANCE_REVIEWS"
		_ = s.notification.SendNotification(&review.EmpID, nil, "EMAIL", subject, body, 5, &refTable, &reviewID, user)
	}

	return result.Error
}

// AcknowledgeReview acknowledges a completed review.
// Mirrors: PKG_PERFORMANCE.acknowledge_review
func (s *PerformanceService) AcknowledgeReview(reviewID int64, empComments *string, user string) error {
	now := time.Now()
	result := s.db.Model(&models.PerformanceReview{}).
		Where("review_id = ? AND status = 'COMPLETED'", reviewID).
		Updates(map[string]interface{}{
			"employee_comments":  empComments,
			"employee_ack_date":  now,
			"status":             "ACKNOWLEDGED",
			"modified_by":        user,
			"modified_date":      now,
		})
	if result.RowsAffected == 0 {
		return errors.New("review not found or not in COMPLETED status")
	}
	return result.Error
}

// AddGoal adds a goal to a performance review.
// Mirrors: PKG_PERFORMANCE.add_goal
func (s *PerformanceService) AddGoal(reviewID *int64, empID int64, goalTitle string, goalDescription *string, goalCategory string, weightPct float64, targetDate *time.Time, user string) (int64, error) {
	goal := models.PerformanceGoal{
		ReviewID:        reviewID,
		EmpID:           empID,
		GoalTitle:       goalTitle,
		GoalDescription: goalDescription,
		GoalCategory:    goalCategory,
		WeightPct:       weightPct,
		TargetDate:      targetDate,
		Status:          "NOT_STARTED",
		ProgressPct:     0,
		BaseModel:       models.BaseModel{CreatedBy: user},
	}
	if err := s.db.Create(&goal).Error; err != nil {
		return 0, err
	}
	return goal.GoalID, nil
}

// UpdateGoalProgress updates the progress of a goal.
// Mirrors: PKG_PERFORMANCE.update_goal_progress
func (s *PerformanceService) UpdateGoalProgress(goalID int64, progressPct float64, status *string, comments *string, user string) error {
	updates := map[string]interface{}{
		"progress_pct":  progressPct,
		"modified_by":   user,
		"modified_date": time.Now(),
	}

	if status != nil {
		updates["status"] = *status
	} else {
		if progressPct >= 100 {
			updates["status"] = "COMPLETED"
		} else if progressPct > 0 {
			updates["status"] = "IN_PROGRESS"
		}
	}

	if comments != nil {
		updates["comments"] = *comments
	}

	return s.db.Model(&models.PerformanceGoal{}).
		Where("goal_id = ?", goalID).
		Updates(updates).Error
}

// GetTeamReviews returns reviews for a manager's team in a cycle.
// Mirrors: PKG_PERFORMANCE.get_team_reviews
func (s *PerformanceService) GetTeamReviews(managerID, cycleID int64) ([]models.PerformanceReview, error) {
	var reviews []models.PerformanceReview
	err := s.db.Preload("Employee").Preload("Employee.Job").Preload("Employee.Department").
		Where("reviewer_emp_id = ? AND cycle_id = ?", managerID, cycleID).
		Order("created_date").
		Find(&reviews).Error
	return reviews, err
}

// GetRatingDistribution returns the distribution of ratings for a cycle.
// Mirrors: PKG_PERFORMANCE.get_rating_distribution
func (s *PerformanceService) GetRatingDistribution(cycleID int64, deptID *int64) ([]map[string]interface{}, error) {
	query := s.db.Model(&models.PerformanceReview{}).
		Select("rating_label, COUNT(*) as count").
		Where("cycle_id = ? AND overall_rating IS NOT NULL", cycleID)

	if deptID != nil {
		query = query.Joins("JOIN employees ON performance_reviews.emp_id = employees.emp_id").
			Where("employees.dept_id = ?", *deptID)
	}

	var results []map[string]interface{}
	err := query.Group("rating_label").Order("MIN(overall_rating) DESC").
		Find(&results).Error
	return results, err
}

// GenerateReviewsForCycle creates reviews for all active employees in a cycle.
// Mirrors: PKG_PERFORMANCE.generate_reviews_for_cycle
func (s *PerformanceService) GenerateReviewsForCycle(cycleID int64, user string) (int, error) {
	var employees []models.Employee
	s.db.Where("employment_status = 'ACTIVE' AND manager_emp_id IS NOT NULL").Find(&employees)

	count := 0
	for _, emp := range employees {
		// Check if review already exists
		var existing int64
		s.db.Model(&models.PerformanceReview{}).
			Where("cycle_id = ? AND emp_id = ?", cycleID, emp.EmpID).
			Count(&existing)
		if existing > 0 {
			continue
		}

		if emp.ManagerEmpID != nil {
			_, err := s.CreateReview(cycleID, emp.EmpID, *emp.ManagerEmpID, user)
			if err == nil {
				count++
			}
		}
	}

	return count, nil
}

// GetGoals returns goals for an employee.
func (s *PerformanceService) GetGoals(empID int64, reviewID *int64) ([]models.PerformanceGoal, error) {
	var goals []models.PerformanceGoal
	query := s.db.Where("emp_id = ?", empID)
	if reviewID != nil {
		query = query.Where("review_id = ?", *reviewID)
	}
	err := query.Order("created_date DESC").Find(&goals).Error
	return goals, err
}

// ratingToLabel converts a numeric rating to a label.
func ratingToLabel(rating float64) string {
	switch {
	case rating >= 4.5:
		return "Exceptional"
	case rating >= 3.5:
		return "Exceeds Expectations"
	case rating >= 2.5:
		return "Meets Expectations"
	case rating >= 1.5:
		return "Needs Improvement"
	default:
		return "Unsatisfactory"
	}
}

// GetReview returns a single performance review by ID.
func (s *PerformanceService) GetReview(reviewID int64) (*models.PerformanceReview, error) {
	var review models.PerformanceReview
	err := s.db.Preload("Employee").Preload("Reviewer").Preload("Cycle").
		Where("review_id = ?", reviewID).First(&review).Error
	if err != nil {
		return nil, fmt.Errorf("review not found: %w", err)
	}
	return &review, nil
}
