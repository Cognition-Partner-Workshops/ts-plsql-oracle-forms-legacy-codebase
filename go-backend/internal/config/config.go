package config

import (
	"os"
)

// Config holds application configuration.
type Config struct {
	DatabaseDSN    string
	ServerPort     string
	JWTSecret      string
	SMTPHost       string
	SMTPPort       string
	SMTPFrom       string
	EncryptionKey  string
	SessionTimeout int // minutes
	FiscalYearStartMonth int
}

// Load returns a Config populated from environment variables with sensible defaults.
func Load() *Config {
	return &Config{
		DatabaseDSN:          getEnv("DATABASE_DSN", "hrms.db"),
		ServerPort:           getEnv("SERVER_PORT", "8080"),
		JWTSecret:            getEnv("JWT_SECRET", "hrms-jwt-secret-change-in-production"),
		SMTPHost:             getEnv("SMTP_HOST", "smtp.internal.company.com"),
		SMTPPort:             getEnv("SMTP_PORT", "25"),
		SMTPFrom:             getEnv("SMTP_FROM", "hrms-noreply@company.com"),
		EncryptionKey:        getEnv("ENCRYPTION_KEY", "HR$ystem_3ncrypt10n_K3y_2024!!"),
		SessionTimeout:       30,
		FiscalYearStartMonth: 10, // October
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
