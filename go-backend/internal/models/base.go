package models

import "time"

// BaseModel contains common audit fields present on all HRMS tables.
// Mirrors: CREATED_BY, CREATED_DATE, MODIFIED_BY, MODIFIED_DATE columns.
type BaseModel struct {
	CreatedBy    string     `gorm:"column:created_by;size:30;not null" json:"created_by"`
	CreatedDate  time.Time  `gorm:"column:created_date;not null;autoCreateTime" json:"created_date"`
	ModifiedBy   *string    `gorm:"column:modified_by;size:30" json:"modified_by,omitempty"`
	ModifiedDate *time.Time `gorm:"column:modified_date" json:"modified_date,omitempty"`
}

// SoftDelete adds the active flag pattern used across the HRMS schema.
type SoftDelete struct {
	ActiveFlag string `gorm:"column:active_flag;type:char(1);default:'Y';not null" json:"active_flag"`
}

// IsActive returns true if the record is active.
func (s SoftDelete) IsActive() bool {
	return s.ActiveFlag == "Y"
}
