package models

import "time"

// ReviewCycle mirrors HRMS.REVIEW_CYCLES table.
type ReviewCycle struct {
	CycleID          int64      `gorm:"column:cycle_id;primaryKey;autoIncrement" json:"cycle_id"`
	CycleName        string     `gorm:"column:cycle_name;size:100;not null" json:"cycle_name"`
	CycleYear        int        `gorm:"column:cycle_year;not null" json:"cycle_year"`
	StartDate        time.Time  `gorm:"column:start_date;not null" json:"start_date"`
	EndDate          time.Time  `gorm:"column:end_date;not null" json:"end_date"`
	SelfReviewDue    *time.Time `gorm:"column:self_review_due" json:"self_review_due,omitempty"`
	ManagerReviewDue *time.Time `gorm:"column:manager_review_due" json:"manager_review_due,omitempty"`
	Status           string     `gorm:"column:status;size:20;default:'DRAFT'" json:"status"`
	BaseModel
}

func (ReviewCycle) TableName() string { return "review_cycles" }

// PerformanceReview mirrors HRMS.PERFORMANCE_REVIEWS table.
type PerformanceReview struct {
	ReviewID           int64      `gorm:"column:review_id;primaryKey;autoIncrement" json:"review_id"`
	CycleID            int64      `gorm:"column:cycle_id;not null;index" json:"cycle_id"`
	EmpID              int64      `gorm:"column:emp_id;not null;index" json:"emp_id"`
	ReviewerEmpID      int64      `gorm:"column:reviewer_emp_id;not null" json:"reviewer_emp_id"`
	ReviewType         string     `gorm:"column:review_type;size:20;default:'ANNUAL'" json:"review_type"`
	Status             string     `gorm:"column:status;size:20;default:'NOT_STARTED'" json:"status"`
	SelfAssessment     *string    `gorm:"column:self_assessment;type:text" json:"self_assessment,omitempty"`
	ManagerAssessment  *string    `gorm:"column:manager_assessment;type:text" json:"manager_assessment,omitempty"`
	OverallRating      *float64   `gorm:"column:overall_rating;type:decimal(3,1)" json:"overall_rating,omitempty"`
	RatingLabel        *string    `gorm:"column:rating_label;size:50" json:"rating_label,omitempty"`
	Strengths          *string    `gorm:"column:strengths;type:text" json:"strengths,omitempty"`
	AreasForImprovement *string   `gorm:"column:areas_for_improvement;type:text" json:"areas_for_improvement,omitempty"`
	DevelopmentPlan    *string    `gorm:"column:development_plan;type:text" json:"development_plan,omitempty"`
	EmployeeComments   *string    `gorm:"column:employee_comments;type:text" json:"employee_comments,omitempty"`
	EmployeeAckDate    *time.Time `gorm:"column:employee_ack_date" json:"employee_ack_date,omitempty"`
	BaseModel

	Cycle    *ReviewCycle `gorm:"foreignKey:CycleID;references:CycleID" json:"cycle,omitempty"`
	Employee *Employee    `gorm:"foreignKey:EmpID;references:EmpID" json:"employee,omitempty"`
	Reviewer *Employee    `gorm:"foreignKey:ReviewerEmpID;references:EmpID" json:"reviewer,omitempty"`
}

func (PerformanceReview) TableName() string { return "performance_reviews" }

// PerformanceGoal mirrors HRMS.PERFORMANCE_GOALS table.
type PerformanceGoal struct {
	GoalID          int64      `gorm:"column:goal_id;primaryKey;autoIncrement" json:"goal_id"`
	ReviewID        *int64     `gorm:"column:review_id;index" json:"review_id,omitempty"`
	EmpID           int64      `gorm:"column:emp_id;not null;index" json:"emp_id"`
	GoalTitle       string     `gorm:"column:goal_title;size:200;not null" json:"goal_title"`
	GoalDescription *string    `gorm:"column:goal_description;type:text" json:"goal_description,omitempty"`
	GoalCategory    string     `gorm:"column:goal_category;size:30;default:'BUSINESS'" json:"goal_category"`
	WeightPct       float64    `gorm:"column:weight_pct;type:decimal(5,2);default:0" json:"weight_pct"`
	TargetDate      *time.Time `gorm:"column:target_date" json:"target_date,omitempty"`
	Status          string     `gorm:"column:status;size:20;default:'NOT_STARTED'" json:"status"`
	ProgressPct     float64    `gorm:"column:progress_pct;type:decimal(5,2);default:0" json:"progress_pct"`
	Comments        *string    `gorm:"column:comments;type:text" json:"comments,omitempty"`
	BaseModel
}

func (PerformanceGoal) TableName() string { return "performance_goals" }
