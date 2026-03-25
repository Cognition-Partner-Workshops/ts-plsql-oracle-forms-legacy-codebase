package services

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"time"

	"github.com/Cognition-Partner-Workshops/ts-plsql-oracle-forms-legacy-codebase/go-backend/internal/models"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

// SecurityService migrates PKG_SECURITY — authentication, sessions, RBAC, encryption.
type SecurityService struct {
	db             *gorm.DB
	audit          *AuditService
	encryptionKey  string
	sessionTimeout int // minutes
}

// NewSecurityService creates a new SecurityService.
func NewSecurityService(db *gorm.DB, audit *AuditService, encryptionKey string, sessionTimeout int) *SecurityService {
	return &SecurityService{
		db:             db,
		audit:          audit,
		encryptionKey:  encryptionKey,
		sessionTimeout: sessionTimeout,
	}
}

var (
	ErrInvalidCredentials = errors.New("invalid credentials")
	ErrAccountLocked      = errors.New("account is locked")
	ErrSessionExpired     = errors.New("session has expired")
	ErrInsufficientPriv   = errors.New("insufficient privileges")
)

// HashPassword hashes a password using bcrypt (upgraded from legacy MD5).
// Mirrors: PKG_SECURITY.hash_password (originally used DBMS_CRYPTO.HASH_MD5)
func (s *SecurityService) HashPassword(password string) (string, error) {
	bytes, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return "", err
	}
	return string(bytes), nil
}

// CheckPassword verifies a password against a bcrypt hash.
func (s *SecurityService) CheckPassword(password, hash string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
	return err == nil
}

// Authenticate validates credentials and creates a session.
// Mirrors: PKG_SECURITY.authenticate
// Returns session ID on success.
func (s *SecurityService) Authenticate(username, password, ipAddress string) (int64, int64, error) {
	// Find employee by email (username)
	var emp models.Employee
	err := s.db.Where("email = ? AND employment_status = 'ACTIVE'", username).First(&emp).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return 0, 0, ErrInvalidCredentials
		}
		return 0, 0, err
	}

	// Check password from system_parameters (in production, store on employees table)
	var param models.SystemParameter
	err = s.db.Where("category = 'USER_PASSWORD' AND param_name = ?", fmt.Sprintf("EMP_%d", emp.EmpID)).First(&param).Error
	if err != nil {
		return 0, 0, ErrInvalidCredentials
	}
	if param.ParamValue == nil || !s.CheckPassword(password, *param.ParamValue) {
		return 0, 0, ErrInvalidCredentials
	}

	// Create session
	session := models.UserSession{
		EmpID:         emp.EmpID,
		Username:      username,
		LoginTime:     time.Now(),
		IPAddress:     &ipAddress,
		SessionStatus: "ACTIVE",
	}
	if err := s.db.Create(&session).Error; err != nil {
		return 0, 0, err
	}

	_ = s.audit.LogActionWithSession("USER_SESSIONS", session.SessionID, "LOGIN", username, ipAddress, fmt.Sprintf("%d", session.SessionID))

	return session.SessionID, emp.EmpID, nil
}

// Logout ends a user session.
// Mirrors: PKG_SECURITY.logout
func (s *SecurityService) Logout(sessionID int64) error {
	now := time.Now()
	return s.db.Model(&models.UserSession{}).
		Where("session_id = ? AND session_status = 'ACTIVE'", sessionID).
		Updates(map[string]interface{}{
			"session_status": "LOGGED_OUT",
			"logout_time":    now,
		}).Error
}

// IsSessionValid checks if a session is active and not timed out.
// Mirrors: PKG_SECURITY.is_session_valid (30-minute timeout)
func (s *SecurityService) IsSessionValid(sessionID int64) (bool, error) {
	var session models.UserSession
	err := s.db.Where("session_id = ? AND session_status = 'ACTIVE'", sessionID).First(&session).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return false, nil
		}
		return false, err
	}

	// Check timeout
	timeout := time.Duration(s.sessionTimeout) * time.Minute
	if time.Since(session.LoginTime) > timeout {
		// Expire the session
		s.db.Model(&session).Updates(map[string]interface{}{
			"session_status": "EXPIRED",
			"logout_time":    time.Now(),
		})
		return false, nil
	}

	return true, nil
}

