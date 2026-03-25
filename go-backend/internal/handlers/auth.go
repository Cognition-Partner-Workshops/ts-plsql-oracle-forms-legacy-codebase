package handlers

import (
	"net/http"

	"github.com/Cognition-Partner-Workshops/ts-plsql-oracle-forms-legacy-codebase/go-backend/internal/services"
	"github.com/gin-gonic/gin"
)

// AuthHandler handles authentication endpoints.
// Replaces HRMS_LOGIN.xml Oracle Form.
type AuthHandler struct {
	security *services.SecurityService
}

// NewAuthHandler creates a new AuthHandler.
func NewAuthHandler(security *services.SecurityService) *AuthHandler {
	return &AuthHandler{security: security}
}

// Login authenticates a user and returns a session token.
// POST /api/auth/login
// Replaces: HRMS_LOGIN form → PKG_SECURITY.authenticate
func (h *AuthHandler) Login(c *gin.Context) {
	var req struct {
		Username string `json:"username" binding:"required"`
		Password string `json:"password" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "username and password are required"})
		return
	}

	sessionID, empID, err := h.security.Authenticate(req.Username, req.Password, c.ClientIP())
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"session_id": sessionID,
		"emp_id":     empID,
		"message":    "login successful",
	})
}

// Logout ends a user session.
// POST /api/auth/logout
// Replaces: HRMS_MENU logout action → PKG_SECURITY.logout
func (h *AuthHandler) Logout(c *gin.Context) {
	var req struct {
		SessionID int64 `json:"session_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "session_id is required"})
		return
	}

	if err := h.security.Logout(req.SessionID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "logout successful"})
}

// ChangePassword changes a user's password.
// POST /api/auth/change-password
// Replaces: PKG_SECURITY.change_password
func (h *AuthHandler) ChangePassword(c *gin.Context) {
	var req struct {
		EmpID       int64  `json:"emp_id" binding:"required"`
		OldPassword string `json:"old_password" binding:"required"`
		NewPassword string `json:"new_password" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "emp_id, old_password, and new_password are required"})
		return
	}

	user := c.GetString("username")
	if user == "" {
		user = "SYSTEM"
	}

	if err := h.security.ChangePassword(req.EmpID, req.OldPassword, req.NewPassword, user); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "password changed successfully"})
}
