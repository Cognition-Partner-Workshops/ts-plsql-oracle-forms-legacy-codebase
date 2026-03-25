package middleware

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/Cognition-Partner-Workshops/ts-plsql-oracle-forms-legacy-codebase/go-backend/internal/services"
	"github.com/gin-gonic/gin"
)

// AuthMiddleware validates session tokens and injects user context.
// Migrates the WHEN-NEW-FORM-INSTANCE session check from Oracle Forms.
func AuthMiddleware(security *services.SecurityService) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "missing authorization header"})
			return
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || parts[0] != "Bearer" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid authorization format"})
			return
		}

		sessionID, err := strconv.ParseInt(parts[1], 10, 64)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid session token"})
			return
		}

		valid, err := security.IsSessionValid(sessionID)
		if err != nil || !valid {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "session expired or invalid"})
			return
		}

		c.Set("session_id", sessionID)
		c.Next()
	}
}

// PermissionMiddleware checks RBAC permissions for a module/action.
// Migrates PKG_SECURITY.has_permission checks from Oracle Forms triggers.
func PermissionMiddleware(security *services.SecurityService, module, action string) gin.HandlerFunc {
	return func(c *gin.Context) {
		empIDVal, exists := c.Get("emp_id")
		if !exists {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "employee context not found"})
			return
		}

		empID, ok := empIDVal.(int64)
		if !ok {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "invalid employee context"})
			return
		}

		hasPermission, err := security.HasPermission(empID, module, action)
		if err != nil || !hasPermission {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "insufficient privileges"})
			return
		}

		c.Next()
	}
}
