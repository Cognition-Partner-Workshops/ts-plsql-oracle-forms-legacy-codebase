package services

import (
	"log"
	"time"

	"github.com/Cognition-Partner-Workshops/ts-plsql-oracle-forms-legacy-codebase/go-backend/internal/models"
	"gorm.io/gorm"
)

// NotificationService migrates PKG_NOTIFICATION — email, in-app, and SMS notifications.
type NotificationService struct {
	db       *gorm.DB
	smtpHost string
	smtpPort string
	smtpFrom string
}

// NewNotificationService creates a new NotificationService.
func NewNotificationService(db *gorm.DB, smtpHost, smtpPort, smtpFrom string) *NotificationService {
	return &NotificationService{
		db:       db,
		smtpHost: smtpHost,
		smtpPort: smtpPort,
		smtpFrom: smtpFrom,
	}
}

// SendNotification queues a notification for delivery.
// Mirrors: PKG_NOTIFICATION.send_notification (PRAGMA AUTONOMOUS_TRANSACTION)
func (s *NotificationService) SendNotification(
	recipientEmpID *int64,
	recipientEmail *string,
	notificationType string,
	subject string,
	body string,
	priority int,
	referenceTable *string,
	referenceID *int64,
	user string,
) error {
	// If recipient is an employee, look up their email
	if recipientEmpID != nil && (recipientEmail == nil || *recipientEmail == "") {
		var emp models.Employee
		if err := s.db.Select("email").Where("emp_id = ?", *recipientEmpID).First(&emp).Error; err == nil {
			recipientEmail = emp.Email
		}
	}

	notification := models.NotificationQueue{
		RecipientEmpID:   recipientEmpID,
		RecipientEmail:   recipientEmail,
		NotificationType: notificationType,
		Subject:          subject,
		Body:             body,
		Status:           "PENDING",
		Priority:         priority,
		ReferenceTable:   referenceTable,
		ReferenceID:      referenceID,
		BaseModel:        models.BaseModel{CreatedBy: user},
	}

	return s.db.Create(&notification).Error
}

// ProcessQueue processes pending notifications in batches.
// Mirrors: PKG_NOTIFICATION.process_queue
func (s *NotificationService) ProcessQueue(batchSize int, user string) (int, int, error) {
	var notifications []models.NotificationQueue
	err := s.db.Where("status = 'PENDING'").
		Order("priority ASC, created_date ASC").
		Limit(batchSize).
		Find(&notifications).Error
	if err != nil {
		return 0, 0, err
	}

	sent := 0
	failed := 0
	now := time.Now()

	for i := range notifications {
		n := &notifications[i]
		// In a real implementation, this would send via SMTP/SMS/push.
		// For now, we log and mark as sent.
		if n.NotificationType == "EMAIL" && n.RecipientEmail != nil {
			log.Printf("[NOTIFICATION] Sending email to %s: %s", *n.RecipientEmail, n.Subject)
			n.Status = "SENT"
			n.SentDate = &now
			sent++
		} else if n.NotificationType == "IN_APP" {
			log.Printf("[NOTIFICATION] In-app notification for emp %v: %s", n.RecipientEmpID, n.Subject)
			n.Status = "SENT"
			n.SentDate = &now
			sent++
		} else {
			errMsg := "unsupported notification type or missing recipient"
			n.Status = "FAILED"
			n.ErrorMessage = &errMsg
			n.RetryCount++
			failed++
		}

		s.db.Model(n).Updates(map[string]interface{}{
			"status":        n.Status,
			"sent_date":     n.SentDate,
			"error_message": n.ErrorMessage,
			"retry_count":   n.RetryCount,
			"modified_by":   user,
			"modified_date": now,
		})
	}

	return sent, failed, nil
}

// RetryFailed resets failed notifications for retry.
// Mirrors: PKG_NOTIFICATION.retry_failed
func (s *NotificationService) RetryFailed(maxRetries int, user string) (int64, error) {
	result := s.db.Model(&models.NotificationQueue{}).
		Where("status = 'FAILED' AND retry_count < ?", maxRetries).
		Updates(map[string]interface{}{
			"status":        "PENDING",
			"modified_by":   user,
			"modified_date": time.Now(),
		})
	return result.RowsAffected, result.Error
}

// CancelNotification cancels a pending notification.
// Mirrors: PKG_NOTIFICATION.cancel_notification
func (s *NotificationService) CancelNotification(notificationID int64, user string) error {
	result := s.db.Model(&models.NotificationQueue{}).
		Where("notification_id = ? AND status = 'PENDING'", notificationID).
		Updates(map[string]interface{}{
			"status":        "CANCELLED",
			"modified_by":   user,
			"modified_date": time.Now(),
		})
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return result.Error
}
