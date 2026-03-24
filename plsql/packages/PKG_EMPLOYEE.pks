CREATE OR REPLACE PACKAGE HRMS.PKG_EMPLOYEE AS
-- ============================================================================
-- PKG_EMPLOYEE - Employee Management Package
-- Core CRUD and business logic for employee records
--
-- Dependencies: PKG_COMMON, PKG_AUDIT, PKG_NOTIFICATION, PKG_PAYROLL
-- Called by: HRMS_EMPLOYEE form, HRMS_DEPARTMENT form, batch jobs
-- Known issues:
--   - Circular dependency with PKG_PAYROLL (salary validation)
--   - get_org_chart uses recursive SQL that times out for deep hierarchies
-- ============================================================================

    -- Global package variables (session state)
    g_current_user       VARCHAR2(30);
    g_current_emp_id     NUMBER(10);
    g_current_dept_id    NUMBER(10);
    g_debug_mode         BOOLEAN := FALSE;

    -- Custom exception codes
    e_employee_not_found     EXCEPTION;
    e_duplicate_emp_number   EXCEPTION;
    e_invalid_department     EXCEPTION;
    e_invalid_manager        EXCEPTION;
    e_termination_error      EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_employee_not_found,   -20001);
    PRAGMA EXCEPTION_INIT(e_duplicate_emp_number,  -20002);
    PRAGMA EXCEPTION_INIT(e_invalid_department,    -20003);
    PRAGMA EXCEPTION_INIT(e_invalid_manager,       -20004);
    PRAGMA EXCEPTION_INIT(e_termination_error,     -20005);

    -- Employee record type
    TYPE t_emp_rec IS RECORD (
        emp_id           EMPLOYEES.EMP_ID%TYPE,
        emp_number       EMPLOYEES.EMP_NUMBER%TYPE,
        first_name       EMPLOYEES.FIRST_NAME%TYPE,
        last_name        EMPLOYEES.LAST_NAME%TYPE,
        hire_date        EMPLOYEES.HIRE_DATE%TYPE,
        dept_id          EMPLOYEES.DEPT_ID%TYPE,
        job_id           EMPLOYEES.JOB_ID%TYPE,
        manager_emp_id   EMPLOYEES.MANAGER_EMP_ID%TYPE,
        employment_status EMPLOYEES.EMPLOYMENT_STATUS%TYPE,
        base_salary      NUMBER(12,2)
    );

    -- Ref cursor for dynamic queries
    TYPE t_emp_cursor IS REF CURSOR;

    -- Table type for bulk operations
    TYPE t_emp_id_table IS TABLE OF NUMBER(10) INDEX BY BINARY_INTEGER;
    TYPE t_emp_rec_table IS TABLE OF t_emp_rec INDEX BY BINARY_INTEGER;

    -- -----------------------------------------------------------------------
    -- CRUD Operations
    -- -----------------------------------------------------------------------
    FUNCTION create_employee(
        p_first_name      IN VARCHAR2,
        p_last_name       IN VARCHAR2,
        p_hire_date       IN DATE,
        p_dept_id         IN NUMBER,
        p_job_id          IN NUMBER,
        p_manager_emp_id  IN NUMBER DEFAULT NULL,
        p_location_code   IN VARCHAR2 DEFAULT NULL,
        p_employment_type IN VARCHAR2 DEFAULT 'FULL_TIME',
        p_base_salary     IN NUMBER DEFAULT NULL,
        p_email           IN VARCHAR2 DEFAULT NULL,
        p_user            IN VARCHAR2 DEFAULT USER
    ) RETURN NUMBER;

    PROCEDURE update_employee(
        p_emp_id          IN NUMBER,
        p_first_name      IN VARCHAR2 DEFAULT NULL,
        p_last_name       IN VARCHAR2 DEFAULT NULL,
        p_email           IN VARCHAR2 DEFAULT NULL,
        p_phone_work      IN VARCHAR2 DEFAULT NULL,
        p_phone_mobile    IN VARCHAR2 DEFAULT NULL,
        p_address_line1   IN VARCHAR2 DEFAULT NULL,
        p_address_line2   IN VARCHAR2 DEFAULT NULL,
        p_city            IN VARCHAR2 DEFAULT NULL,
        p_state_province  IN VARCHAR2 DEFAULT NULL,
        p_postal_code     IN VARCHAR2 DEFAULT NULL,
        p_country_code    IN VARCHAR2 DEFAULT NULL,
        p_user            IN VARCHAR2 DEFAULT USER
    );

    FUNCTION get_employee(
        p_emp_id IN NUMBER
    ) RETURN t_emp_rec;

    FUNCTION get_employee_by_number(
        p_emp_number IN VARCHAR2
    ) RETURN t_emp_rec;

    PROCEDURE search_employees(
        p_cursor         OUT t_emp_cursor,
        p_last_name      IN VARCHAR2 DEFAULT NULL,
        p_first_name     IN VARCHAR2 DEFAULT NULL,
        p_dept_id        IN NUMBER DEFAULT NULL,
        p_status         IN VARCHAR2 DEFAULT NULL,
        p_location_code  IN VARCHAR2 DEFAULT NULL,
        p_hire_date_from IN DATE DEFAULT NULL,
        p_hire_date_to   IN DATE DEFAULT NULL
    );

    -- -----------------------------------------------------------------------
    -- Employment Lifecycle
    -- -----------------------------------------------------------------------
    PROCEDURE transfer_employee(
        p_emp_id          IN NUMBER,
        p_new_dept_id     IN NUMBER,
        p_new_job_id      IN NUMBER DEFAULT NULL,
        p_new_manager_id  IN NUMBER DEFAULT NULL,
        p_new_location    IN VARCHAR2 DEFAULT NULL,
        p_effective_date  IN DATE DEFAULT SYSDATE,
        p_reason_code     IN VARCHAR2 DEFAULT NULL,
        p_comments        IN VARCHAR2 DEFAULT NULL,
        p_user            IN VARCHAR2 DEFAULT USER
    );

    PROCEDURE promote_employee(
        p_emp_id          IN NUMBER,
        p_new_job_id      IN NUMBER,
        p_new_salary      IN NUMBER,
        p_effective_date  IN DATE DEFAULT SYSDATE,
        p_comments        IN VARCHAR2 DEFAULT NULL,
        p_user            IN VARCHAR2 DEFAULT USER
    );

    PROCEDURE terminate_employee(
        p_emp_id          IN NUMBER,
        p_termination_date IN DATE,
        p_reason          IN VARCHAR2,
        p_comments        IN VARCHAR2 DEFAULT NULL,
        p_user            IN VARCHAR2 DEFAULT USER
    );

    PROCEDURE rehire_employee(
        p_emp_id          IN NUMBER,
        p_rehire_date     IN DATE,
        p_dept_id         IN NUMBER,
        p_job_id          IN NUMBER,
        p_base_salary     IN NUMBER,
        p_user            IN VARCHAR2 DEFAULT USER
    );

    -- -----------------------------------------------------------------------
    -- Queries and Reports
    -- -----------------------------------------------------------------------
    FUNCTION get_direct_reports(
        p_manager_emp_id IN NUMBER
    ) RETURN t_emp_id_table;

    FUNCTION get_org_chart(
        p_root_emp_id IN NUMBER,
        p_max_depth   IN NUMBER DEFAULT 10
    ) RETURN t_emp_cursor;

    FUNCTION get_headcount_by_dept(
        p_dept_id IN NUMBER DEFAULT NULL,
        p_as_of_date IN DATE DEFAULT SYSDATE
    ) RETURN NUMBER;

    FUNCTION get_tenure_years(
        p_emp_id IN NUMBER
    ) RETURN NUMBER;

    FUNCTION is_active(
        p_emp_id IN NUMBER
    ) RETURN BOOLEAN;

    -- -----------------------------------------------------------------------
    -- Validation
    -- -----------------------------------------------------------------------
    FUNCTION validate_employee(
        p_emp_id IN NUMBER
    ) RETURN BOOLEAN;

    FUNCTION emp_exists(
        p_emp_id IN NUMBER
    ) RETURN BOOLEAN;

    -- -----------------------------------------------------------------------
    -- Utility
    -- -----------------------------------------------------------------------
    FUNCTION generate_emp_number RETURN VARCHAR2;

    PROCEDURE set_session_context(
        p_user    IN VARCHAR2,
        p_emp_id  IN NUMBER
    );

END PKG_EMPLOYEE;
/
