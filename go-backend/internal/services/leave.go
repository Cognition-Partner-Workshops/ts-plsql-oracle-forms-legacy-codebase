package services

import (
	"errors"
	"fmt"
	"time"

	"github.com/Cognition-Partner-Workshops/ts-plsql-oracle-forms-legacy-codebase/go-backend/internal/models"
	"gorm.io/gorm"
)

// LeaveService migrates PKG_LEAVE — leave requests, approvals, balance tracking, accrual.
type LeaveService struct {
	db           *gorm.DB
	audit        *AuditService
	notification *NotificationService
}

// NewLeaveService creates a new LeaveService.
func NewLeaveService(db *gorm.DB, audit *AuditService, notification *NotificationService) *LeaveService {
	return &LeaveService{
		db:           db,
		audit:        audit,
		notification: notification,
	}
}

// CalculateBusinessDays counts weekdays excluding holidays between two dates.
// Mirrors: PKG_LEAVE.calculate_business_days
func (s *LeaveService) CalculateBusinessDays(startDate, endDate time.Time, locationCode *string) (float64, error) {
	// Get holidays
	var holidays []models.Holiday
	query := s.db.Where("holiday_date BETWEEN ? AND ? AND active_flag = 'Y'", startDate, endDate)
	if locationCode != nil {
		query = query.Where("location_code IS NULL OR location_code = ?", *locationCode)
	}
	query.Find(&holidays)

	holidayMap := make(map[string]bool)
	for _, h := range holidays {
		holidayMap[h.HolidayDate.Format("2006-01-02")] = true
	}

	days := 0.0
	current := startDate
	for !current.After(endDate) {
		wd := current.Weekday()
		if wd != time.Saturday && wd != time.Sunday {
			if !holidayMap[current.Format("2006-01-02")] {
				days++
			}
		}
		current = current.AddDate(0, 0, 1)
	}
	return days, nil
}

// CheckLeaveOverlap checks for overlapping leave requests.
// Mirrors: PKG_LEAVE.check_leave_overlap
func (s *LeaveService) CheckLeaveOverlap(empID int64, startDate, endDate time.Time, excludeRequestID *int64) (bool, error) {
	query := s.db.Model(&models.LeaveRequest{}).
		Where("emp_id = ? AND status IN ('PENDING', 'APPROVED') AND start_date <= ? AND end_date >= ?",
			empID, endDate, startDate)
	if excludeRequestID != nil {
		query = query.Where("request_id != ?", *excludeRequestID)
	}

	var count int64
	err := query.Count(&count).Error
	return count > 0, err
}

