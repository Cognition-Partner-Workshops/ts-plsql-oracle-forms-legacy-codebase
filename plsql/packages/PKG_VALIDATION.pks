CREATE OR REPLACE PACKAGE HRMS.PKG_VALIDATION AS
-- ============================================================================
-- PKG_VALIDATION - Centralized Validation Package
-- Business rule validation shared between Forms triggers and PL/SQL packages
--
-- Dependencies: PKG_COMMON
-- Called by: All forms (WHEN-VALIDATE-ITEM triggers), PKG_EMPLOYEE, PKG_PAYROLL
-- ============================================================================

    FUNCTION validate_date_range(
        p_start_date IN DATE,
        p_end_date   IN DATE
    ) RETURN BOOLEAN;

    FUNCTION validate_salary_for_grade(
        p_salary   IN NUMBER,
        p_grade_id IN NUMBER
    ) RETURN VARCHAR2;  -- Returns NULL if valid, error message if invalid

    FUNCTION validate_email_format(
        p_email IN VARCHAR2
    ) RETURN BOOLEAN;

    FUNCTION validate_phone_format(
        p_phone IN VARCHAR2
    ) RETURN BOOLEAN;

    FUNCTION validate_emp_number_format(
        p_emp_number IN VARCHAR2
    ) RETURN BOOLEAN;

    FUNCTION is_future_date(
        p_date IN DATE
    ) RETURN BOOLEAN;

    FUNCTION is_business_day(
        p_date          IN DATE,
        p_location_code IN VARCHAR2 DEFAULT NULL
    ) RETURN BOOLEAN;

    FUNCTION validate_required_fields(
        p_table_name IN VARCHAR2,
        p_record_id  IN NUMBER
    ) RETURN VARCHAR2;  -- Returns NULL if all required fields populated

END PKG_VALIDATION;
/
