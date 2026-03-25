package services

import (
	"fmt"
	"log"
	"regexp"
	"strings"
	"time"
	"unicode"

	"github.com/Cognition-Partner-Workshops/ts-plsql-oracle-forms-legacy-codebase/go-backend/internal/models"
	"gorm.io/gorm"
)

// CommonService migrates PKG_COMMON — shared utilities, logging, date formatting, config params.
type CommonService struct {
	db *gorm.DB
}

// NewCommonService creates a new CommonService.
func NewCommonService(db *gorm.DB) *CommonService {
	return &CommonService{db: db}
}

// LogInfo logs an informational message to the audit log.
// Mirrors: PKG_COMMON.log_info
func (s *CommonService) LogInfo(module, procedure, message, user string) {
	log.Printf("[INFO] %s.%s: %s (user=%s)", module, procedure, message, user)
}

// LogError logs an error message.
// Mirrors: PKG_COMMON.log_error
func (s *CommonService) LogError(module, procedure, message, user string) {
	log.Printf("[ERROR] %s.%s: %s (user=%s)", module, procedure, message, user)
}

// GetParam retrieves a system parameter value.
// Mirrors: PKG_COMMON.get_param
func (s *CommonService) GetParam(category, paramName string) (string, error) {
	var param models.SystemParameter
	err := s.db.Where("category = ? AND param_name = ? AND active_flag = 'Y'", category, paramName).First(&param).Error
	if err != nil {
		return "", err
	}
	if param.ParamValue == nil {
		return "", nil
	}
	return *param.ParamValue, nil
}

// SetParam updates or inserts a system parameter.
// Mirrors: PKG_COMMON.set_param
func (s *CommonService) SetParam(category, paramName, paramValue, user string) error {
	var param models.SystemParameter
	err := s.db.Where("category = ? AND param_name = ?", category, paramName).First(&param).Error
	if err == gorm.ErrRecordNotFound {
		param = models.SystemParameter{
			Category:   category,
			ParamName:  paramName,
			ParamValue: &paramValue,
			BaseModel:  models.BaseModel{CreatedBy: user},
		}
		return s.db.Create(&param).Error
	}
	if err != nil {
		return err
	}
	return s.db.Model(&param).Updates(map[string]interface{}{
		"param_value": paramValue,
		"modified_by": user,
		"modified_date": time.Now(),
	}).Error
}

// FormatDate formats a time to YYYY-MM-DD string.
// Mirrors: PKG_COMMON.format_date
func (s *CommonService) FormatDate(t time.Time) string {
	return t.Format("2006-01-02")
}

// FormatDateTime formats a time to YYYY-MM-DD HH:MM:SS string.
// Mirrors: PKG_COMMON.format_datetime
func (s *CommonService) FormatDateTime(t time.Time) string {
	return t.Format("2006-01-02 15:04:05")
}

// FormatCurrency formats a float as a currency string.
// Mirrors: PKG_COMMON.format_currency
func (s *CommonService) FormatCurrency(amount float64) string {
	return fmt.Sprintf("$%.2f", amount)
}

// FormatSSN formats an SSN with dashes (XXX-XX-XXXX).
// Mirrors: PKG_COMMON.format_ssn
func (s *CommonService) FormatSSN(ssn string) string {
	clean := strings.ReplaceAll(ssn, "-", "")
	clean = strings.ReplaceAll(clean, " ", "")
	if len(clean) != 9 {
		return ssn
	}
	return clean[:3] + "-" + clean[3:5] + "-" + clean[5:]
}

// FormatPhone formats a phone number.
// Mirrors: PKG_COMMON.format_phone
func (s *CommonService) FormatPhone(phone string) string {
	digits := regexp.MustCompile(`\D`).ReplaceAllString(phone, "")
	if len(digits) == 10 {
		return fmt.Sprintf("(%s) %s-%s", digits[:3], digits[3:6], digits[6:])
	}
	return phone
}

// IsValidEmail checks if an email address is valid.
// Mirrors: PKG_COMMON.is_valid_email
func (s *CommonService) IsValidEmail(email string) bool {
	re := regexp.MustCompile(`^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$`)
	return re.MatchString(email)
}

// IsValidSSN checks if an SSN is valid (9 digits).
// Mirrors: PKG_COMMON.is_valid_ssn
func (s *CommonService) IsValidSSN(ssn string) bool {
	digits := regexp.MustCompile(`\D`).ReplaceAllString(ssn, "")
	return len(digits) == 9
}

// IsValidPhone checks if a phone number is valid (10+ digits).
// Mirrors: PKG_COMMON.is_valid_phone
func (s *CommonService) IsValidPhone(phone string) bool {
	digits := regexp.MustCompile(`\D`).ReplaceAllString(phone, "")
	return len(digits) >= 10
}

// IsValidPassword checks password meets requirements: 8+ chars, uppercase, number.
// Mirrors: PKG_SECURITY.change_password validation
func (s *CommonService) IsValidPassword(password string) bool {
	if len(password) < 8 {
		return false
	}
	hasUpper := false
	hasDigit := false
	for _, c := range password {
		if unicode.IsUpper(c) {
			hasUpper = true
		}
		if unicode.IsDigit(c) {
			hasDigit = true
		}
	}
	return hasUpper && hasDigit
}

// GetFiscalYear returns the fiscal year for a given date (fiscal year starts Oct 1).
// Mirrors: PKG_COMMON.get_fiscal_year (hard-coded to October start)
func (s *CommonService) GetFiscalYear(t time.Time) int {
	if int(t.Month()) >= 10 {
		return t.Year() + 1
	}
	return t.Year()
}