// SubmitLeaveRequest creates a new leave request.
// Mirrors: PKG_LEAVE.submit_leave_request
func (s *LeaveService) SubmitLeaveRequest(req *models.LeaveRequest, user string) (int64, error) {
	var requestID int64

	err := s.db.Transaction(func(tx *gorm.DB) error {
		// Validate employee
		var emp models.Employee
		if err := tx.Where("emp_id = ? AND employment_status = 'ACTIVE'", req.EmpID).First(&emp).Error; err != nil {
			return fmt.Errorf("employee not found or not active: %w", err)
		}

		// Validate leave type
		var leaveType models.LeaveType
		if err := tx.Where("leave_type_id = ? AND active_flag = 'Y'", req.LeaveTypeID).First(&leaveType).Error; err != nil {
			return fmt.Errorf("leave type not found or inactive: %w", err)
		}

		// Check minimum tenure
		if leaveType.MinTenureDays > 0 {
			tenure := time.Since(emp.HireDate).Hours() / 24
			if int(tenure) < leaveType.MinTenureDays {
				return fmt.Errorf("minimum tenure of %d days required for %s", leaveType.MinTenureDays, leaveType.LeaveTypeName)
			}
		}

		// Validate dates
		if req.EndDate.Before(req.StartDate) {
			return errors.New("end date cannot be before start date")
		}

		// Check overlap
		hasOverlap, err := s.CheckLeaveOverlap(req.EmpID, req.StartDate, req.EndDate, nil)
		if err != nil {
			return err
		}
		if hasOverlap {
			return errors.New("overlapping leave request exists")
		}

		// Calculate total days if not provided
		if req.TotalDays <= 0 {
			days, err := s.CalculateBusinessDays(req.StartDate, req.EndDate, emp.LocationCode)
			if err != nil {
				return err
			}
			if req.HalfDayFlag == "Y" {
				days = 0.5
			}
			req.TotalDays = days
		}

		// Check balance
		balance := s.GetLeaveBalance(tx, req.EmpID, req.LeaveTypeID, req.StartDate.Year())
		if balance < req.TotalDays {
			return fmt.Errorf("insufficient leave balance: available %.1f, requested %.1f", balance, req.TotalDays)
		}

		// Set approver (manager)
		req.ApproverEmpID = emp.ManagerEmpID
		req.Status = "PENDING"
		req.BaseModel = models.BaseModel{CreatedBy: user}

		if err := tx.Create(req).Error; err != nil {
			return err
		}
		requestID = req.RequestID

		// Update pending balance
		tx.Model(&models.LeaveBalance{}).
			Where("emp_id = ? AND leave_type_id = ? AND calendar_year = ?",
				req.EmpID, req.LeaveTypeID, req.StartDate.Year()).
			Update("pending", gorm.Expr("pending + ?", req.TotalDays))

		// Auto-approve if no approval required
		if leaveType.RequiresApproval == "N" {
			return s.approveRequest(tx, requestID, user, "Auto-approved")
		}

		// Notify approver
		if req.ApproverEmpID != nil {
			subject := "Leave Request Pending Approval"
			body := fmt.Sprintf("%s %s has submitted a %s request for %.1f days (%s to %s).",
				emp.FirstName, emp.LastName, leaveType.LeaveTypeName, req.TotalDays,
				req.StartDate.Format("2006-01-02"), req.EndDate.Format("2006-01-02"))
			refTable := "LEAVE_REQUESTS"
			_ = s.notification.SendNotification(req.ApproverEmpID, nil, "EMAIL", subject, body, 3, &refTable, &requestID, user)
		}

		return nil
	})

	return requestID, err
}

// ApproveLeaveRequest approves a pending leave request.
// Mirrors: PKG_LEAVE.approve_leave_request
func (s *LeaveService) ApproveLeaveRequest(requestID int64, comments, user string) error {
	return s.db.Transaction(func(tx *gorm.DB) error {
		return s.approveRequest(tx, requestID, user, comments)
	})
}

func (s *LeaveService) approveRequest(tx *gorm.DB, requestID int64, user, comments string) error {
	var req models.LeaveRequest
	if err := tx.Where("request_id = ? AND status = 'PENDING'", requestID).First(&req).Error; err != nil {
		return fmt.Errorf("leave request not found or not in PENDING status: %w", err)
	}

	now := time.Now()
	tx.Model(&req).Updates(map[string]interface{}{
		"status":            "APPROVED",
		"approval_date":     now,
		"approval_comments": comments,
		"modified_by":       user,
		"modified_date":     now,
	})

	// Move from pending to used
	tx.Model(&models.LeaveBalance{}).
		Where("emp_id = ? AND leave_type_id = ? AND calendar_year = ?",
			req.EmpID, req.LeaveTypeID, req.StartDate.Year()).
		Updates(map[string]interface{}{
			"pending": gorm.Expr("pending - ?", req.TotalDays),
			"used":    gorm.Expr("used + ?", req.TotalDays),
		})

	_ = s.audit.LogAction("LEAVE_REQUESTS", requestID, "APPROVE", user)

	// Notify employee
	subject := "Leave Request Approved"
	body := fmt.Sprintf("Your leave request from %s to %s has been approved.",
		req.StartDate.Format("2006-01-02"), req.EndDate.Format("2006-01-02"))
	refTable := "LEAVE_REQUESTS"
	_ = s.notification.SendNotification(&req.EmpID, nil, "EMAIL", subject, body, 5, &refTable, &requestID, user)

	return nil
}

