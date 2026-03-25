package handlers

import (
	"net/http"
	"strconv"

	"github.com/Cognition-Partner-Workshops/ts-plsql-oracle-forms-legacy-codebase/go-backend/internal/models"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// AdminHandler handles administrative lookup endpoints.
// Replaces LOV (List of Values) queries from Oracle Forms.
type AdminHandler struct {
	db *gorm.DB
}

// NewAdminHandler creates a new AdminHandler.
func NewAdminHandler(db *gorm.DB) *AdminHandler {
	return &AdminHandler{db: db}
}

// GetDepartments returns all active departments.
// GET /api/admin/departments
// Replaces: LOV_DEPARTMENTS, RG_DEPARTMENTS in HRMS_EMPLOYEE.xml
func (h *AdminHandler) GetDepartments(c *gin.Context) {
	var depts []models.Department
	h.db.Where("active_flag = 'Y'").Order("dept_name").Find(&depts)
	c.JSON(http.StatusOK, depts)
}

// GetJobTitles returns all active job titles.
// GET /api/admin/job-titles?grade_id=1
// Replaces: LOV_JOB_TITLES in HRMS_EMPLOYEE.xml
func (h *AdminHandler) GetJobTitles(c *gin.Context) {
	var jobs []models.JobTitle
	query := h.db.Preload("Grade").Where("active_flag = 'Y'")
	if g := c.Query("grade_id"); g != "" {
		gradeID, _ := strconv.ParseInt(g, 10, 64)
		query = query.Where("grade_id = ?", gradeID)
	}
	query.Order("job_title").Find(&jobs)
	c.JSON(http.StatusOK, jobs)
}

// GetJobGrades returns all active job grades.
// GET /api/admin/job-grades
// Replaces: LOV_JOB_GRADES in HRMS_EMPLOYEE.xml
func (h *AdminHandler) GetJobGrades(c *gin.Context) {
	var grades []models.JobGrade
	h.db.Where("active_flag = 'Y'").Order("grade_level").Find(&grades)
	c.JSON(http.StatusOK, grades)
}

// GetLocations returns all active locations.
// GET /api/admin/locations
// Replaces: LOV_LOCATIONS in HRMS_EMPLOYEE.xml
func (h *AdminHandler) GetLocations(c *gin.Context) {
	var locations []models.Location
	h.db.Where("active_flag = 'Y'").Order("location_name").Find(&locations)
	c.JSON(http.StatusOK, locations)
}

// GetLeaveTypes returns all active leave types.
// GET /api/admin/leave-types
func (h *AdminHandler) GetLeaveTypes(c *gin.Context) {
	var types []models.LeaveType
	h.db.Where("active_flag = 'Y'").Order("leave_type_name").Find(&types)
	c.JSON(http.StatusOK, types)
}

// GetLookupValues returns lookup values by type.
// GET /api/admin/lookups?type=EMPLOYMENT_STATUS
// Replaces: LOV-based lookups in Oracle Forms
func (h *AdminHandler) GetLookupValues(c *gin.Context) {
	lookupType := c.Query("type")
	if lookupType == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "type parameter is required"})
		return
	}
	var values []models.LookupValue
	h.db.Where("lookup_type = ? AND active_flag = 'Y'", lookupType).
		Order("display_order").Find(&values)
	c.JSON(http.StatusOK, values)
}

// GetHolidays returns holidays.
// GET /api/admin/holidays?year=2024
func (h *AdminHandler) GetHolidays(c *gin.Context) {
	var holidays []models.Holiday
	query := h.db.Where("active_flag = 'Y'")
	if y := c.Query("year"); y != "" {
		year, _ := strconv.Atoi(y)
		query = query.Where("strftime('%Y', holiday_date) = ?", strconv.Itoa(year))
	}
	query.Order("holiday_date").Find(&holidays)
	c.JSON(http.StatusOK, holidays)
}

// GetPayElements returns all active pay elements.
// GET /api/admin/pay-elements
func (h *AdminHandler) GetPayElements(c *gin.Context) {
	var elements []models.PayElement
	h.db.Where("active_flag = 'Y'").Order("priority_order").Find(&elements)
	c.JSON(http.StatusOK, elements)
}

// HealthCheck returns a health status.
// GET /api/health
func (h *AdminHandler) HealthCheck(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status":  "healthy",
		"service": "HRMS Go Backend",
		"version": "1.0.0",
	})
}
