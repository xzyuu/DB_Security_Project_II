


/* =====================================================================
    LAB_RESULT PROCEDURE
   ===================================================================== */

CREATE OR REPLACE PROCEDURE PROJ_TWO.INSERT_LAB_RESULT (
    p_order_id     IN NUMBER,
    p_result_value IN PROJ_TWO.LAB_RESULT.RESULT_VALUE%TYPE,
    p_result_date  IN DATE
)
AUTHID DEFINER
AS
    v_department_id NUMBER;
    v_c_label       NUMBER;
    v_r_label       NUMBER;
    v_result_id     NUMBER;
BEGIN
    -- Verify technician belongs to the order's department.
    SELECT lo.department_id
    INTO v_department_id
    FROM PROJ_TWO.LAB_ORDER lo
    JOIN PROJ_TWO.STAFF s
        ON s.department_id = lo.department_id
    WHERE lo.order_id = p_order_id
      AND UPPER(s.oracle_username) =
          SYS_CONTEXT('USERENV', 'SESSION_USER')
      AND s.role = 'ROLE_LAB_TECH_P2'
      AND lo.department_id IN (23, 24);

    -- Assign department-specific C and R labels.
    IF v_department_id = 23 THEN
        v_c_label := 3001;
        v_r_label := 3003;
    ELSE
        v_c_label := 3002;
        v_r_label := 3004;
    END IF;

    SAVEPOINT before_lab_result;

    -- Insert a Pending result at C level.
    INSERT INTO PROJ_TWO.LAB_RESULT (
        ORDER_ID, RESULT_VALUE, RESULT_DATE,
        STATUS, RELEASED_FLAG, OLS_LABEL
    )
    VALUES (
        p_order_id, p_result_value, p_result_date,
        'Pending', 0, v_c_label
    )
    RETURNING RESULT_ID INTO v_result_id;

    -- Upgrade the unreleased result from C to R.
    UPDATE PROJ_TWO.LAB_RESULT
    SET OLS_LABEL = v_r_label
    WHERE RESULT_ID = v_result_id;

    IF SQL%ROWCOUNT <> 1 THEN
        RAISE_APPLICATION_ERROR(
            -20002, 'Failed to classify result'
        );
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(
            -20001, 'Unauthorized laboratory order'
        );

    WHEN OTHERS THEN
        ROLLBACK TO before_lab_result;
        RAISE;
END;
/

BEGIN
    SA_USER_ADMIN.SET_PROG_PRIVS(
        policy_name       => 'HOSPITAL_POL',
        schema_name       => 'PROJ_TWO',
        program_unit_name => 'INSERT_LAB_RESULT',
        privileges        => 'WRITEUP'
    );
END;
/

GRANT EXECUTE ON PROJ_TWO.INSERT_LAB_RESULT TO ROLE_LAB_TECH_P2; 



/* =====================================================================
    RELEASE_LAB_RESULT PROCEDURE
   ===================================================================== */
CREATE OR REPLACE PROCEDURE PROJ_TWO.RELEASE_LAB_RESULT (
    p_result_id IN NUMBER
)
AUTHID DEFINER
AS
    v_department_id NUMBER;
    v_r_label NUMBER;
    v_c_label NUMBER;
BEGIN
    -- Verify the session user is a laboratory supervisor.
    SELECT department_id
    INTO v_department_id
    FROM PROJ_TWO.STAFF
    WHERE UPPER(oracle_username) =
          SYS_CONTEXT('USERENV', 'SESSION_USER')
      AND role = 'ROLE_LAB_TECH_P2'
      AND is_supervisor = 'Y'
      AND department_id IN (23, 24);

    -- Determine department-specific labels.
    IF v_department_id = 23 THEN
        v_r_label := 3003;
        v_c_label := 3001;
    ELSE
        v_r_label := 3004;
        v_c_label := 3002;
    END IF;

    -- Release only Final/Amended results in the supervisor's department.
    UPDATE PROJ_TWO.LAB_RESULT lr
    SET released_flag = 1,
        OLS_LABEL = v_c_label
    WHERE lr.result_id = p_result_id
      AND lr.released_flag = 0
      AND lr.OLS_LABEL = v_r_label
      AND lr.status IN ('Final', 'Amended')
      AND EXISTS (
          SELECT 1
          FROM PROJ_TWO.LAB_ORDER lo
          WHERE lo.order_id = lr.order_id
            AND lo.department_id = v_department_id
      );

    -- Report when no eligible record was released.
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(
            -20002, 'Result cannot be released'
        );
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(
            -20001, 'Unauthorized supervisor'
        );
END;
/

BEGIN
    SA_USER_ADMIN.SET_PROG_PRIVS(
        policy_name       => 'HOSPITAL_POL',
        schema_name       => 'PROJ_TWO',
        program_unit_name => 'RELEASE_LAB_RESULT',
        privileges        => 'WRITEDOWN'
    );
END;
/
-- Only the two supervisors can execute RELEASE.
GRANT EXECUTE ON PROJ_TWO.RELEASE_LAB_RESULT TO USER_LAB_TECH1_P2;
GRANT EXECUTE ON PROJ_TWO.RELEASE_LAB_RESULT TO USER_LAB_TECH3_P2;