CREATE OR REPLACE PACKAGE HRMS.UT_PKG_PERFORMANCE AS
-- ============================================================================
-- UT_PKG_PERFORMANCE - Unit Tests for PKG_PERFORMANCE
-- Framework: utPLSQL v3
-- Coverage target: >80% of PKG_PERFORMANCE body
-- ============================================================================

    --%suite(PKG_PERFORMANCE - Performance Review Management Package)
    --%suitepath(hrms.performance)

    --%beforeall
    PROCEDURE setup_test_data;

    --%afterall
    PROCEDURE teardown_test_data;

    --%test(create_review_cycle creates a new cycle record)
    PROCEDURE test_create_cycle_basic;

    --%test(create_review_cycle validates date range)
    PROCEDURE test_create_cycle_bad_dates;

    --%test(open_review_cycle sets cycle status to OPEN)
    PROCEDURE test_open_cycle;

    --%test(open_review_cycle raises error for already open cycle)
    PROCEDURE test_open_cycle_already_open;

    --%test(close_review_cycle sets cycle status to CLOSED)
    PROCEDURE test_close_cycle;

    --%test(create_review creates a review for employee in cycle)
    PROCEDURE test_create_review;

    --%test(create_review raises error for non-existent cycle)
    PROCEDURE test_create_review_bad_cycle;

    --%test(submit_self_assessment records employee self-review)
    PROCEDURE test_self_assessment;

    --%test(submit_manager_review records manager rating and comments)
    PROCEDURE test_manager_review;

    --%test(submit_manager_review validates rating is between 1 and 5)
    PROCEDURE test_manager_review_bad_rating;

    --%test(acknowledge_review marks review as acknowledged by employee)
    PROCEDURE test_acknowledge_review;

    --%test(add_goal creates a goal linked to review)
    PROCEDURE test_add_goal;

    --%test(add_goal validates weight percentage)
    PROCEDURE test_add_goal_bad_weight;

    --%test(update_goal_progress sets progress percentage)
    PROCEDURE test_update_goal_progress;

    --%test(update_goal_progress validates progress 0-100)
    PROCEDURE test_update_goal_bad_progress;

    --%test(get_team_reviews returns cursor for manager team)
    PROCEDURE test_get_team_reviews;

    --%test(get_rating_distribution returns distribution by department)
    PROCEDURE test_rating_distribution;

    --%test(generate_reviews_for_cycle creates reviews for all active employees)
    PROCEDURE test_generate_reviews;

END UT_PKG_PERFORMANCE;
/
