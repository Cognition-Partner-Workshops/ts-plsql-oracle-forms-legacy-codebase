package services

import (
	"encoding/json"
	"time"

	"github.com/Cognition-Partner-Workshops/ts-plsql-oracle-forms-legacy-codebase/go-backend/internal/models"
	"gorm.io/gorm"
)

// AuditService migrates PKG_AUDIT — centralized audit trail logging.
type AuditService struct {
	db *gorm.DB
}

// NewAuditService creates a new AuditService.
func NewAuditService(db *gorm.DB) *AuditService {
	return &AuditService{db: db}
}

// LogAction records an audit entry for a DML action.
// Mirrors: PKG_AUDIT.log_action (PRAGMA AUTONOMOUS_TRANSACTION)
func (s *AuditService) LogAction(tableName string, recordID int64, actionType, changedBy string) error {
	entry := models.AuditLog{
		AuditTableName: tableName,
		RecordID:       recordID,
		ActionType:     actionType,
		ChangedBy:      changedBy,
		ChangedDate:    time.Now(),
	}
	return s.db.Create(&entry).Error
}

// LogActionWithValues records an audit entry with old/new values as JSON.
// Mirrors: PKG_AUDIT.log_action with p_old_values/p_new_values
func (s *AuditService) LogActionWithValues(tableName string, recordID int64, actionType, changedBy string, oldValues, newValues interface{}) error {
	entry := models.AuditLog{
		AuditTableName: tableName,
		RecordID:    recordID,
		ActionType:  actionType,
		ChangedBy:   changedBy,
		ChangedDate: time.Now(),
	}

	if oldValues != nil {
		b, err := json.Marshal(oldValues)
		if err == nil {
			s := string(b)
			entry.OldValues = &s
		}
	}
	if newValues != nil {
		b, err := json.Marshal(newValues)
		if err == nil {
			s := string(b)
			entry.NewValues = &s
		}
	}

	return s.db.Create(&entry).Error
}

// LogActionWithSession records an audit entry with session context.
// Mirrors: PKG_AUDIT.log_action with session/IP info
func (s *AuditService) LogActionWithSession(tableName string, recordID int64, actionType, changedBy, ipAddress, sessionID string) error {
	entry := models.AuditLog{
		AuditTableName: tableName,
		RecordID:       recordID,
		ActionType:     actionType,
		ChangedBy:      changedBy,
		ChangedDate:    time.Now(),
		IPAddress:      &ipAddress,
		SessionID:      &sessionID,
	}
	return s.db.Create(&entry).Error
}

// GetAuditTrail returns audit entries for a given table and record.
// Mirrors: PKG_AUDIT.get_audit_trail
func (s *AuditService) GetAuditTrail(tableName string, recordID int64) ([]models.AuditLog, error) {
	var entries []models.AuditLog
	err := s.db.Where("table_name = ? AND record_id = ?", tableName, recordID).
		Order("changed_date DESC").
		Find(&entries).Error
	return entries, err
}

// GetAuditByUser returns audit entries for a specific user within a date range.
func (s *AuditService) GetAuditByUser(changedBy string, startDate, endDate time.Time) ([]models.AuditLog, error) {
	var entries []models.AuditLog
	err := s.db.Where("changed_by = ? AND changed_date BETWEEN ? AND ?", changedBy, startDate, endDate).
		Order("changed_date DESC").
		Find(&entries).Error
	return entries, err
}

// PurgeOldRecords removes audit entries older than the specified number of days.
// Mirrors: PKG_AUDIT.purge_old_records
func (s *AuditService) PurgeOldRecords(retentionDays int) (int64, error) {
	cutoff := time.Now().AddDate(0, 0, -retentionDays)
	result := s.db.Where("changed_date < ?", cutoff).Delete(&models.AuditLog{})
	return result.RowsAffected, result.Error
}
