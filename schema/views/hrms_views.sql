-- ============================================================================
-- HRMS Database Views
-- Used by Oracle Reports (.rdf), Forms LOVs, and external reporting tools
-- ============================================================================

-- -----------------------------------------------------------------------
-- VW_ACTIVE_EMPLOYEES
-- Commonly used view for active employee lookups
-- -----------------------------------------------------------------------
CREATE OR REPLACE VIEW HRMS.VW_ACTIVE_EMPLOYEES AS
SELECT e.EMP_ID, e.EMP_NUMBER, e.FIRST_NAME, e.LAST_NAME,
       e.FIRST_NAME || ' ' || e.LAST_NAME AS FULL_NAME,
       e.EMAIL, e.PHONE_WORK, e.PHONE_MOBILE,
       e.HIRE_DATE,
       TRUNC(MONTHS_BETWEEN(SYSDATE, e.HIRE_DATE) / 12, 1) AS TENURE_YEARS,
       e.EMPLOYMENT_TYPE, e.EMPLOYMENT_STATUS,
       e.DEPT_ID, d.DEPT_NAME, d.DEPT_CODE, d.COST_CENTER,
       e.JOB_ID, j.JOB_TITLE, j.JOB_CODE,
       g.GRADE_ID, g.GRADE_NAME,
       e.MANAGER_EMP_ID,
       m.FIRST_NAME || ' ' || m.LAST_NAME AS MANAGER_NAME,
       e.LOCATION_CODE,
       l.LOCATION_NAME, l.CITY, l.STATE_PROVINCE, l.COUNTRY_CODE,
       sr.BASE_SALARY AS CURRENT_SALARY,
       sr.CURRENCY_CODE, sr.PAY_FREQUENCY
FROM EMPLOYEES e
JOIN DEPARTMENTS d ON e.DEPT_ID = d.DEPT_ID
JOIN JOB_TITLES j ON e.JOB_ID = j.JOB_ID
JOIN JOB_GRADES g ON j.GRADE_ID = g.GRADE_ID
LEFT JOIN EMPLOYEES m ON e.MANAGER_EMP_ID = m.EMP_ID
LEFT JOIN LOCATIONS l ON e.LOCATION_CODE = l.LOCATION_CODE
LEFT JOIN SALARY_RECORDS sr ON e.EMP_ID = sr.EMP_ID
    AND sr.ACTIVE_FLAG = 'Y'
    AND sr.EFFECTIVE_DATE <= SYSDATE
    AND (sr.END_DATE IS NULL OR sr.END_DATE > SYSDATE)
WHERE e.EMPLOYMENT_STATUS = 'ACTIVE'
AND e.ACTIVE_FLAG = 'Y';

COMMENT ON TABLE HRMS.VW_ACTIVE_EMPLOYEES IS
    'Denormalized view of active employees with department, job, manager, location, and salary';

-- -----------------------------------------------------------------------
-- VW_ORG_HIERARCHY
-- Hierarchical org chart using CONNECT BY
-- WARNING: Performance degrades significantly with >500 employees
-- -----------------------------------------------------------------------
CREATE OR REPLACE VIEW HRMS.VW_ORG_HIERARCHY AS
SELECT EMP_ID, EMP_NUMBER, FIRST_NAME || ' ' || LAST_NAME AS EMP_NAME,
       MANAGER_EMP_ID, DEPT_ID,
       LEVEL AS ORG_LEVEL,
       SYS_CONNECT_BY_PATH(FIRST_NAME || ' ' || LAST_NAME, ' > ') AS ORG_PATH,
       CONNECT_BY_ISLEAF AS IS_LEAF
FROM EMPLOYEES
WHERE EMPLOYMENT_STATUS = 'ACTIVE'
START WITH MANAGER_EMP_ID IS NULL
CONNECT BY PRIOR EMP_ID = MANAGER_EMP_ID
ORDER SIBLINGS BY LAST_NAME;

-- -----------------------------------------------------------------------
-- VW_EMPLOYEE_COMPENSATION
-- Current compensation details with compa-ratio calculation
-- -----------------------------------------------------------------------
CREATE OR REPLACE VIEW HRMS.VW_EMPLOYEE_COMPENSATION AS
SELECT e.EMP_ID, e.EMP_NUMBER,
       e.FIRST_NAME || ' ' || e.LAST_NAME AS EMP_NAME,
       d.DEPT_NAME, j.JOB_TITLE, g.GRADE_NAME,
       sr.BASE_SALARY,
       g.MIN_SALARY AS GRADE_MIN,
       g.MAX_SALARY AS GRADE_MAX,
       (g.MIN_SALARY + g.MAX_SALARY) / 2 AS GRADE_MIDPOINT,
       ROUND(sr.BASE_SALARY / ((g.MIN_SALARY + g.MAX_SALARY) / 2) * 100, 1) AS COMPA_RATIO,
       sr.EFFECTIVE_DATE AS SALARY_EFFECTIVE_DATE,
       sr.CHANGE_REASON AS LAST_CHANGE_REASON,
       sr.CHANGE_PCT AS LAST_CHANGE_PCT
FROM EMPLOYEES e
JOIN DEPARTMENTS d ON e.DEPT_ID = d.DEPT_ID
JOIN JOB_TITLES j ON e.JOB_ID = j.JOB_ID
JOIN JOB_GRADES g ON j.GRADE_ID = g.GRADE_ID
JOIN SALARY_RECORDS sr ON e.EMP_ID = sr.EMP_ID AND sr.ACTIVE_FLAG = 'Y'
WHERE e.EMPLOYMENT_STATUS = 'ACTIVE';

