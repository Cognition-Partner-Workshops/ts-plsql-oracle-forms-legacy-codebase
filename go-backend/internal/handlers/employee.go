package handlers

import (
	"net/http"
	"strconv"
	"time"

	"github.com/Cognition-Partner-Workshops/ts-plsql-oracle-forms-legacy-codebase/go-backend/internal/models"
	"github.com/Cognition-Partner-Workshops/ts-plsql-oracle-forms-legacy-codebase/go-backend/internal/services"
	"github.com/gin-gonic/gin"
)

// EmployeeHandler handles employee endpoints.
// Replaces HRMS_EMPLOYEE.xml Oracle Form (4 tab pages, 5 data blocks, 8 LOVs).
type EmployeeHandler struct {
	employee *services.EmployeeService
}

// NewEmployeeHandler creates a new EmployeeHandler.
func NewEmployeeHandler(employee *services.EmployeeService) *EmployeeHandler {
	return &EmployeeHandler{employee: employee}
}

// Create creates a new employee.
// POST /api/employees
// Replaces: HRMS_EMPLOYEE form PRE-INSERT trigger → PKG_EMPLOYEE.create_employee
func (h *EmployeeHandler) Create(c *gin.Context) {
	var req struct {
		FirstName      string  `json:"first_name" binding:"required"`
		LastName       string  `json:"last_name" binding:"required"`
		Email          *string `json:"email"`
		Phone          *string `json:"phone"`
		Gender         *string `json:"gender"`
		DateOfBirth    *string `json:"date_of_birth"`
		DeptID         int64   `json:"dept_id" binding:"required"`
		JobID          int64   `json:"job_id" binding:"required"`
		ManagerEmpID   *int64  `json:"manager_emp_id"`
		HireDate       string  `json:"hire_date" binding:"required"`
		EmploymentType string  `json:"employment_type"`
		LocationCode   *string `json:"location_code"`
		BaseSalary     float64 `json:"base_salary"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	hireDate, err := time.Parse("2006-01-02", req.HireDate)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid hire_date format, use YYYY-MM-DD"})
		return
	}

	emp := &models.Employee{
		FirstName:      req.FirstName,
		LastName:       req.LastName,
		Email:          req.Email,
		PhoneWork:      req.Phone,
		Gender:         req.Gender,
		DeptID:         req.DeptID,
		JobID:          req.JobID,
		ManagerEmpID:   req.ManagerEmpID,
		HireDate:       hireDate,
		EmploymentType: req.EmploymentType,
		LocationCode:   req.LocationCode,
	}
	if req.DateOfBirth != nil {
		dob, err := time.Parse("2006-01-02", *req.DateOfBirth)
		if err == nil {
			emp.DateOfBirth = &dob
		}
	}
	if emp.EmploymentType == "" {
		emp.EmploymentType = "FULL_TIME"
	}

	user := c.GetString("username")
	if user == "" {
		user = "SYSTEM"
	}

	_, err = h.employee.CreateEmployee(emp, req.BaseSalary, user)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, emp)
}

// Get retrieves an employee by ID.
// GET /api/employees/:id
// Replaces: HRMS_EMPLOYEE form POST-QUERY trigger
func (h *EmployeeHandler) Get(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid employee ID"})
		return
	}

	emp, err := h.employee.GetEmployee(id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "employee not found"})
		return
	}

	c.JSON(http.StatusOK, emp)
}

// Search searches employees with filters.
// GET /api/employees?first_name=&last_name=&dept_id=&status=&page=&page_size=
// Replaces: HRMS_EMPLOYEE form EXECUTE_QUERY with LOV filters
func (h *EmployeeHandler) Search(c *gin.Context) {
	firstName := c.Query("first_name")
	lastName := c.Query("last_name")
	status := c.Query("status")
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))

	var deptID *int64
	if d := c.Query("dept_id"); d != "" {
		v, _ := strconv.ParseInt(d, 10, 64)
		deptID = &v
	}

	var firstNamePtr, lastNamePtr, statusPtr *string
	if firstName != "" {
		firstNamePtr = &firstName
	}
	if lastName != "" {
		lastNamePtr = &lastName
	}
	if status != "" {
		statusPtr = &status
	}

	employees, total, err := h.employee.SearchEmployees(firstNamePtr, lastNamePtr, deptID, statusPtr, page, pageSize)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"employees": employees,
		"total":     total,
		"page":      page,
		"page_size": pageSize,
	})
}

// Update updates an employee record.
// PUT /api/employees/:id
// Replaces: HRMS_EMPLOYEE form PRE-UPDATE trigger → PKG_EMPLOYEE.update_employee
func (h *EmployeeHandler) Update(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid employee ID"})
		return
	}

	var updates map[string]interface{}
	if err := c.ShouldBindJSON(&updates); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	user := c.GetString("username")
	if user == "" {
		user = "SYSTEM"
	}

	if err := h.employee.UpdateEmployee(id, updates, user); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "employee updated"})
}

// Transfer transfers an employee.
// POST /api/employees/:id/transfer
// Replaces: PKG_EMPLOYEE.transfer_employee
func (h *EmployeeHandler) Transfer(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid employee ID"})
		return
	}

	var req struct {
		NewDeptID    int64   `json:"new_dept_id" binding:"required"`
		NewJobID     *int64  `json:"new_job_id"`
		NewManagerID *int64  `json:"new_manager_id"`
		NewLocation  *string `json:"new_location"`
		Reason       string  `json:"reason" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	user := c.GetString("username")
	if user == "" {
		user = "SYSTEM"
	}

	if err := h.employee.TransferEmployee(id, req.NewDeptID, req.NewJobID, req.NewManagerID, req.NewLocation, req.Reason, user); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "employee transferred"})
}

