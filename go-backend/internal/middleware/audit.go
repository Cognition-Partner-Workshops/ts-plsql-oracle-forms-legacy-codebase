package middleware

import (
	"bytes"
	"io"
	"time"

	"github.com/Cognition-Partner-Workshops/ts-plsql-oracle-forms-legacy-codebase/go-backend/internal/services"
	"github.com/gin-gonic/gin"
)

// AuditMiddleware logs all API requests to the audit trail.
// Migrates TRG_SALARY_AUDIT, TRG_LEAVE_REQUEST_AUDIT, TRG_DEPARTMENT_AUDIT
// trigger behavior into HTTP-level auditing.
func AuditMiddleware(audit *services.AuditService) gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()

		// Read body for audit (re-buffer it)
		var bodyBytes []byte
		if c.Request.Body != nil {
			bodyBytes, _ = io.ReadAll(c.Request.Body)
			c.Request.Body = io.NopCloser(bytes.NewBuffer(bodyBytes))
		}

		c.Next()

		// Log after request completes
		duration := time.Since(start)
		user := c.GetString("username")
		if user == "" {
			user = "ANONYMOUS"
		}

		ip := c.ClientIP()
		sessionID := ""
		if sid, exists := c.Get("session_id"); exists {
			sessionID = sid.(string)
		}

		// Only audit mutating requests
		if c.Request.Method != "GET" && c.Request.Method != "OPTIONS" {
			_ = audit.LogActionWithSession(
				"HTTP_REQUEST",
				0,
				c.Request.Method+" "+c.Request.URL.Path,
				user,
				ip,
				sessionID,
			)
		}

		// Log slow requests
		if duration > 5*time.Second {
			_ = audit.LogAction("SLOW_REQUEST", 0,
				c.Request.Method+" "+c.Request.URL.Path,
				user,
			)
		}
	}
}