-- -----------------------------------------------------------------------
-- VW_LEAVE_SUMMARY
-- Current year leave balances with utilization
-- -----------------------------------------------------------------------
CREATE OR REPLACE VIEW HRMS.VW_LEAVE_SUMMARY AS
SELECT e.EMP_ID, e.EMP_NUMBER,
       e.FIRST_NAME || ' ' || e.LAST_NAME AS EMP_NAME,
       d.DEPT_NAME,
       lt.LEAVE_TYPE_NAME,
       lb.OPENING_BALANCE,
       lb.ACCRUED,
       lb.USED,
       lb.ADJUSTMENT,
       lb.PENDING,
       lb.OPENING_BALANCE + lb.ACCRUED - lb.USED + lb.ADJUSTMENT AS AVAILABLE,
       ROUND(lb.USED * 100 / NULLIF(lb.OPENING_BALANCE + lb.ACCRUED, 0), 1) AS UTILIZATION_PCT
FROM LEAVE_BALANCES lb
JOIN EMPLOYEES e ON lb.EMP_ID = e.EMP_ID
JOIN DEPARTMENTS d ON e.DEPT_ID = d.DEPT_ID
JOIN LEAVE_TYPES lt ON lb.LEAVE_TYPE_ID = lt.LEAVE_TYPE_ID
WHERE lb.CALENDAR_YEAR = EXTRACT(YEAR FROM SYSDATE)
AND e.EMPLOYMENT_STATUS = 'ACTIVE';

-- -----------------------------------------------------------------------
-- VW_PAYROLL_LATEST
-- Latest payroll run details per employee
-- -----------------------------------------------------------------------
CREATE OR REPLACE VIEW HRMS.VW_PAYROLL_LATEST AS
SELECT pd.EMP_ID, e.EMP_NUMBER,
       e.FIRST_NAME || ' ' || e.LAST_NAME AS EMP_NAME,
       pp.PERIOD_NAME,
       SUM(CASE WHEN pd.ELEMENT_TYPE = 'EARNING' THEN pd.AMOUNT ELSE 0 END) AS GROSS_PAY,
       SUM(CASE WHEN pd.ELEMENT_TYPE = 'TAX' THEN ABS(pd.AMOUNT) ELSE 0 END) AS TOTAL_TAXES,
       SUM(CASE WHEN pd.ELEMENT_TYPE IN ('DEDUCTION','BENEFIT') THEN ABS(pd.AMOUNT) ELSE 0 END) AS TOTAL_DEDUCTIONS,
       SUM(pd.AMOUNT) AS NET_PAY
FROM PAYROLL_DETAILS pd
JOIN EMPLOYEES e ON pd.EMP_ID = e.EMP_ID
JOIN PAYROLL_RUNS pr ON pd.RUN_ID = pr.RUN_ID
JOIN PAY_PERIODS pp ON pr.PERIOD_ID = pp.PERIOD_ID
WHERE pr.RUN_ID = (
    SELECT MAX(pr2.RUN_ID)
    FROM PAYROLL_RUNS pr2
    WHERE pr2.STATUS = 'APPROVED'
)
AND pd.STATUS != 'ERROR'
GROUP BY pd.EMP_ID, e.EMP_NUMBER,
         e.FIRST_NAME || ' ' || e.LAST_NAME,
         pp.PERIOD_NAME;

-- -----------------------------------------------------------------------
-- VW_PENDING_APPROVALS
-- Unified view of items pending approval across modules
-- -----------------------------------------------------------------------
CREATE OR REPLACE VIEW HRMS.VW_PENDING_APPROVALS AS
SELECT 'LEAVE' AS APPROVAL_TYPE,
       lr.REQUEST_ID AS ITEM_ID,
       lr.APPROVER_EMP_ID AS APPROVER_ID,
       e.FIRST_NAME || ' ' || e.LAST_NAME AS REQUESTOR_NAME,
       lt.LEAVE_TYPE_NAME AS ITEM_DESCRIPTION,
       lr.CREATED_DATE AS REQUEST_DATE,
       lr.TOTAL_DAYS || ' day(s) ' ||
           TO_CHAR(lr.START_DATE, 'MM/DD') || '-' || TO_CHAR(lr.END_DATE, 'MM/DD') AS DETAILS
FROM LEAVE_REQUESTS lr
JOIN EMPLOYEES e ON lr.EMP_ID = e.EMP_ID
JOIN LEAVE_TYPES lt ON lr.LEAVE_TYPE_ID = lt.LEAVE_TYPE_ID
WHERE lr.STATUS = 'PENDING'
UNION ALL
SELECT 'PERFORMANCE' AS APPROVAL_TYPE,
       pr.REVIEW_ID AS ITEM_ID,
       pr.REVIEWER_EMP_ID AS APPROVER_ID,
       e.FIRST_NAME || ' ' || e.LAST_NAME AS REQUESTOR_NAME,
       'Performance Review - ' || rc.CYCLE_NAME AS ITEM_DESCRIPTION,
       pr.CREATED_DATE AS REQUEST_DATE,
       pr.STATUS AS DETAILS
FROM PERFORMANCE_REVIEWS pr
JOIN EMPLOYEES e ON pr.EMP_ID = e.EMP_ID
JOIN REVIEW_CYCLES rc ON pr.CYCLE_ID = rc.CYCLE_ID
WHERE pr.STATUS = 'MANAGER_REVIEW';