// HasPermission checks if an employee has permission for a module/action.
// Mirrors: PKG_SECURITY.has_permission
// Simplified RBAC: grade >= 8 = full access, >= 5 = view all, < 5 = own records only
func (s *SecurityService) HasPermission(empID int64, module, action string) (bool, error) {
	var emp models.Employee
	err := s.db.Preload("Job.Grade").Where("emp_id = ?", empID).First(&emp).Error
	if err != nil {
		return false, err
	}

	if emp.Job == nil || emp.Job.Grade == nil {
		return false, nil
	}

	gradeLevel := emp.Job.Grade.GradeLevel

	switch {
	case gradeLevel >= 8:
		return true, nil // full access
	case gradeLevel >= 5:
		if action == "VIEW" {
			return true, nil
		}
		// Can edit own department
		return action == "EDIT", nil
	default:
		// Own records only
		return action == "VIEW", nil
	}
}

// EncryptSSN encrypts an SSN using AES-256.
// Mirrors: PKG_SECURITY.encrypt_ssn (using DBMS_CRYPTO.ENCRYPT)
func (s *SecurityService) EncryptSSN(ssn string) (string, error) {
	key := sha256.Sum256([]byte(s.encryptionKey))
	block, err := aes.NewCipher(key[:])
	if err != nil {
		return "", err
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}

	nonce := make([]byte, gcm.NonceSize())
	if _, err = io.ReadFull(rand.Reader, nonce); err != nil {
		return "", err
	}

	ciphertext := gcm.Seal(nonce, nonce, []byte(ssn), nil)
	return hex.EncodeToString(ciphertext), nil
}

// DecryptSSN decrypts an SSN.
// Mirrors: PKG_SECURITY.decrypt_ssn
func (s *SecurityService) DecryptSSN(encrypted string) (string, error) {
	data, err := hex.DecodeString(encrypted)
	if err != nil {
		return "", err
	}

	key := sha256.Sum256([]byte(s.encryptionKey))
	block, err := aes.NewCipher(key[:])
	if err != nil {
		return "", err
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}

	nonceSize := gcm.NonceSize()
	if len(data) < nonceSize {
		return "", errors.New("ciphertext too short")
	}

	nonce, ciphertext := data[:nonceSize], data[nonceSize:]
	plaintext, err := gcm.Open(nil, nonce, ciphertext, nil)
	if err != nil {
		return "", err
	}

	return string(plaintext), nil
}

// ChangePassword changes a user's password.
// Mirrors: PKG_SECURITY.change_password
func (s *SecurityService) ChangePassword(empID int64, oldPassword, newPassword, user string) error {
	// Validate new password
	cs := &CommonService{}
	if !cs.IsValidPassword(newPassword) {
		return errors.New("password must be at least 8 characters with at least one uppercase letter and one number")
	}

	// Verify old password
	var param models.SystemParameter
	key := fmt.Sprintf("EMP_%d", empID)
	err := s.db.Where("category = 'USER_PASSWORD' AND param_name = ?", key).First(&param).Error
	if err == nil && param.ParamValue != nil {
		if !s.CheckPassword(oldPassword, *param.ParamValue) {
			return ErrInvalidCredentials
		}
	}

	// Hash new password
	hash, err := s.HashPassword(newPassword)
	if err != nil {
		return err
	}

	// Upsert
	if errors.Is(s.db.Where("category = 'USER_PASSWORD' AND param_name = ?", key).First(&models.SystemParameter{}).Error, gorm.ErrRecordNotFound) {
		return s.db.Create(&models.SystemParameter{
			Category:   "USER_PASSWORD",
			ParamName:  key,
			ParamValue: &hash,
			BaseModel:  models.BaseModel{CreatedBy: user},
		}).Error
	}

	return s.db.Model(&models.SystemParameter{}).
		Where("category = 'USER_PASSWORD' AND param_name = ?", key).
		Updates(map[string]interface{}{
			"param_value":   hash,
			"modified_by":   user,
			"modified_date": time.Now(),
		}).Error
}