// RejectLeaveRequest rejects a pending leave request.
// Mirrors: PKG_LEAVE.reject_leave_request
func (s *LeaveService) RejectLeaveRequest(requestID int64, comments, user string) error {
	return s.db.Transaction(func(tx *gorm.DB) error {
		var req models.LeaveRequest
		if err := tx.Where("request_id = ? AND status = 'PENDING'", requestID).First(&req).Error; err != nil {
			return fmt.Errorf("leave request not found or not in PENDING status: %w", err)
		}

		now := time.Now()
		tx.Model(&req).Updates(map[string]interface{}{
			"status":            "REJECTED",
			"approval_comments": comments,
			"modified_by":       user,
			"modified_date":     now,
		})

		// Release pending balance
		tx.Model(&models.LeaveBalance{}).
			Where("emp_id = ? AND leave_type_id = ? AND calendar_year = ?",
				req.EmpID, req.LeaveTypeID, req.StartDate.Year()).
			Update("pending", gorm.Expr("pending - ?", req.TotalDays))

		_ = s.audit.LogAction("LEAVE_REQUESTS", requestID, "REJECT", user)

		// Notify employee
		subject := "Leave Request Rejected"
		body := fmt.Sprintf("Your leave request from %s to %s has been rejected. Reason: %s",
			req.StartDate.Format("2006-01-02"), req.EndDate.Format("2006-01-02"), comments)
		refTable := "LEAVE_REQUESTS"
		_ = s.notification.SendNotification(&req.EmpID, nil, "EMAIL", subject, body, 5, &refTable, &requestID, user)

		return nil
	})
}

// CancelLeaveRequest cancels a pending or approved leave request.
// Mirrors: PKG_LEAVE.cancel_leave_request
func (s *LeaveService) CancelLeaveRequest(requestID int64, reason, user string) error {
	return s.db.Transaction(func(tx *gorm.DB) error {
		var req models.LeaveRequest
		if err := tx.Where("request_id = ? AND status IN ('PENDING', 'APPROVED')", requestID).First(&req).Error; err != nil {
			return fmt.Errorf("leave request not found or cannot be cancelled: %w", err)
		}

		now := time.Now()
		tx.Model(&req).Updates(map[string]interface{}{
			"status":         "CANCELLED",
			"cancel_reason":  reason,
			"cancelled_date": now,
			"modified_by":    user,
			"modified_date":  now,
		})

		// Restore balance
		if req.Status == "PENDING" {
			tx.Model(&models.LeaveBalance{}).
				Where("emp_id = ? AND leave_type_id = ? AND calendar_year = ?",
					req.EmpID, req.LeaveTypeID, req.StartDate.Year()).
				Update("pending", gorm.Expr("pending - ?", req.TotalDays))
		} else if req.Status == "APPROVED" {
			tx.Model(&models.LeaveBalance{}).
				Where("emp_id = ? AND leave_type_id = ? AND calendar_year = ?",
					req.EmpID, req.LeaveTypeID, req.StartDate.Year()).
				Update("used", gorm.Expr("used - ?", req.TotalDays))
		}

		_ = s.audit.LogAction("LEAVE_REQUESTS", requestID, "CANCEL", user)
		return nil
	})
}

// GetLeaveBalance returns the available leave balance.
// Mirrors: PKG_LEAVE.get_leave_balance (virtual column AVAILABLE)
func (s *LeaveService) GetLeaveBalance(tx *gorm.DB, empID, leaveTypeID int64, year int) float64 {
	var balance models.LeaveBalance
	err := tx.Where("emp_id = ? AND leave_type_id = ? AND calendar_year = ?", empID, leaveTypeID, year).
		First(&balance).Error
	if err != nil {
		return 0
	}
	return balance.Available()
}

// GetLeaveBalances returns all leave balances for an employee in a year.
func (s *LeaveService) GetLeaveBalances(empID int64, year int) ([]models.LeaveBalance, error) {
	var balances []models.LeaveBalance
	err := s.db.Preload("LeaveType").
		Where("emp_id = ? AND calendar_year = ?", empID, year).
		Find(&balances).Error
	return balances, err
}