// Promote promotes an employee.
// POST /api/employees/:id/promote
// Replaces: PKG_EMPLOYEE.promote_employee
func (h *EmployeeHandler) Promote(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid employee ID"})
		return
	}

	var req struct {
		NewJobID  int64   `json:"new_job_id" binding:"required"`
		NewSalary float64 `json:"new_salary" binding:"required"`
		Reason    string  `json:"reason" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	user := c.GetString("username")
	if user == "" {
		user = "SYSTEM"
	}

	if err := h.employee.PromoteEmployee(id, req.NewJobID, req.NewSalary, req.Reason, user); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "employee promoted"})
}

// Terminate terminates an employee.
// POST /api/employees/:id/terminate
// Replaces: PKG_EMPLOYEE.terminate_employee
func (h *EmployeeHandler) Terminate(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid employee ID"})
		return
	}

	var req struct {
		TerminationDate string `json:"termination_date" binding:"required"`
		Reason          string `json:"reason" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	termDate, err := time.Parse("2006-01-02", req.TerminationDate)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid termination_date format"})
		return
	}

	user := c.GetString("username")
	if user == "" {
		user = "SYSTEM"
	}

	if err := h.employee.TerminateEmployee(id, termDate, req.Reason, user); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "employee terminated"})
}

// Rehire rehires a terminated employee.
// POST /api/employees/:id/rehire
// Replaces: PKG_EMPLOYEE.rehire_employee
func (h *EmployeeHandler) Rehire(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid employee ID"})
		return
	}

	var req struct {
		RehireDate string  `json:"rehire_date" binding:"required"`
		DeptID     int64   `json:"dept_id" binding:"required"`
		JobID      int64   `json:"job_id" binding:"required"`
		Salary     float64 `json:"salary" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	rehireDate, err := time.Parse("2006-01-02", req.RehireDate)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid rehire_date format"})
		return
	}

	user := c.GetString("username")
	if user == "" {
		user = "SYSTEM"
	}

	if err := h.employee.RehireEmployee(id, rehireDate, req.DeptID, req.JobID, req.Salary, user); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "employee rehired"})
}

// GetDirectReports returns direct reports for a manager.
// GET /api/employees/:id/direct-reports
func (h *EmployeeHandler) GetDirectReports(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid employee ID"})
		return
	}

	reports, err := h.employee.GetDirectReports(id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, reports)
}

// GetOrgChart returns the org chart.
// GET /api/employees/:id/org-chart?depth=3
func (h *EmployeeHandler) GetOrgChart(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid employee ID"})
		return
	}

	maxDepth, _ := strconv.Atoi(c.DefaultQuery("depth", "3"))
	chart, err := h.employee.GetOrgChart(id, maxDepth)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, chart)
}

// GetHistory returns employee change history.
// GET /api/employees/:id/history
func (h *EmployeeHandler) GetHistory(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid employee ID"})
		return
	}

	history, err := h.employee.GetEmployeeHistory(id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, history)
}

// GetDependents returns employee dependents.
// GET /api/employees/:id/dependents
func (h *EmployeeHandler) GetDependents(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid employee ID"})
		return
	}

	deps, err := h.employee.GetDependents(id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, deps)
}

// GetEmergencyContacts returns employee emergency contacts.
// GET /api/employees/:id/emergency-contacts
func (h *EmployeeHandler) GetEmergencyContacts(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid employee ID"})
		return
	}

	contacts, err := h.employee.GetEmergencyContacts(id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, contacts)
}
