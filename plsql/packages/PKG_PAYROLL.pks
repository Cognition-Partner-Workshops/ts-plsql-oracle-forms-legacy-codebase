CREATE OR REPLACE PACKAGE HRMS.PKG_PAYROLL AS
-- ============================================================================
-- PKG_PAYROLL - Payroll Processing Package
-- Salary management, pay run calculation, tax withholding, deductions
--
-- Dependencies: PKG_EMPLOYEE, PKG_COMMON, PKG_AUDIT, PKG_NOTIFICATION
-- Called by: HRMS_PAYROLL form, batch scheduler (DBMS_SCHEDULER)
-- Known issues:
--   - Circular dependency with PKG_EMPLOYEE (is_active check)
--   - Tax calculation uses hard-coded 2024 brackets in some paths
--   - Overtime calculation does not account for holidays correctly
--   - YTD accumulation resets incorrectly for mid-year hires in some edge cases
-- ============================================================================

    -- Custom exceptions
    e_invalid_salary       EXCEPTION;
    e_period_closed        EXCEPTION;
    e_run_already_paid     EXCEPTION;
    e_calculation_error    EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_invalid_salary,    -20101);
    PRAGMA EXCEPTION_INIT(e_period_closed,     -20102);
    PRAGMA EXCEPTION_INIT(e_run_already_paid,  -20103);
    PRAGMA EXCEPTION_INIT(e_calculation_error, -20104);

    -- Types
    TYPE t_payslip_rec IS RECORD (
        emp_id           NUMBER(10),
        emp_number       VARCHAR2(20),
        emp_name         VARCHAR2(101),
        period_name      VARCHAR2(50),
        gross_pay        NUMBER(12,2),
        total_deductions NUMBER(12,2),
        net_pay          NUMBER(12,2),
        federal_tax      NUMBER(12,2),
        state_tax        NUMBER(12,2),
        social_security  NUMBER(12,2),
        medicare         NUMBER(12,2),
        ytd_gross        NUMBER(15,2),
        ytd_net          NUMBER(15,2)
    );

    TYPE t_payslip_cursor IS REF CURSOR;

    -- -----------------------------------------------------------------------
    -- Salary Management
    -- -----------------------------------------------------------------------
    PROCEDURE create_salary_record(
        p_emp_id         IN NUMBER,
        p_effective_date IN DATE,
        p_base_salary    IN NUMBER,
        p_change_reason  IN VARCHAR2 DEFAULT NULL,
        p_change_pct     IN NUMBER DEFAULT NULL,
        p_currency_code  IN VARCHAR2 DEFAULT 'USD',
        p_pay_frequency  IN VARCHAR2 DEFAULT 'MONTHLY',
        p_user           IN VARCHAR2 DEFAULT USER
    );

    FUNCTION get_current_salary(
        p_emp_id IN NUMBER
    ) RETURN NUMBER;

    FUNCTION get_salary_as_of(
        p_emp_id   IN NUMBER,
        p_as_of    IN DATE
    ) RETURN NUMBER;

    -- -----------------------------------------------------------------------
    -- Pay Period Management
    -- -----------------------------------------------------------------------
    PROCEDURE create_pay_periods(
        p_year          IN NUMBER,
        p_frequency     IN VARCHAR2 DEFAULT 'MONTHLY',
        p_user          IN VARCHAR2 DEFAULT USER
    );

    PROCEDURE close_pay_period(
        p_period_id IN NUMBER,
        p_user      IN VARCHAR2 DEFAULT USER
    );

    FUNCTION get_current_period RETURN NUMBER;

    -- -----------------------------------------------------------------------
    -- Payroll Processing
    -- -----------------------------------------------------------------------
    FUNCTION create_payroll_run(
        p_period_id IN NUMBER,
        p_run_type  IN VARCHAR2 DEFAULT 'REGULAR',
        p_user      IN VARCHAR2 DEFAULT USER
    ) RETURN NUMBER;

    PROCEDURE calculate_payroll(
        p_run_id IN NUMBER,
        p_user   IN VARCHAR2 DEFAULT USER
    );

    PROCEDURE calculate_employee_pay(
        p_run_id    IN NUMBER,
        p_emp_id    IN NUMBER,
        p_period_id IN NUMBER,
        p_user      IN VARCHAR2 DEFAULT USER
    );

    PROCEDURE approve_payroll(
        p_run_id IN NUMBER,
        p_user   IN VARCHAR2 DEFAULT USER
    );

    PROCEDURE reverse_payroll(
        p_run_id IN NUMBER,
        p_reason IN VARCHAR2,
        p_user   IN VARCHAR2 DEFAULT USER
    );

    -- -----------------------------------------------------------------------
    -- Tax Calculations
    -- -----------------------------------------------------------------------
    FUNCTION calculate_federal_tax(
        p_taxable_income  IN NUMBER,
        p_filing_status   IN VARCHAR2,
        p_allowances      IN NUMBER DEFAULT 0,
        p_additional_wh   IN NUMBER DEFAULT 0,
        p_pay_frequency   IN VARCHAR2 DEFAULT 'MONTHLY'
    ) RETURN NUMBER;

    FUNCTION calculate_state_tax(
        p_taxable_income  IN NUMBER,
        p_state_code      IN VARCHAR2,
        p_filing_status   IN VARCHAR2,
        p_allowances      IN NUMBER DEFAULT 0,
        p_pay_frequency   IN VARCHAR2 DEFAULT 'MONTHLY'
    ) RETURN NUMBER;

    FUNCTION calculate_fica(
        p_gross_pay   IN NUMBER,
        p_ytd_gross   IN NUMBER
    ) RETURN NUMBER;

    FUNCTION calculate_medicare(
        p_gross_pay   IN NUMBER,
        p_ytd_gross   IN NUMBER
    ) RETURN NUMBER;

    -- -----------------------------------------------------------------------
    -- Reporting
    -- -----------------------------------------------------------------------
    PROCEDURE get_payslip(
        p_cursor  OUT t_payslip_cursor,
        p_run_id  IN NUMBER,
        p_emp_id  IN NUMBER DEFAULT NULL
    );

    FUNCTION get_ytd_earnings(
        p_emp_id    IN NUMBER,
        p_tax_year  IN NUMBER DEFAULT EXTRACT(YEAR FROM SYSDATE)
    ) RETURN NUMBER;

    PROCEDURE generate_pay_register(
        p_run_id IN NUMBER,
        p_user   IN VARCHAR2 DEFAULT USER
    );

END PKG_PAYROLL;
/