// AdjustLeaveBalance adds an adjustment amount to a leave balance.
// Mirrors: PKG_LEAVE.adjust_leave_balance
func (s *LeaveService) AdjustLeaveBalance(empID, leaveTypeID int64, year int, amount float64, reason, user string) error {
	result := s.db.Model(&models.LeaveBalance{}).
		Where("emp_id = ? AND leave_type_id = ? AND calendar_year = ?", empID, leaveTypeID, year).
		Updates(map[string]interface{}{
			"adjustment":    gorm.Expr("adjustment + ?", amount),
			"modified_by":   user,
			"modified_date": time.Now(),
		})
	if result.RowsAffected == 0 {
		return errors.New("leave balance not found")
	}
	return result.Error
}

// InitializeBalances creates leave balance records for an employee for all active leave types.
// Mirrors: PKG_LEAVE.initialize_balances
func (s *LeaveService) InitializeBalances(empID int64, year int, user string) error {
	var leaveTypes []models.LeaveType
	s.db.Where("active_flag = 'Y'").Find(&leaveTypes)

	for _, lt := range leaveTypes {
		var count int64
		s.db.Model(&models.LeaveBalance{}).
			Where("emp_id = ? AND leave_type_id = ? AND calendar_year = ?", empID, lt.LeaveTypeID, year).
			Count(&count)
		if count == 0 {
			balance := models.LeaveBalance{
				EmpID:       empID,
				LeaveTypeID: lt.LeaveTypeID,
				CalendarYear: year,
				BaseModel:   models.BaseModel{CreatedBy: user},
			}
			s.db.Create(&balance)
		}
	}
	return nil
}

// RunMonthlyAccrual processes monthly leave accrual for all active employees.
// Mirrors: PKG_LEAVE.run_monthly_accrual
func (s *LeaveService) RunMonthlyAccrual(accrualDate time.Time, user string) (int, float64, error) {
	totalEmployees := 0
	totalAccrued := 0.0

	var employees []models.Employee
	s.db.Where("employment_status = 'ACTIVE'").Find(&employees)

	var leaveTypes []models.LeaveType
	s.db.Where("active_flag = 'Y' AND accrual_flag = 'Y' AND accrual_frequency = 'MONTHLY'").Find(&leaveTypes)

	for _, emp := range employees {
		totalEmployees++
		for _, lt := range leaveTypes {
			// Check minimum tenure
			if lt.MinTenureDays > 0 {
				tenure := accrualDate.Sub(emp.HireDate).Hours() / 24
				if int(tenure) < lt.MinTenureDays {
					continue
				}
			}

			// Get current balance
			currentBalance := s.GetLeaveBalance(s.db, emp.EmpID, lt.LeaveTypeID, accrualDate.Year())

			// Calculate accrual amount (cap at max balance)
			accrualAmount := 0.0
			if lt.AccrualRate != nil {
				accrualAmount = *lt.AccrualRate
			}
			if lt.MaxBalance != nil {
				if currentBalance+accrualAmount > *lt.MaxBalance {
					accrualAmount = *lt.MaxBalance - currentBalance
					if accrualAmount < 0 {
						accrualAmount = 0
					}
				}
			}

			if accrualAmount > 0 {
				// Ensure balance record exists
				s.InitializeBalances(emp.EmpID, accrualDate.Year(), user)

				// Update balance
				s.db.Model(&models.LeaveBalance{}).
					Where("emp_id = ? AND leave_type_id = ? AND calendar_year = ?",
						emp.EmpID, lt.LeaveTypeID, accrualDate.Year()).
					Updates(map[string]interface{}{
						"accrued":       gorm.Expr("accrued + ?", accrualAmount),
						"modified_by":   user,
						"modified_date": time.Now(),
					})

				// Log accrual
				log := models.LeaveAccrualLog{
					EmpID:         emp.EmpID,
					LeaveTypeID:   lt.LeaveTypeID,
					AccrualDate:   accrualDate,
					AccrualAmount: accrualAmount,
					CreatedBy:     user,
				}
				s.db.Create(&log)

				totalAccrued += accrualAmount
			}
		}
	}

	return totalEmployees, totalAccrued, nil
}

