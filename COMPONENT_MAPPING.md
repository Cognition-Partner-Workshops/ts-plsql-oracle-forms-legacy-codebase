# HRMS Component Mapping: Oracle Forms to Java/React

## Overview

This document maps every Oracle Forms element in the HRMS application to its equivalent in a modern Java (Spring Boot) / React technology stack. The mapping covers all 6 Forms modules, 2 PLL libraries, the menu module, all PL/SQL packages, database objects, and cross-cutting concerns.

---

## Table of Contents

1. [Forms Module Mappings](#1-forms-module-mappings)
2. [PLL Library Mappings](#2-pll-library-mappings)
3. [Menu Module Mapping](#3-menu-module-mapping)
4. [PL/SQL Package Mappings](#4-plsql-package-mappings)
5. [Database Object Mappings](#5-database-object-mappings)
6. [Forms Built-in Mappings](#6-forms-built-in-mappings)
7. [Trigger Type Mappings](#7-trigger-type-mappings)

---

## 1. Forms Module Mappings

### 1.1 HRMS_LOGIN (Login & Authentication)

| Forms Element | Type | Java/React Equivalent |
|--------------|------|----------------------|
| **Module: HRMS_LOGIN** | Form Module | React Route: `/login` (LoginPage component) |
| CVS_LOGIN | Canvas (Content) | React component: `<LoginForm />` |
| LOGIN | Data Block (Control, non-DB) | React state: `useState({ username, password, errorMsg })` |
| LOGIN.USERNAME | Text Item | `<input type="text" />` or MUI `<TextField label="Username" />` |
| LOGIN.PASSWORD | Text Item (Obscured) | `<input type="password" />` or MUI `<TextField type="password" />` |
| LOGIN.ERROR_MSG | Display Item | Conditional `<Alert severity="error" />` component |
| LOGIN.BTN_LOGIN | Push Button | `<Button onClick={handleLogin} />` |
| WHEN-BUTTON-PRESSED (BTN_LOGIN) | Trigger | `handleLogin()` async function calling `POST /api/auth/login` |
| PKG_SECURITY.authenticate() call | PL/SQL | Spring Security `AuthenticationManager.authenticate()` |
| :GLOBAL.session_id | Global Variable | JWT token stored in `localStorage` or HTTP-only cookie |
| :GLOBAL.current_user | Global Variable | JWT claims / React Context `useAuth()` |
| :GLOBAL.current_emp_id | Global Variable | JWT claims / React Context `useAuth()` |
| OPEN_FORM('HRMS_MENU') | Built-in | `navigate('/dashboard')` (React Router) |
| GET_APPLICATION_PROPERTY(CLIENT_HOST) | Built-in | `request.getRemoteAddr()` (Spring) |

**Authentication Flow:**
```
Legacy: Forms Login -> PKG_SECURITY.authenticate() -> GLOBAL variables -> OPEN_FORM
Modern: React LoginPage -> POST /api/auth/login -> JWT token -> React Router navigate
```

---

### 1.2 HRMS_MENU (Main Navigation Shell)

| Forms Element | Type | Java/React Equivalent |
|--------------|------|----------------------|
| **Module: HRMS_MENU** | Form Module (MDI Parent) | React component: `<AppShell />` or `<DashboardLayout />` |
| CVS_MAIN | Canvas (Content) | React layout: `<Sidebar />` + `<main>` content area |
| CVS_HEADER | Canvas (Stacked) | `<AppBar />` or `<Header />` component |
| MENU_CONTROL | Data Block (Control) | React state + Context for navigation |
| BTN_EMPLOYEES | Push Button | `<NavLink to="/employees" />` or Sidebar menu item |
| BTN_PAYROLL | Push Button | `<NavLink to="/payroll" />` |
| BTN_LEAVE | Push Button | `<NavLink to="/leave" />` |
| BTN_PERFORMANCE | Push Button | `<NavLink to="/performance" />` |
| BTN_REPORTS | Push Button | `<NavLink to="/reports" />` |
| BTN_LOGOUT | Push Button | `<NavLink onClick={logout} />` |
| OPEN_FORM('HRMS_EMPLOYEE', ACTIVATE, SESSION) | Built-in | `<Route path="/employees" element={<EmployeePage />} />` |
| OPEN_FORM('HRMS_PAYROLL', ACTIVATE, SESSION) | Built-in | `<Route path="/payroll" element={<PayrollPage />} />` |
| OPEN_FORM('HRMS_LEAVE', ACTIVATE, SESSION) | Built-in | `<Route path="/leave" element={<LeavePage />} />` |
| OPEN_FORM('HRMS_PERFORMANCE', ACTIVATE, SESSION) | Built-in | `<Route path="/performance" element={<PerformancePage />} />` |
| PKG_SECURITY.has_permission() | Menu security | React RBAC: `<ProtectedRoute requiredRole="..." />` |
| SET_MENU_ITEM_PROPERTY(..., ENABLED) | Runtime menu control | Conditional rendering: `{hasPermission('PAYROLL') && <NavLink />}` |
| EXIT_FORM | Built-in | `logout()` -> clear JWT -> `navigate('/login')` |

**Menu Module (HRMS_MENU.mmb.sql):**

| Menu Item | Menu Path | Java/React Equivalent |
|-----------|-----------|----------------------|
| MNU_FILE > Save | File > Save | Toolbar `<IconButton onClick={save} />` or Ctrl+S handler |
| MNU_FILE > Exit | File > Exit | Logout button in AppBar |
| MNU_EDIT > Cut/Copy/Paste | Edit menu | Native browser clipboard (no mapping needed) |
| MNU_QUERY > Enter/Execute/Cancel | Query menu | Search/filter controls in each module's list view |
| MNU_NAVIGATE > First/Prev/Next/Last | Navigate menu | Pagination component: `<TablePagination />` |
| MNU_MODULES > Employees | Modules menu | `<NavLink to="/employees" />` in sidebar |
| MNU_MODULES > Payroll | Modules menu | `<NavLink to="/payroll" />` |
| MNU_MODULES > Leave | Modules menu | `<NavLink to="/leave" />` |
| MNU_MODULES > Performance | Modules menu | `<NavLink to="/performance" />` |
| MNU_ADMIN > System Parameters | Admin menu | `<NavLink to="/admin/settings" />` (admin-only) |
| MNU_ADMIN > User Sessions | Admin menu | `<NavLink to="/admin/sessions" />` (admin-only) |
| MNU_HELP > About | Help menu | `<Dialog>` with app version info |

---

### 1.3 HRMS_EMPLOYEE (Employee Management)

| Forms Element | Type | Java/React Equivalent |
|--------------|------|----------------------|
| **Module: HRMS_EMPLOYEE** | Form Module | React page: `<EmployeePage />` with sub-routes |
| **Canvases** | | |
| CVS_MAIN | Content Canvas | `<EmployeeLayout />` wrapper component |
| TP_PERSONAL | Tab Page | `<Tabs>` panel or React Router nested route `/employees/:id/personal` |
| TP_JOB | Tab Page | Tab panel or route `/employees/:id/job` |
| TP_DEPENDENTS | Tab Page | Tab panel or route `/employees/:id/dependents` |
| TP_HISTORY | Tab Page | Tab panel or route `/employees/:id/history` |
| **Data Blocks** | | |
| EMPLOYEE | Data Block (DB: EMPLOYEES) | React Query + form state: `useQuery(['employee', id])` + `useForm()` |
| SALARY | Data Block (DB: SALARY_RECORDS) | Nested component: `<SalaryHistory />` with `useQuery(['salaries', empId])` |
| DEPENDENT | Data Block (DB: EMPLOYEE_DEPENDENTS) | `<DependentsList />` component with CRUD |
| HISTORY | Data Block (DB: EMPLOYEE_HISTORY, read-only) | `<EmployeeHistoryTable />` read-only data grid |
| TOOLBAR | Control Block | `<EmployeeToolbar />` with action buttons |
| **EMPLOYEE Block Items** | | |
| EMPLOYEE.EMP_ID | Number (Hidden) | Route param: `useParams().id` |
| EMPLOYEE.EMP_NUMBER | Text (Display) | `<Typography>` or read-only `<TextField />` |
| EMPLOYEE.FIRST_NAME | Text Item | `<TextField name="firstName" />` with validation |
| EMPLOYEE.LAST_NAME | Text Item | `<TextField name="lastName" />` with validation |
| EMPLOYEE.MIDDLE_NAME | Text Item | `<TextField name="middleName" />` |
| EMPLOYEE.DATE_OF_BIRTH | Date Item | `<DatePicker name="dateOfBirth" />` |
| EMPLOYEE.GENDER | List Item | `<Select name="gender">` with options M/F/O |
| EMPLOYEE.MARITAL_STATUS | List Item | `<Select name="maritalStatus">` |
| EMPLOYEE.EMAIL | Text Item | `<TextField type="email" />` with email validation |
| EMPLOYEE.PHONE_WORK | Text Item | `<TextField />` with phone mask (react-input-mask) |
| EMPLOYEE.PHONE_MOBILE | Text Item | `<TextField />` with phone mask |
| EMPLOYEE.ADDRESS_LINE1 | Text Item | `<TextField name="addressLine1" />` |
| EMPLOYEE.ADDRESS_LINE2 | Text Item | `<TextField name="addressLine2" />` |
| EMPLOYEE.CITY | Text Item | `<TextField name="city" />` |
| EMPLOYEE.STATE_PROVINCE | Text Item / LOV | `<Autocomplete />` or `<Select>` with state list |
| EMPLOYEE.POSTAL_CODE | Text Item | `<TextField />` with postal code pattern |
| EMPLOYEE.COUNTRY_CODE | List Item | `<Select>` with country codes |
| EMPLOYEE.HIRE_DATE | Date Item | `<DatePicker />` with max future date validation (90 days) |
| EMPLOYEE.TERMINATION_DATE | Date Item (Conditional) | `<DatePicker />` shown only when status = TERMINATED |
| EMPLOYEE.DEPT_ID | LOV Item | `<Autocomplete />` fetching from `GET /api/departments` |
| EMPLOYEE.JOB_ID | LOV Item | `<Autocomplete />` fetching from `GET /api/jobs` |
| EMPLOYEE.MANAGER_EMP_ID | LOV Item | `<Autocomplete />` fetching from `GET /api/employees/active` |
| EMPLOYEE.LOCATION_CODE | LOV Item | `<Autocomplete />` fetching from `GET /api/locations` |
| EMPLOYEE.EMPLOYMENT_TYPE | List Item | `<Select>` options: FULL_TIME, PART_TIME, CONTRACT, INTERN |
| EMPLOYEE.EMPLOYMENT_STATUS | Display Item | `<Chip />` color-coded status badge |
| EMPLOYEE.ACTIVE_FLAG | Checkbox | Derived from EMPLOYMENT_STATUS (not directly editable) |
| EMPLOYEE.PHOTO_BLOB | Image Item | `<Avatar />` with file upload (`<input type="file" accept="image/*" />`) |
| EMPLOYEE.SSN_ENCRYPTED | Text (Masked) | `<TextField />` with SSN mask, masked display (***-**-1234) |
| **LOVs (List of Values)** | | |
| LOV_DEPARTMENTS | Record Group + LOV | `<Autocomplete>` with `GET /api/departments?active=true` |
| LOV_JOB_TITLES | Record Group + LOV | `<Autocomplete>` with `GET /api/jobs?active=true` |
| LOV_MANAGERS | Record Group + LOV | `<Autocomplete>` with `GET /api/employees?status=ACTIVE` |
| LOV_LOCATIONS | Record Group + LOV | `<Autocomplete>` with `GET /api/locations?active=true` |
| LOV_GENDERS | Static LOV | `<Select>` with static options array |
| LOV_MARITAL_STATUS | Static LOV | `<Select>` with static options from lookup API |
| LOV_EMP_TYPES | Static LOV | `<Select>` with static options |
| LOV_COUNTRIES | Record Group + LOV | `<Autocomplete>` with country list (i18n library) |
| **Triggers** | | |
| WHEN-NEW-FORM-INSTANCE | Form-level | `useEffect(() => { checkAuth(); loadPermissions(); }, [])` |
| ON-ERROR | Form-level | Global error boundary: `<ErrorBoundary />` + toast notifications |
| KEY-EXIT | Form-level | `beforeunload` event handler for unsaved changes |
| PRE-INSERT | Block-level (EMPLOYEE) | `onSubmit` handler: set EMP_ID, EMP_NUMBER, defaults before `POST /api/employees` |
| PRE-UPDATE | Block-level | `onSubmit` handler: set MODIFIED_BY, MODIFIED_DATE (server-side) |
| POST-QUERY | Block-level | `useEffect` after query: format display values, compute derived fields |
| WHEN-VALIDATE-ITEM (EMAIL) | Item-level | `react-hook-form` field validation: `register('email', { validate: validateEmail })` |
| WHEN-VALIDATE-ITEM (HIRE_DATE) | Item-level | `register('hireDate', { validate: d => d <= addDays(new Date(), 90) })` |
| WHEN-VALIDATE-ITEM (SALARY) | Item-level | `register('salary', { validate: v => validateSalaryRange(v, gradeId) })` |

---

### 1.4 HRMS_PAYROLL (Payroll Processing)

| Forms Element | Type | Java/React Equivalent |
|--------------|------|----------------------|
| **Module: HRMS_PAYROLL** | Form Module | React page: `<PayrollPage />` |
| **Canvases** | | |
| CVS_PERIODS | Tab Page | Tab: `<PayPeriodsTab />` |
| CVS_RUNS | Tab Page | Tab: `<PayrollRunsTab />` |
| CVS_DETAILS | Tab Page | Tab: `<PayrollDetailsTab />` |
| **Data Blocks** | | |
| PAY_PERIOD | Data Block (DB: PAY_PERIODS, read-only) | `<DataGrid>` with `useQuery(['payPeriods'])` |
| PAYROLL_RUN | Data Block (DB: PAYROLL_RUNS) | `<DataGrid>` with `useQuery(['payrollRuns', periodId])` |
| PAYROLL_DETAIL | Data Block (DB: PAYROLL_DETAILS, read-only) | `<DataGrid>` with `useQuery(['payrollDetails', runId])` |
| **Items** | | |
| PAY_PERIOD.PERIOD_NAME | Display Item | `<DataGrid>` column |
| PAY_PERIOD.STATUS | Display Item | `<Chip>` color-coded (OPEN=green, CLOSED=grey) |
| PAY_PERIOD.PERIOD_START_DATE | Date Display | Formatted date column |
| PAY_PERIOD.PERIOD_END_DATE | Date Display | Formatted date column |
| PAY_PERIOD.PAY_DATE | Date Display | Formatted date column |
| PAYROLL_RUN.RUN_TYPE | List Item | `<Select>` options: REGULAR, SUPPLEMENTAL, BONUS, FINAL |
| PAYROLL_RUN.STATUS | Display Item | `<Chip>` with status-specific colors and icons |
| PAYROLL_RUN.TOTAL_GROSS | Number Display | Formatted currency: `<Typography>{formatCurrency(totalGross)}</Typography>` |
| PAYROLL_RUN.TOTAL_NET | Number Display | Formatted currency |
| PAYROLL_RUN.EMPLOYEE_COUNT | Number Display | `<Typography>` |
| PAYROLL_RUN.ERROR_COUNT | Number Display | `<Badge badgeContent={errorCount} color="error">` |
| **Action Buttons** | | |
| BTN_CREATE_RUN | Push Button | `<Button onClick={() => mutation.mutate({ periodId, type })}>Create Run</Button>` calling `POST /api/payroll/runs` |
| BTN_CALCULATE | Push Button | `<Button onClick={calculatePayroll}>Calculate</Button>` calling `POST /api/payroll/runs/:id/calculate` |
| BTN_APPROVE | Push Button | `<Button onClick={approvePayroll}>Approve</Button>` calling `POST /api/payroll/runs/:id/approve` |
| BTN_REVERSE | Push Button | `<Button color="error" onClick={reversePayroll}>Reverse</Button>` with confirmation dialog |
| **Triggers** | | |
| WHEN-NEW-FORM-INSTANCE | Form-level | `useEffect` to load current pay period and permissions |
| WHEN-BUTTON-PRESSED (BTN_CREATE_RUN) | Item-level | `useMutation` for `POST /api/payroll/runs` |
| WHEN-BUTTON-PRESSED (BTN_CALCULATE) | Item-level | `useMutation` for `POST /api/payroll/runs/:id/calculate` (async with progress) |
| WHEN-BUTTON-PRESSED (BTN_APPROVE) | Item-level | `useMutation` with confirmation dialog |

---

### 1.5 HRMS_LEAVE (Leave Management)

| Forms Element | Type | Java/React Equivalent |
|--------------|------|----------------------|
| **Module: HRMS_LEAVE** | Form Module | React page: `<LeavePage />` |
| **Canvases** | | |
| TP_MY_LEAVE | Tab Page | Tab: `<MyLeaveTab />` |
| TP_NEW_REQUEST | Tab Page | Tab/Dialog: `<NewLeaveRequestForm />` |
| TP_BALANCES | Tab Page | Tab: `<LeaveBalancesTab />` |
| TP_TEAM | Tab Page | Tab: `<TeamCalendarTab />` (manager-only) |
| **Data Blocks** | | |
| LEAVE_REQUEST | Data Block (DB: LEAVE_REQUESTS, read-only) | `<DataGrid>` with `useQuery(['leaveRequests', empId])` |
| NEW_REQUEST | Control Block (non-DB) | React form state: `useForm<LeaveRequestInput>()` |
| LEAVE_BALANCE | Data Block (DB: VW_LEAVE_SUMMARY, read-only) | `<LeaveBalanceCards />` with `useQuery(['leaveBalances', empId])` |
| TEAM_LEAVE | Data Block (read-only) | `<Calendar />` component with team leave overlay |
| **NEW_REQUEST Block Items** | | |
| NR_LEAVE_TYPE_ID | LOV Item | `<Select>` fetching from `GET /api/leave-types` |
| NR_START_DATE | Date Item | `<DatePicker>` with business day validation |
| NR_END_DATE | Date Item | `<DatePicker>` with min=startDate validation |
| NR_HALF_DAY | Checkbox | `<Checkbox label="Half Day" />` |
| NR_HALF_DAY_PERIOD | Radio Group | `<RadioGroup>` options: AM, PM (shown when half-day checked) |
| NR_REASON | Text Area | `<TextField multiline rows={3} />` |
| NR_TOTAL_DAYS | Display Item (calculated) | `<Typography>` showing calculated business days |
| NR_AVAILABLE_BALANCE | Display Item | `<Typography>` showing current balance for selected type |
| BTN_SUBMIT | Push Button | `<Button type="submit">Submit Request</Button>` calling `POST /api/leave/requests` |
| BTN_CANCEL | Push Button | `<Button variant="outlined" onClick={resetForm}>Cancel</Button>` |
| **LEAVE_REQUEST Block Items** | | |
| REQUEST_ID | Hidden | Row identifier |
| LEAVE_TYPE_NAME | Display | `<DataGrid>` column |
| START_DATE | Date Display | `<DataGrid>` date column |
| END_DATE | Date Display | `<DataGrid>` date column |
| TOTAL_DAYS | Number Display | `<DataGrid>` column |
| STATUS | Display | `<Chip>` color-coded (PENDING=orange, APPROVED=green, REJECTED=red) |
| BTN_APPROVE | Push Button (manager) | `<IconButton onClick={() => approve(requestId)}>` calling `POST /api/leave/requests/:id/approve` |
| BTN_REJECT | Push Button (manager) | `<IconButton onClick={() => reject(requestId)}>` with reason dialog |
| BTN_CANCEL_REQUEST | Push Button | `<IconButton onClick={() => cancel(requestId)}>` with confirmation |
| **Triggers** | | |
| WHEN-NEW-FORM-INSTANCE | Form-level | `useEffect` to load balances and permissions |
| WHEN-VALIDATE-ITEM (NR_START_DATE) | Item-level | `register('startDate', { validate: validateStartDate })` |
| WHEN-VALIDATE-ITEM (NR_END_DATE) | Item-level | `register('endDate', { validate: d => d >= startDate })` |
| WHEN-BUTTON-PRESSED (BTN_SUBMIT) | Item-level | `onSubmit` handler with validation chain |
| POST-QUERY (LEAVE_BALANCE) | Block-level | Auto-handled by React Query on data fetch |

---

### 1.6 HRMS_PERFORMANCE (Performance Reviews)

| Forms Element | Type | Java/React Equivalent |
|--------------|------|----------------------|
| **Module: HRMS_PERFORMANCE** | Form Module | React page: `<PerformancePage />` |
| **Canvases** | | |
| TP_CYCLES | Tab Page | Tab: `<ReviewCyclesTab />` |
| TP_REVIEWS | Tab Page | Tab: `<ReviewsTab />` |
| TP_GOALS | Tab Page | Tab: `<GoalsTab />` |
| **Data Blocks** | | |
| REVIEW_CYCLE | Data Block (DB: REVIEW_CYCLES) | `<DataGrid>` with `useQuery(['reviewCycles'])` |
| PERFORMANCE_REVIEW | Data Block (DB: PERFORMANCE_REVIEWS) | `<ReviewList />` component or detail view |
| PERFORMANCE_GOAL | Data Block (DB: PERFORMANCE_GOALS) | `<GoalList />` component with CRUD |
| **Relations (Master-Detail)** | | |
| CYCLE_REVIEW_REL | Relation (REVIEW_CYCLE -> PERFORMANCE_REVIEW) | React Query dependent queries: `useQuery(['reviews', cycleId], { enabled: !!cycleId })` |
| REVIEW_GOAL_REL | Relation (PERFORMANCE_REVIEW -> PERFORMANCE_GOAL) | `useQuery(['goals', reviewId], { enabled: !!reviewId })` |
| **Items** | | |
| REVIEW_CYCLE.CYCLE_NAME | Text Item | `<TextField />` |
| REVIEW_CYCLE.STATUS | Display Item | `<Chip>` (DRAFT, OPEN, IN_PROGRESS, CALIBRATION, CLOSED) |
| REVIEW_CYCLE.START_DATE | Date Item | `<DatePicker />` |
| REVIEW_CYCLE.END_DATE | Date Item | `<DatePicker />` |
| PERFORMANCE_REVIEW.OVERALL_RATING | Number Item | `<Rating precision={0.5} max={5} />` (MUI Rating component) |
| PERFORMANCE_REVIEW.SELF_ASSESSMENT | Long Text (CLOB) | `<RichTextEditor />` (Quill, TipTap, or similar) |
| PERFORMANCE_REVIEW.MANAGER_ASSESSMENT | Long Text (CLOB) | `<RichTextEditor />` |
| PERFORMANCE_REVIEW.STRENGTHS | Long Text (CLOB) | `<RichTextEditor />` |
| PERFORMANCE_REVIEW.AREAS_FOR_IMPROVEMENT | Long Text (CLOB) | `<RichTextEditor />` |
| PERFORMANCE_REVIEW.DEVELOPMENT_PLAN | Long Text (CLOB) | `<RichTextEditor />` |
| PERFORMANCE_GOAL.GOAL_TITLE | Text Item | `<TextField />` |
| PERFORMANCE_GOAL.GOAL_CATEGORY | List Item | `<Select>` options: BUSINESS, DEVELOPMENT, LEADERSHIP, INNOVATION, COMPLIANCE |
| PERFORMANCE_GOAL.WEIGHT_PCT | Number Item | `<Slider />` or `<TextField type="number" />` (0-100) |
| PERFORMANCE_GOAL.PROGRESS_PCT | Number Item | `<LinearProgress variant="determinate" />` with editable value |
| PERFORMANCE_GOAL.TARGET_DATE | Date Item | `<DatePicker />` |
| PERFORMANCE_GOAL.STATUS | List Item | `<Select>` options: NOT_STARTED, IN_PROGRESS, COMPLETED, DEFERRED, CANCELLED |
| **Triggers** | | |
| WHEN-NEW-FORM-INSTANCE | Form-level | `useEffect` for auth check and data load |
| ON-POPULATE-DETAILS (CYCLE_REVIEW_REL) | Relation trigger | Automatic via dependent React Query |
| ON-POPULATE-DETAILS (REVIEW_GOAL_REL) | Relation trigger | Automatic via dependent React Query |

---

## 2. PLL Library Mappings

### 2.1 HRMS_COMMON_LIB.pll

| PLL Function/Procedure | Purpose | Java/React Equivalent |
|------------------------|---------|----------------------|
| `handle_error(p_module, p_location)` | Error logging + display | Global error handler: `try/catch` + `toast.error()` + `POST /api/logs/error` |
| `toolbar_save` | Commit form | Form `onSubmit` handler calling PUT/POST API |
| `toolbar_clear` | Clear form | `form.reset()` (react-hook-form) |
| `toolbar_query` | Execute query | `queryClient.invalidateQueries()` or search handler |
| `toolbar_first` | Navigate to first record | Pagination: `setPage(0)` |
| `toolbar_prev` | Navigate to previous record | `setPage(p => Math.max(0, p - 1))` |
| `toolbar_next` | Navigate to next record | `setPage(p => p + 1)` |
| `toolbar_last` | Navigate to last record | `setPage(totalPages - 1)` |
| `toolbar_insert` | Create new record | `navigate('/employees/new')` or open create dialog |
| `toolbar_delete` | Delete current record | `DELETE /api/resource/:id` with confirmation dialog |
| `toolbar_exit` | Close form | `navigate(-1)` or `navigate('/dashboard')` |
| `format_date(p_date)` | Format date for display | `dayjs(date).format('MM/DD/YYYY')` or `Intl.DateTimeFormat` |
| `format_datetime(p_date)` | Format date+time | `dayjs(date).format('MM/DD/YYYY HH:mm')` |
| `get_current_user` | Get logged-in user | `useAuth().currentUser` from auth context |
| `get_session_id` | Get session ID | JWT token or `useAuth().sessionId` |
| `check_session` | Validate session active | Axios interceptor checking 401 responses + JWT expiry check |
| `refresh_lov(p_lov_name)` | Refresh LOV data | `queryClient.invalidateQueries(['departments'])` etc. |

### 2.2 HRMS_VALIDATION_LIB.pll

| PLL Function | Purpose | Java/React Equivalent |
|-------------|---------|----------------------|
| `validate_email(p_email)` | Email format check | `zod.string().email()` or `yup.string().email()` (also server-side: `@Email` annotation) |
| `validate_phone(p_phone)` | Phone format check | Regex validation: `/^\+?[\d\s\-()]{10,15}$/` + `libphonenumber-js` |
| `validate_ssn(p_ssn)` | SSN format check | Regex: `/^\d{3}-?\d{2}-?\d{4}$/` (client) + server validation |
| `validate_date_not_future(p_date)` | Date not in future | `zod.date().max(new Date())` or custom validator |
| `validate_salary_range(p_salary, p_grade)` | Salary within grade range | Custom validator calling `GET /api/grades/:id/salary-range` |

> **Important:** The legacy system has validation drift between `HRMS_VALIDATION_LIB` (client-side PLL) and `PKG_VALIDATION` (server-side PL/SQL). The modern system MUST have a single source of truth for validation rules, enforced server-side and optionally mirrored client-side via a shared schema (e.g., Zod schema used by both React and a Node.js API, or OpenAPI spec generating both client and server validators).

---

## 3. Menu Module Mapping

### HRMS_MENU.mmb (Menu Module)

| Oracle Forms Menu | React Equivalent |
|-------------------|-----------------|
| Default Menu Bar | `<AppBar>` with responsive navigation |
| File menu | Not needed (web apps don't have File menus) |
| Edit menu (Cut/Copy/Paste) | Native browser functionality |
| Query menu (Enter/Execute/Cancel) | Search bar + filter controls per page |
| Navigate menu (First/Prev/Next/Last) | `<Pagination>` or infinite scroll |
| Modules menu | `<Sidebar>` or `<Drawer>` navigation |
| Admin menu | Admin-only section in sidebar, guarded by `<ProtectedRoute>` |
| Help > About | `<Dialog>` triggered from user avatar menu |
| Menu-level security (`ENABLED`/`DISABLED`) | Role-based rendering: `{user.hasRole('ADMIN') && <MenuItem />}` |
| `PKG_SECURITY.has_permission()` check | Custom hook: `usePermission('MODULE', 'ACTION')` |

---

## 4. PL/SQL Package Mappings

### 4.1 PKG_COMMON -> Common Utility Services

| PL/SQL Component | Java Equivalent |
|-----------------|----------------|
| `PKG_COMMON` package | `CommonService.java` (Spring `@Service`) + `CommonUtils.java` utility class |
| `log_error()` | SLF4J Logger + centralized logging (ELK/CloudWatch) |
| `log_info()` | SLF4J Logger: `log.info(...)` |
| `get_param() / set_param()` | `SystemParameterService` backed by config table or Spring `@ConfigurationProperties` |
| `business_days_between()` | Java `TemporalAdjusters` or custom `BusinessDayCalculator` utility |
| `add_business_days()` | `BusinessDayCalculator.addBusinessDays(date, days)` |
| `get_fiscal_year()` | `FiscalYearService.getFiscalYear(date)` (configurable start month) |
| `get_fiscal_quarter()` | `FiscalYearService.getFiscalQuarter(date)` |
| `format_phone()` | `PhoneNumberFormatter` using `libphonenumber` (Google) |
| `format_ssn_masked()` | `SsnFormatter.mask(ssn)` -> `***-**-1234` |
| `format_currency()` | `NumberFormat.getCurrencyInstance(locale)` |
| `format_name()` | Simple string util or `NameFormatter` |
| `is_valid_email()` | Bean Validation `@Email` + `EmailValidator` |
| `is_valid_phone()` | `PhoneNumberUtil.isValidNumber()` (libphonenumber) |
| `is_valid_ssn()` | Custom `@ValidSsn` annotation + validator |
| `PRAGMA AUTONOMOUS_TRANSACTION` | Separate `@Transactional(propagation = REQUIRES_NEW)` or async event |

### 4.2 PKG_AUDIT -> Audit Infrastructure

| PL/SQL Component | Java Equivalent |
|-----------------|----------------|
| `PKG_AUDIT` package | Spring Data Envers (`@Audited`) or custom `AuditService` |
| `log_action()` | JPA `@EntityListeners(AuditListener.class)` or Hibernate Envers |
| `purge_old_records()` | Scheduled task: `@Scheduled(cron = "0 0 2 * * SUN")` |
| `get_change_history()` | `AuditRepository.findByEntityAndId()` returning audit trail |
| `AUDIT_LOG` table | JPA `AuditLog` entity or Envers `_AUD` tables |

### 4.3 PKG_SECURITY -> Security Layer

| PL/SQL Component | Java Equivalent |
|-----------------|----------------|
| `PKG_SECURITY` package | Spring Security configuration + `AuthService.java` |
| `authenticate()` | `AuthenticationManager.authenticate(UsernamePasswordAuthenticationToken)` |
| `logout()` | `SecurityContextHolder.clearContext()` + JWT blacklist/revocation |
| `is_session_valid()` | JWT validation filter: `JwtAuthenticationFilter` |
| `has_permission()` | `@PreAuthorize("hasRole('...')")` or `AccessDecisionManager` |
| `hash_password()` | `BCryptPasswordEncoder.encode()` (NOT MD5) |
| `encrypt_ssn() / decrypt_ssn()` | `Encryptors.text(password, salt)` (Spring Security Crypto) or AWS KMS |
| `change_password()` | `POST /api/auth/change-password` endpoint with `PasswordEncoder` |
| MD5 hashing | **Replace with BCrypt/Argon2** |
| Hard-coded encryption key | **Move to secret manager (AWS KMS, HashiCorp Vault, etc.)** |
| `USER_SESSIONS` table | JWT tokens (stateless) or Redis session store |

### 4.4 PKG_VALIDATION -> Validation Layer

| PL/SQL Component | Java Equivalent |
|-----------------|----------------|
| `PKG_VALIDATION` package | Bean Validation (JSR-380) annotations + custom validators |
| `validate_date_range()` | `@AssertTrue` on DTO method or custom `@ValidDateRange` |
| `validate_salary_for_grade()` | Custom `@ValidSalary` annotation + `SalaryValidator` |
| `validate_email_format()` | `@Email` (Hibernate Validator) |
| `validate_phone_format()` | Custom `@ValidPhone` annotation |
| `validate_emp_number_format()` | `@Pattern(regexp = "EMP-\\d{6}")` |
| `is_future_date()` | `@Future` or `@FutureOrPresent` annotation |
| `is_business_day()` | Custom validator with `BusinessDayCalculator` |
| `validate_required_fields()` | `@NotNull`, `@NotBlank` annotations on DTO fields |

### 4.5 PKG_NOTIFICATION -> Notification Service

| PL/SQL Component | Java Equivalent |
|-----------------|----------------|
| `PKG_NOTIFICATION` package | `NotificationService.java` + message broker (RabbitMQ/SQS) |
| `send_notification()` | `NotificationService.send(notification)` -> message queue |
| `process_queue()` | `@RabbitListener` or SQS consumer processing notifications |
| `retry_failed()` | Dead letter queue + retry policy (Spring Retry / `@Retryable`) |
| `cancel_notification()` | Queue message deletion or status update |
| `UTL_MAIL` (email sending) | `JavaMailSender` (Spring Mail) or SES/SendGrid |
| `NOTIFICATION_QUEUE` table | Message broker queue (RabbitMQ, AWS SQS) + persistence table |
| Hard-coded SMTP server | Externalized config: `spring.mail.host` in `application.yml` |
| HTML templates as string constants | Thymeleaf or Freemarker email templates |

### 4.6 PKG_EMPLOYEE -> Employee Service

| PL/SQL Component | Java Equivalent |
|-----------------|----------------|
| `PKG_EMPLOYEE` package | `EmployeeService.java` + `EmployeeController.java` |
| `create_employee()` | `POST /api/employees` -> `EmployeeService.create(dto)` |
| `update_employee()` | `PUT /api/employees/:id` -> `EmployeeService.update(id, dto)` |
| `get_employee()` | `GET /api/employees/:id` -> `EmployeeService.findById(id)` |
| `get_employee_by_number()` | `GET /api/employees?empNumber=EMP-000001` |
| `search_employees()` | `GET /api/employees?lastName=...&deptId=...` with Spring Data Specifications |
| `transfer_employee()` | `POST /api/employees/:id/transfer` |
| `promote_employee()` | `POST /api/employees/:id/promote` |
| `terminate_employee()` | `POST /api/employees/:id/terminate` |
| `rehire_employee()` | `POST /api/employees/:id/rehire` |
| `get_direct_reports()` | `GET /api/employees/:id/direct-reports` |
| `get_org_chart()` | `GET /api/employees/:id/org-chart` (paginated, with depth limit) |
| `get_headcount_by_dept()` | `GET /api/reports/headcount?deptId=...&asOf=...` |
| `get_tenure_years()` | Computed field on Employee DTO |
| `is_active() / emp_exists()` | `EmployeeRepository.existsByIdAndStatus(id, ACTIVE)` |
| `generate_emp_number()` | `EmployeeNumberGenerator` using DB sequence (not MAX+1) |
| `set_session_context()` | Spring Security `SecurityContext` (automatic) |
| `g_current_user` global | `SecurityContextHolder.getContext().getAuthentication()` |
| Dynamic SQL in `search_employees()` | Spring Data JPA `Specification<Employee>` (type-safe, no SQL injection) |

### 4.7 PKG_PAYROLL -> Payroll Service

| PL/SQL Component | Java Equivalent |
|-----------------|----------------|
| `PKG_PAYROLL` package | `PayrollService.java` + `TaxCalculationService.java` + `PayrollController.java` |
| `create_salary_record()` | `POST /api/employees/:id/salary-records` |
| `get_current_salary()` | `GET /api/employees/:id/current-salary` |
| `create_pay_periods()` | `POST /api/payroll/periods/generate` |
| `close_pay_period()` | `POST /api/payroll/periods/:id/close` |
| `create_payroll_run()` | `POST /api/payroll/runs` |
| `calculate_payroll()` | `POST /api/payroll/runs/:id/calculate` (async with progress via WebSocket/SSE) |
| `calculate_employee_pay()` | Internal service method, batch-processed via Spring Batch |
| `approve_payroll()` | `POST /api/payroll/runs/:id/approve` |
| `reverse_payroll()` | `POST /api/payroll/runs/:id/reverse` |
| `calculate_federal_tax()` | `TaxCalculationService.calculateFederalTax()` using configurable brackets from DB |
| `calculate_state_tax()` | `TaxCalculationService.calculateStateTax()` using configurable brackets |
| `calculate_fica()` | `TaxCalculationService.calculateFica()` with configurable wage base |
| `calculate_medicare()` | `TaxCalculationService.calculateMedicare()` |
| `get_payslip()` | `GET /api/payroll/runs/:runId/payslips?empId=...` |
| `get_ytd_earnings()` | `GET /api/employees/:id/ytd-earnings?year=...` |
| `generate_pay_register()` | `GET /api/payroll/runs/:id/register` (PDF/CSV export) |
| Cursor-loop processing | Spring Batch `ItemReader` / `ItemProcessor` / `ItemWriter` |
| Hard-coded tax constants | Configurable `TaxBracket` entity loaded from DB + annual refresh |
| Partial commits every 50 rows | Spring Batch chunk-oriented processing with configurable commit interval |

### 4.8 PKG_LEAVE -> Leave Service

| PL/SQL Component | Java Equivalent |
|-----------------|----------------|
| `PKG_LEAVE` package | `LeaveService.java` + `LeaveController.java` |
| `submit_leave_request()` | `POST /api/leave/requests` |
| `approve_leave_request()` | `POST /api/leave/requests/:id/approve` |
| `reject_leave_request()` | `POST /api/leave/requests/:id/reject` |
| `cancel_leave_request()` | `POST /api/leave/requests/:id/cancel` |
| `get_leave_balance()` | `GET /api/leave/balances?empId=...&typeId=...&year=...` |
| `adjust_leave_balance()` | `POST /api/leave/balances/adjust` |
| `initialize_balances()` | Scheduled task or on-demand: `POST /api/leave/balances/initialize` |
| `run_monthly_accrual()` | Spring `@Scheduled` batch job: `LeaveAccrualJob` |
| `process_carryover()` | Scheduled task: `LeaveCarryoverJob` |
| `expire_carryover()` | Scheduled task (idempotent implementation to fix double-expiry bug) |
| `get_pending_requests()` | `GET /api/leave/requests?approver=...&status=PENDING` |
| `get_team_calendar()` | `GET /api/leave/team-calendar?managerId=...&start=...&end=...` |
| `calculate_business_days()` | `BusinessDayCalculator.calculate(start, end, locationCode)` |
| `check_leave_overlap()` | Validation in `LeaveService` before persisting |

### 4.9 PKG_PERFORMANCE -> Performance Service

| PL/SQL Component | Java Equivalent |
|-----------------|----------------|
| `PKG_PERFORMANCE` package | `PerformanceService.java` + `PerformanceController.java` |
| `create_review_cycle()` | `POST /api/performance/cycles` |
| `open_review_cycle()` | `POST /api/performance/cycles/:id/open` |
| `close_review_cycle()` | `POST /api/performance/cycles/:id/close` |
| `create_review()` | `POST /api/performance/reviews` |
| `submit_self_assessment()` | `PUT /api/performance/reviews/:id/self-assessment` |
| `submit_manager_review()` | `PUT /api/performance/reviews/:id/manager-review` |
| `acknowledge_review()` | `POST /api/performance/reviews/:id/acknowledge` |
| `add_goal()` | `POST /api/performance/reviews/:reviewId/goals` |
| `update_goal_progress()` | `PUT /api/performance/goals/:id/progress` |
| `get_team_reviews()` | `GET /api/performance/reviews?managerId=...&cycleId=...` |
| `get_rating_distribution()` | `GET /api/performance/cycles/:id/rating-distribution` |
| `generate_reviews_for_cycle()` | `POST /api/performance/cycles/:id/generate-reviews` (batch) |

### 4.10 PKG_REPORTING -> Reporting Service

| PL/SQL Component | Java Equivalent |
|-----------------|----------------|
| `PKG_REPORTING` package | `ReportService.java` + `ReportController.java` or BI tool |
| `headcount_report()` | `GET /api/reports/headcount` |
| `compensation_summary()` | `GET /api/reports/compensation` |
| `turnover_report()` | `GET /api/reports/turnover` |
| `new_hires_report()` | `GET /api/reports/new-hires` |
| `leave_utilization_report()` | `GET /api/reports/leave-utilization` |
| `payroll_summary_report()` | `GET /api/reports/payroll-summary` |
| `eeo_compliance_report()` | `GET /api/reports/eeo-compliance` |
| `refresh_reporting_tables()` | Materialized view refresh or ETL pipeline (configurable schedule) |
| Oracle Reports (.rdf) | JasperReports, Apache POI (Excel), or React data visualization |
| Denormalized reporting tables | Materialized views, CQRS read models, or BI tool cache |

### 4.11 PKG_INTEGRATION -> Integration Service

| PL/SQL Component | Java Equivalent |
|-----------------|----------------|
| `PKG_INTEGRATION` package | `IntegrationService.java` + Spring Integration / Apache Camel |
| `generate_gl_journal()` | REST API call to ERP/GL system or message queue publication |
| `export_benefits_feed()` | REST API to benefits provider (replace ADP flat file) |
| `import_time_attendance()` | REST API consumer or file watcher with Spring Integration |
| `sync_org_structure()` | Scheduled sync via API (replace UTL_FILE flat files) |
| `get_integration_status()` | Health check endpoint: `GET /api/integrations/:name/status` |
| `UTL_FILE` operations | `java.nio.file` or cloud storage SDK (S3) for any remaining file needs |
| FTP with cleartext credentials | SFTP with key-based auth or API-based transfer |

---

## 5. Database Object Mappings

### 5.1 Tables -> JPA Entities

| Oracle Table | JPA Entity | Notes |
|-------------|-----------|-------|
| DEPARTMENTS | `Department.java` | `@Entity` with self-referencing `@ManyToOne` for `parentDept` |
| LOCATIONS | `Location.java` | `@Entity` with `@Id` on `locationCode` (natural key) |
| JOB_GRADES | `JobGrade.java` | `@Entity` with salary range validation |
| JOB_TITLES | `JobTitle.java` | `@ManyToOne` to `JobGrade` |
| EMPLOYEES | `Employee.java` | Central entity; `@ManyToOne` to Department, JobTitle, self-ref Manager |
| EMPLOYEE_HISTORY | `EmployeeHistory.java` | `@ManyToOne` to Employee |
| EMPLOYEE_DEPENDENTS | `EmployeeDependent.java` | `@ManyToOne` to Employee |
| EMERGENCY_CONTACTS | `EmergencyContact.java` | `@ManyToOne` to Employee |
| SALARY_RECORDS | `SalaryRecord.java` | `@ManyToOne` to Employee; effective-dated |
| PAY_ELEMENTS | `PayElement.java` | Reference entity |
| EMPLOYEE_PAY_ELEMENTS | `EmployeePayElement.java` | `@ManyToOne` to Employee + PayElement |
| PAY_PERIODS | `PayPeriod.java` | `@Entity` with status workflow |
| PAYROLL_RUNS | `PayrollRun.java` | `@ManyToOne` to PayPeriod |
| PAYROLL_DETAILS | `PayrollDetail.java` | `@ManyToOne` to PayrollRun + Employee |
| TAX_BRACKETS | `TaxBracket.java` | Configurable tax table (no more hard-coding) |
| EMPLOYEE_TAX_INFO | `EmployeeTaxInfo.java` | `@ManyToOne` to Employee; year-specific |
| EMPLOYEE_BANK_ACCOUNTS | `EmployeeBankAccount.java` | Encrypted account numbers; `@ManyToOne` to Employee |
| LEAVE_TYPES | `LeaveType.java` | Reference entity with accrual configuration |
| LEAVE_BALANCES | `LeaveBalance.java` | Composite unique: Employee + LeaveType + Year |
| LEAVE_REQUESTS | `LeaveRequest.java` | `@ManyToOne` to Employee + LeaveType |
| LEAVE_ACCRUAL_LOG | `LeaveAccrualLog.java` | Audit trail for accruals |
| HOLIDAYS | `Holiday.java` | Location-specific holidays |
| REVIEW_CYCLES | `ReviewCycle.java` | Performance review periods |
| PERFORMANCE_REVIEWS | `PerformanceReview.java` | `@ManyToOne` to ReviewCycle + Employee (reviewed) + Employee (reviewer) |
| PERFORMANCE_GOALS | `PerformanceGoal.java` | `@ManyToOne` to PerformanceReview + Employee |
| AUDIT_LOG | `AuditLog.java` | Cross-cutting; or use Hibernate Envers `_AUD` tables |
| SYSTEM_PARAMETERS | `SystemParameter.java` | Config table; may move to Spring Cloud Config |
| NOTIFICATION_QUEUE | N/A (use message broker) | Replace table-based queue with RabbitMQ/SQS |
| USER_SESSIONS | N/A (use JWT) | Stateless auth eliminates session table |
| LOOKUP_VALUES | `LookupValue.java` | Generic reference data; or split into typed enums |

### 5.2 Sequences -> ID Generation

| Oracle Sequence | Java Equivalent |
|----------------|----------------|
| `SEQ_EMPLOYEE` (and all `SEQ_*`) | JPA `@GeneratedValue(strategy = GenerationType.SEQUENCE)` with `@SequenceGenerator` (if staying on Oracle) or `GenerationType.IDENTITY` (PostgreSQL) |
| `SEQ_EMP_NUMBER` | Custom `EmployeeNumberGenerator` using atomic DB operation |
| `SEQ_AUDIT` (CACHE 100) | Separate sequence with caching for high-throughput audit table |

### 5.3 Views -> Queries/Projections

| Oracle View | Java Equivalent |
|-------------|----------------|
| `VW_ACTIVE_EMPLOYEES` | JPA `@Query` or Spring Data Projection interface; or JPQL named query |
| `VW_ORG_HIERARCHY` | Recursive CTE query in repository (with pagination) |
| `VW_EMPLOYEE_COMPENSATION` | DTO projection: `CompensationSummaryDto` |
| `VW_LEAVE_SUMMARY` | DTO projection: `LeaveBalanceSummaryDto` |
| `VW_PAYROLL_LATEST` | DTO projection: `LatestPayrollDto` |
| `VW_PENDING_APPROVALS` | UNION query across modules or separate API calls aggregated in UI |

### 5.4 Database Triggers -> JPA Lifecycle

| Oracle Trigger | Java Equivalent |
|---------------|----------------|
| `TRG_EMPLOYEES_BIR` (BEFORE INSERT) | `@PrePersist` callback or `@EntityListeners` |
| `TRG_EMPLOYEES_BUR` (BEFORE UPDATE) | `@PreUpdate` callback |
| `TRG_EMP_INSTEAD_OF_DELETE` (soft delete) | `@SQLDelete(sql = "UPDATE employees SET active_flag = 'N' WHERE ...")` + `@Where(clause = "active_flag = 'Y'")` (Hibernate) |
| `TRG_AUDIT_*` triggers | Hibernate Envers `@Audited` or Spring AOP `@AfterReturning` |

---

## 6. Forms Built-in Mappings

| Oracle Forms Built-in | Java/React Equivalent |
|----------------------|----------------------|
| `OPEN_FORM(name, ACTIVATE, SESSION)` | `navigate('/route')` (React Router) |
| `CLOSE_FORM(name)` | `navigate(-1)` or `navigate('/dashboard')` |
| `EXIT_FORM` | `navigate('/login')` + `logout()` |
| `COMMIT_FORM` | Form submit handler -> API call (POST/PUT) |
| `CLEAR_FORM` | `form.reset()` |
| `EXECUTE_QUERY` | `queryClient.invalidateQueries()` or `refetch()` |
| `GO_BLOCK(block_name)` | Focus management or tab switching |
| `GO_ITEM(item_name)` | `ref.current.focus()` or `setFieldFocus('fieldName')` |
| `MESSAGE(text)` | `toast.info(text)` (react-toastify) or `<Snackbar>` |
| `RAISE FORM_TRIGGER_FAILURE` | `throw new ValidationError()` or `setError('field', ...)` |
| `:SYSTEM.TRIGGER_ITEM` | Event target: `e.target.name` |
| `:SYSTEM.BLOCK_STATUS` | Form dirty state: `form.formState.isDirty` |
| `:SYSTEM.RECORD_STATUS` | Record state tracking in React state/context |
| `SET_ITEM_PROPERTY(item, VISIBLE)` | Conditional rendering: `{condition && <Component />}` |
| `SET_ITEM_PROPERTY(item, ENABLED)` | `disabled={!condition}` prop |
| `SET_ITEM_PROPERTY(item, REQUIRED)` | `required` prop + validation schema |
| `SET_ITEM_PROPERTY(item, UPDATE_ALLOWED)` | `readOnly={!canEdit}` prop |
| `GET_APPLICATION_PROPERTY(...)` | Environment variables or app config |
| `NAME_IN('GLOBAL.var')` | React Context or global state (Zustand/Redux) |
| `COPY('value', 'GLOBAL.var')` | Context setter: `setGlobalState({ var: value })` |
| `LIST_VALUES` (invoke LOV) | Open `<Autocomplete>` dropdown programmatically |
| `DO_KEY('COMMIT_FORM')` | Programmatic form submission: `form.handleSubmit()` |
| `FIRST_RECORD / LAST_RECORD / NEXT_RECORD / PREVIOUS_RECORD` | Pagination or row navigation in data grid |
| `SHOW_LOV(lov_name)` | Open modal/dialog with searchable list |
| `CLEAR_RECORD` | Remove row from local state array |
| `DELETE_RECORD` | Remove row + mark for deletion on save |
| `CREATE_RECORD` | Add empty row to local state array |
| `SET_MENU_ITEM_PROPERTY` | Conditional rendering of menu items |

---

## 7. Trigger Type Mappings

| Oracle Forms Trigger | When It Fires | React/Java Equivalent |
|---------------------|---------------|----------------------|
| `WHEN-NEW-FORM-INSTANCE` | Form opens | `useEffect(() => { ... }, [])` in page component |
| `WHEN-NEW-BLOCK-INSTANCE` | Block gains focus | `useEffect` when tab/section becomes active |
| `WHEN-NEW-RECORD-INSTANCE` | Record navigation | `onRowClick` or `onSelectionChange` handler |
| `WHEN-NEW-ITEM-INSTANCE` | Field gains focus | `onFocus` event handler |
| `WHEN-VALIDATE-ITEM` | Field loses focus, value changed | `onBlur` + validation: `register('field', { validate: fn })` |
| `WHEN-VALIDATE-RECORD` | Record validation | `onSubmit` form-level validation (cross-field) |
| `WHEN-BUTTON-PRESSED` | Button click | `onClick` event handler |
| `WHEN-CHECKBOX-CHANGED` | Checkbox toggled | `onChange` handler for checkbox |
| `WHEN-LIST-CHANGED` | Dropdown selection | `onChange` handler for select/autocomplete |
| `WHEN-TIMER-EXPIRED` | Timer event | `setInterval()` or `setTimeout()` |
| `PRE-FORM` | Before form displayed | Page component initialization (constructor/init) |
| `POST-FORM` | Form about to close | `useEffect` cleanup or `beforeunload` handler |
| `PRE-BLOCK` | Before block queried | `onBeforeQuery` / setup before API call |
| `POST-BLOCK` | After block populated | `onSuccess` callback in React Query |
| `PRE-QUERY` | Before query executes | Transform query parameters before API call |
| `POST-QUERY` | After each record fetched | Data transformation in React Query `select` option |
| `PRE-INSERT` | Before INSERT | `@PrePersist` (JPA) or pre-save hook in service |
| `PRE-UPDATE` | Before UPDATE | `@PreUpdate` (JPA) or pre-save hook in service |
| `PRE-DELETE` | Before DELETE | Pre-delete validation in service layer |
| `POST-INSERT` | After INSERT | `@PostPersist` (JPA) or `onSuccess` in mutation |
| `POST-UPDATE` | After UPDATE | `@PostUpdate` (JPA) or `onSuccess` in mutation |
| `POST-DELETE` | After DELETE | `@PostRemove` (JPA) or `onSuccess` in mutation |
| `ON-ERROR` | Error occurs | `ErrorBoundary` (React) + global Axios error interceptor |
| `ON-MESSAGE` | Message displayed | Toast notification system |
| `ON-CHECK-DELETE-MASTER` | Master record delete with details | Cascade configuration in JPA `@OneToMany(cascade = ...)` |
| `ON-POPULATE-DETAILS` | Master record changes | Dependent query: `useQuery(['details', masterId], { enabled: !!masterId })` |
| `KEY-*` triggers | Keyboard shortcuts | `useHotkeys('ctrl+s', handleSave)` (react-hotkeys-hook) |
