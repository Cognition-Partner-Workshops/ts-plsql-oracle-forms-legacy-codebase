CREATE OR REPLACE PACKAGE BODY HRMS.PKG_REPORTING AS
-- ============================================================================
-- PKG_REPORTING - Report Generation Package Body
-- ============================================================================

    PROCEDURE headcount_report(
        p_cursor     OUT t_report_cursor,
        p_as_of_date IN DATE DEFAULT SYSDATE,
        p_dept_id    IN NUMBER DEFAULT NULL,
        p_location   IN VARCHAR2 DEFAULT NULL
    ) IS
    BEGIN
        OPEN p_cursor FOR
            SELECT d.DEPT_NAME, d.COST_CENTER,
                   l.LOCATION_NAME, l.CITY, l.STATE_PROVINCE,
                   COUNT(*) AS HEADCOUNT,
                   SUM(CASE WHEN e.EMPLOYMENT_TYPE = 'FULL_TIME' THEN 1 ELSE 0 END) AS FT_COUNT,
                   SUM(CASE WHEN e.EMPLOYMENT_TYPE = 'PART_TIME' THEN 1 ELSE 0 END) AS PT_COUNT,
                   SUM(CASE WHEN e.EMPLOYMENT_TYPE = 'CONTRACT' THEN 1 ELSE 0 END) AS CONTRACT_COUNT,
                   SUM(CASE WHEN e.GENDER = 'M' THEN 1 ELSE 0 END) AS MALE_COUNT,
                   SUM(CASE WHEN e.GENDER = 'F' THEN 1 ELSE 0 END) AS FEMALE_COUNT,
                   ROUND(AVG(MONTHS_BETWEEN(p_as_of_date, e.HIRE_DATE) / 12), 1) AS AVG_TENURE_YEARS
            FROM EMPLOYEES e
            JOIN DEPARTMENTS d ON e.DEPT_ID = d.DEPT_ID
            LEFT JOIN LOCATIONS l ON e.LOCATION_CODE = l.LOCATION_CODE
            WHERE e.EMPLOYMENT_STATUS = 'ACTIVE'
            AND e.HIRE_DATE <= p_as_of_date
            AND (e.TERMINATION_DATE IS NULL OR e.TERMINATION_DATE > p_as_of_date)
            AND (p_dept_id IS NULL OR e.DEPT_ID = p_dept_id)
            AND (p_location IS NULL OR e.LOCATION_CODE = p_location)
            GROUP BY d.DEPT_NAME, d.COST_CENTER,
                     l.LOCATION_NAME, l.CITY, l.STATE_PROVINCE
            ORDER BY d.DEPT_NAME;
    END headcount_report;

    PROCEDURE compensation_summary(
        p_cursor   OUT t_report_cursor,
        p_dept_id  IN NUMBER DEFAULT NULL,
        p_grade_id IN NUMBER DEFAULT NULL
    ) IS
    BEGIN
        OPEN p_cursor FOR
            SELECT d.DEPT_NAME, g.GRADE_NAME, j.JOB_TITLE,
                   COUNT(*) AS EMP_COUNT,
                   g.MIN_SALARY AS GRADE_MIN,
                   g.MAX_SALARY AS GRADE_MAX,
                   MIN(sr.BASE_SALARY) AS ACTUAL_MIN,
                   MAX(sr.BASE_SALARY) AS ACTUAL_MAX,
                   ROUND(AVG(sr.BASE_SALARY), 2) AS AVG_SALARY,
                   ROUND(MEDIAN(sr.BASE_SALARY), 2) AS MEDIAN_SALARY,
                   ROUND(AVG(sr.BASE_SALARY / ((g.MIN_SALARY + g.MAX_SALARY) / 2)) * 100, 1) AS COMPA_RATIO
            FROM EMPLOYEES e
            JOIN DEPARTMENTS d ON e.DEPT_ID = d.DEPT_ID
            JOIN JOB_TITLES j ON e.JOB_ID = j.JOB_ID
            JOIN JOB_GRADES g ON j.GRADE_ID = g.GRADE_ID
            JOIN SALARY_RECORDS sr ON e.EMP_ID = sr.EMP_ID AND sr.ACTIVE_FLAG = 'Y'
            WHERE e.EMPLOYMENT_STATUS = 'ACTIVE'
            AND (p_dept_id IS NULL OR e.DEPT_ID = p_dept_id)
            AND (p_grade_id IS NULL OR g.GRADE_ID = p_grade_id)
            GROUP BY d.DEPT_NAME, g.GRADE_NAME, j.JOB_TITLE,
                     g.MIN_SALARY, g.MAX_SALARY
            ORDER BY d.DEPT_NAME, g.GRADE_NAME;
    END compensation_summary;

    PROCEDURE turnover_report(
        p_cursor     OUT t_report_cursor,
        p_start_date IN DATE,
        p_end_date   IN DATE,
        p_dept_id    IN NUMBER DEFAULT NULL
    ) IS
    BEGIN
        OPEN p_cursor FOR
            SELECT d.DEPT_NAME,
                   COUNT(CASE WHEN e.TERMINATION_DATE BETWEEN p_start_date AND p_end_date
                              THEN 1 END) AS TERMINATIONS,
                   COUNT(CASE WHEN e.EMPLOYMENT_STATUS = 'ACTIVE' THEN 1 END) AS CURRENT_HC,
                   ROUND(COUNT(CASE WHEN e.TERMINATION_DATE BETWEEN p_start_date AND p_end_date
                                    THEN 1 END) * 100.0 /
                         NULLIF(COUNT(CASE WHEN e.HIRE_DATE <= p_end_date THEN 1 END), 0), 1) AS TURNOVER_PCT,
                   COUNT(CASE WHEN e.TERMINATION_REASON = 'VOLUNTARY'
                              AND e.TERMINATION_DATE BETWEEN p_start_date AND p_end_date
                              THEN 1 END) AS VOLUNTARY,
                   COUNT(CASE WHEN e.TERMINATION_REASON != 'VOLUNTARY'
                              AND e.TERMINATION_DATE BETWEEN p_start_date AND p_end_date
                              THEN 1 END) AS INVOLUNTARY,
                   ROUND(AVG(CASE WHEN e.TERMINATION_DATE BETWEEN p_start_date AND p_end_date
                                  THEN MONTHS_BETWEEN(e.TERMINATION_DATE, e.HIRE_DATE) / 12 END), 1)
                       AS AVG_TENURE_AT_EXIT
            FROM EMPLOYEES e
            JOIN DEPARTMENTS d ON e.DEPT_ID = d.DEPT_ID
            WHERE (p_dept_id IS NULL OR e.DEPT_ID = p_dept_id)
            AND e.HIRE_DATE <= p_end_date
            GROUP BY d.DEPT_NAME
            HAVING COUNT(CASE WHEN e.HIRE_DATE <= p_end_date THEN 1 END) > 0
            ORDER BY TURNOVER_PCT DESC NULLS LAST;
    END turnover_report;

    PROCEDURE new_hires_report(
        p_cursor     OUT t_report_cursor,
        p_start_date IN DATE,
        p_end_date   IN DATE,
        p_dept_id    IN NUMBER DEFAULT NULL
    ) IS
    BEGIN
        OPEN p_cursor FOR
            SELECT e.EMP_NUMBER, e.FIRST_NAME || ' ' || e.LAST_NAME AS EMP_NAME,
                   e.HIRE_DATE, d.DEPT_NAME, j.JOB_TITLE,
                   l.LOCATION_NAME, e.EMPLOYMENT_TYPE,
                   sr.BASE_SALARY,
                   e.MANAGER_EMP_ID,
                   m.FIRST_NAME || ' ' || m.LAST_NAME AS MANAGER_NAME
            FROM EMPLOYEES e
            JOIN DEPARTMENTS d ON e.DEPT_ID = d.DEPT_ID
            JOIN JOB_TITLES j ON e.JOB_ID = j.JOB_ID
            LEFT JOIN LOCATIONS l ON e.LOCATION_CODE = l.LOCATION_CODE
            LEFT JOIN EMPLOYEES m ON e.MANAGER_EMP_ID = m.EMP_ID
            LEFT JOIN SALARY_RECORDS sr ON e.EMP_ID = sr.EMP_ID AND sr.ACTIVE_FLAG = 'Y'
            WHERE e.HIRE_DATE BETWEEN p_start_date AND p_end_date
            AND (p_dept_id IS NULL OR e.DEPT_ID = p_dept_id)
            ORDER BY e.HIRE_DATE DESC;
    END new_hires_report;

    PROCEDURE leave_utilization_report(
        p_cursor  OUT t_report_cursor,
        p_year    IN NUMBER DEFAULT EXTRACT(YEAR FROM SYSDATE),
        p_dept_id IN NUMBER DEFAULT NULL
    ) IS
    BEGIN
        OPEN p_cursor FOR
            SELECT d.DEPT_NAME, lt.LEAVE_TYPE_NAME,
                   COUNT(DISTINCT lb.EMP_ID) AS EMP_COUNT,
                   ROUND(AVG(lb.OPENING_BALANCE + lb.ACCRUED), 1) AS AVG_ENTITLED,
                   ROUND(AVG(lb.USED), 1) AS AVG_USED,
                   ROUND(AVG(lb.OPENING_BALANCE + lb.ACCRUED - lb.USED + lb.ADJUSTMENT), 1) AS AVG_REMAINING,
                   ROUND(AVG(lb.USED) * 100.0 /
                         NULLIF(AVG(lb.OPENING_BALANCE + lb.ACCRUED), 0), 1) AS UTILIZATION_PCT
            FROM LEAVE_BALANCES lb
            JOIN EMPLOYEES e ON lb.EMP_ID = e.EMP_ID
            JOIN DEPARTMENTS d ON e.DEPT_ID = d.DEPT_ID
            JOIN LEAVE_TYPES lt ON lb.LEAVE_TYPE_ID = lt.LEAVE_TYPE_ID
            WHERE lb.CALENDAR_YEAR = p_year
            AND e.EMPLOYMENT_STATUS = 'ACTIVE'
            AND (p_dept_id IS NULL OR e.DEPT_ID = p_dept_id)
            GROUP BY d.DEPT_NAME, lt.LEAVE_TYPE_NAME
            ORDER BY d.DEPT_NAME, lt.LEAVE_TYPE_NAME;
    END leave_utilization_report;

    PROCEDURE payroll_summary_report(
        p_cursor    OUT t_report_cursor,
        p_period_id IN NUMBER
    ) IS
    BEGIN
        OPEN p_cursor FOR
            SELECT d.DEPT_NAME,
                   COUNT(DISTINCT pd.EMP_ID) AS EMP_COUNT,
                   SUM(CASE WHEN pd.ELEMENT_TYPE = 'EARNING' THEN pd.AMOUNT ELSE 0 END) AS TOTAL_GROSS,
                   SUM(CASE WHEN pd.ELEMENT_ID = 100 THEN ABS(pd.AMOUNT) ELSE 0 END) AS TOTAL_FED_TAX,
                   SUM(CASE WHEN pd.ELEMENT_ID = 101 THEN ABS(pd.AMOUNT) ELSE 0 END) AS TOTAL_STATE_TAX,
                   SUM(CASE WHEN pd.ELEMENT_ID = 102 THEN ABS(pd.AMOUNT) ELSE 0 END) AS TOTAL_SS,
                   SUM(CASE WHEN pd.ELEMENT_ID = 103 THEN ABS(pd.AMOUNT) ELSE 0 END) AS TOTAL_MEDICARE,
                   SUM(CASE WHEN pd.ELEMENT_TYPE IN ('DEDUCTION','BENEFIT')
                            THEN ABS(pd.AMOUNT) ELSE 0 END) AS TOTAL_DEDUCTIONS,
                   SUM(pd.AMOUNT) AS TOTAL_NET
            FROM PAYROLL_DETAILS pd
            JOIN PAYROLL_RUNS pr ON pd.RUN_ID = pr.RUN_ID
            JOIN EMPLOYEES e ON pd.EMP_ID = e.EMP_ID
            JOIN DEPARTMENTS d ON e.DEPT_ID = d.DEPT_ID
            WHERE pr.PERIOD_ID = p_period_id
            AND pd.STATUS != 'ERROR'
            GROUP BY d.DEPT_NAME
            ORDER BY d.DEPT_NAME;
    END payroll_summary_report;

    PROCEDURE eeo_compliance_report(
        p_cursor     OUT t_report_cursor,
        p_as_of_date IN DATE DEFAULT SYSDATE
    ) IS
    BEGIN
        OPEN p_cursor FOR
            SELECT j.EEO_CATEGORY,
                   COUNT(*) AS TOTAL,
                   SUM(CASE WHEN e.GENDER = 'M' THEN 1 ELSE 0 END) AS MALE,
                   SUM(CASE WHEN e.GENDER = 'F' THEN 1 ELSE 0 END) AS FEMALE,
                   SUM(CASE WHEN e.GENDER = 'O' THEN 1 ELSE 0 END) AS OTHER_GENDER,
                   SUM(CASE WHEN e.GENDER IS NULL THEN 1 ELSE 0 END) AS NOT_DISCLOSED,
                   ROUND(SUM(CASE WHEN e.GENDER = 'F' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1)
                       AS FEMALE_PCT
            FROM EMPLOYEES e
            JOIN JOB_TITLES j ON e.JOB_ID = j.JOB_ID
            WHERE e.EMPLOYMENT_STATUS = 'ACTIVE'
            AND e.HIRE_DATE <= p_as_of_date
            GROUP BY j.EEO_CATEGORY
            ORDER BY j.EEO_CATEGORY;
    END eeo_compliance_report;

    PROCEDURE refresh_reporting_tables(
        p_user IN VARCHAR2 DEFAULT USER
    ) IS
    BEGIN
        -- Placeholder for nightly refresh of denormalized reporting tables
        -- In production, this truncates and repopulates RPT_* tables
        PKG_COMMON.log_info('PKG_REPORTING', 'refresh_reporting_tables',
            'Reporting tables refreshed', p_user);
    END refresh_reporting_tables;

END PKG_REPORTING;
/