// ProcessCarryover handles year-end carryover of unused leave to the next year.
// Mirrors: PKG_LEAVE.process_carryover
func (s *LeaveService) ProcessCarryover(year int, user string) error {
	nextYear := year + 1

	type balanceResult struct {
		EmpID           int64
		LeaveTypeID     int64
		Remaining       float64
		CarryoverMax    *float64
		CarryoverExpiry *int
	}

	var results []balanceResult
	s.db.Raw(`
		SELECT lb.emp_id, lb.leave_type_id,
			(lb.opening_balance + lb.accrued - lb.used + lb.adjustment) as remaining,
			lt.carryover_max, lt.carryover_expiry
		FROM leave_balances lb
		JOIN leave_types lt ON lb.leave_type_id = lt.leave_type_id
		WHERE lb.calendar_year = ?
		AND (lb.opening_balance + lb.accrued - lb.used + lb.adjustment) > 0
	`, year).Scan(&results)

	for _, r := range results {
		carryover := r.Remaining
		if r.CarryoverMax != nil && carryover > *r.CarryoverMax {
			carryover = *r.CarryoverMax
		}
		if carryover <= 0 {
			continue
		}

		// Initialize next year balance
		s.InitializeBalances(r.EmpID, nextYear, user)

		updates := map[string]interface{}{
			"carryover_from_prev": carryover,
			"opening_balance":     carryover,
			"modified_by":         user,
			"modified_date":       time.Now(),
		}

		if r.CarryoverExpiry != nil && *r.CarryoverExpiry > 0 {
			expiryDate := time.Date(nextYear, 1, 1, 0, 0, 0, 0, time.UTC).AddDate(0, *r.CarryoverExpiry, 0)
			updates["carryover_expiry_dt"] = expiryDate
		}

		s.db.Model(&models.LeaveBalance{}).
			Where("emp_id = ? AND leave_type_id = ? AND calendar_year = ?", r.EmpID, r.LeaveTypeID, nextYear).
			Updates(updates)
	}

	return nil
}

// ExpireCarryover removes expired carryover balances.
// Mirrors: PKG_LEAVE.expire_carryover
func (s *LeaveService) ExpireCarryover(user string) error {
	now := time.Now()
	s.db.Model(&models.LeaveBalance{}).
		Where("carryover_expiry_dt <= ? AND carryover_from_prev > 0", now).
		Updates(map[string]interface{}{
			"adjustment":        gorm.Expr("adjustment - carryover_from_prev"),
			"carryover_from_prev": 0,
			"modified_by":       user,
			"modified_date":     now,
		})
	return nil
}

// GetPendingRequests returns pending leave requests for an approver.
// Mirrors: PKG_LEAVE.get_pending_requests
func (s *LeaveService) GetPendingRequests(approverID int64) ([]models.LeaveRequest, error) {
	var requests []models.LeaveRequest
	err := s.db.Preload("Employee").Preload("LeaveType").
		Where("approver_emp_id = ? AND status = 'PENDING'", approverID).
		Order("created_date").
		Find(&requests).Error
	return requests, err
}

// GetTeamCalendar returns leave calendar for a manager's team.
// Mirrors: PKG_LEAVE.get_team_calendar
func (s *LeaveService) GetTeamCalendar(managerID int64, startDate, endDate time.Time) ([]models.LeaveRequest, error) {
	var requests []models.LeaveRequest
	err := s.db.Preload("Employee").Preload("LeaveType").
		Joins("JOIN employees ON leave_requests.emp_id = employees.emp_id").
		Where("employees.manager_emp_id = ? AND leave_requests.status IN ('APPROVED', 'TAKEN') AND leave_requests.start_date <= ? AND leave_requests.end_date >= ?",
			managerID, endDate, startDate).
		Order("leave_requests.start_date").
		Find(&requests).Error
	return requests, err
}
