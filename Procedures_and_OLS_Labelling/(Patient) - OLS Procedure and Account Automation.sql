--Step 1
GRANT CREATE TABLE, CREATE PROCEDURE, CREATE SEQUENCE, CREATE JOB
TO PROJ_TWO;

GRANT HOSPITAL_POL_DBA TO PROJ_TWO WITH DELEGATE OPTION;

GRANT EXECUTE ON LBACSYS.SA_COMPONENTS TO PROJ_TWO;
GRANT EXECUTE ON LBACSYS.SA_LABEL_ADMIN TO PROJ_TWO;
GRANT EXECUTE ON LBACSYS.SA_USER_ADMIN TO PROJ_TWO;

--Step 2
GRANT CREATE SESSION TO ROLE_PATIENT_P2;

GRANT ROLE_PATIENT_P2 TO SYSTEM WITH ADMIN OPTION;


CREATE ROLE ROLE_P2_ACCOUNT_CREATE;

GRANT CREATE USER TO ROLE_P2_ACCOUNT_CREATE;


CREATE ROLE ROLE_P2_OLS_LOOKUP;

GRANT SELECT_CATALOG_ROLE TO ROLE_P2_OLS_LOOKUP;

--Step 3
  CREATE OR REPLACE NONEDITIONABLE PROCEDURE "SYSTEM"."P2_CREATE_PATIENT_ACCOUNT" (
    p_username IN VARCHAR2
)
AUTHID DEFINER
AS
    PRAGMA AUTONOMOUS_TRANSACTION;

    v_username VARCHAR2(128);
    v_password VARCHAR2(128);
    v_count    PLS_INTEGER;
BEGIN
    IF SYS_CONTEXT('USERENV', 'SESSION_USER') NOT IN (
        'SYSTEM',
        'PROJ_TWO',
        'USER_RECEPTIONIST1_P2',
        'USER_RECEPTIONIST2_P2'
    ) THEN
        RAISE_APPLICATION_ERROR(
            -20001,
            'Unauthorised caller.'
        );
    END IF;

    v_username := UPPER(TRIM(p_username));

    IF v_username IS NULL
       OR LENGTH(v_username) > 30
       OR NOT REGEXP_LIKE(
           v_username,
           '^USER_PATIENT[1-9][0-9]*_P2$',
           'c'
       )
    THEN
        RAISE_APPLICATION_ERROR(
            -20002,
            'Use USER_PATIENT<n>_P2, without a leading zero.'
        );
    END IF;

    SELECT COUNT(*)
    INTO v_count
    FROM ALL_USERS
    WHERE USERNAME = v_username;

    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(
            -20003,
            'Account already exists. No password or permissions changed.'
        );
    END IF;

    v_password := REPLACE(v_username, '_', '');

    -- Concatenation is limited to the strictly validated username.
    EXECUTE IMMEDIATE
        'CREATE USER "' || v_username ||
        '" IDENTIFIED BY "' || v_password ||
        '" ACCOUNT UNLOCK';

    EXECUTE IMMEDIATE
        'GRANT ROLE_PATIENT_P2 TO "' || v_username || '"';

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;

        -- CREATE USER cannot be undone by this rollback.
        -- No account is locked or deleted here.
        RAISE;
END;

--Step 4
GRANT ROLE_P2_ACCOUNT_CREATE
TO PROCEDURE SYSTEM.P2_CREATE_PATIENT_ACCOUNT;

GRANT EXECUTE ON SYSTEM.P2_CREATE_PATIENT_ACCOUNT
TO PROJ_TWO;

--Step 5
  CREATE OR REPLACE NONEDITIONABLE PROCEDURE "SYSTEM"."P2_CREATE_PATIENT_ACCOUNT" (
    p_username IN VARCHAR2
)
AUTHID DEFINER
AS
    PRAGMA AUTONOMOUS_TRANSACTION;

    v_username VARCHAR2(128);
    v_password VARCHAR2(128);
    v_count    PLS_INTEGER;
BEGIN
    IF SYS_CONTEXT('USERENV', 'SESSION_USER') NOT IN (
        'SYSTEM',
        'PROJ_TWO',
        'USER_RECEPTIONIST1_P2',
        'USER_RECEPTIONIST2_P2'
    ) THEN
        RAISE_APPLICATION_ERROR(
            -20001,
            'Unauthorised caller.'
        );
    END IF;

    v_username := UPPER(TRIM(p_username));

    IF v_username IS NULL
       OR LENGTH(v_username) > 30
       OR NOT REGEXP_LIKE(
           v_username,
           '^USER_PATIENT[1-9][0-9]*_P2$',
           'c'
       )
    THEN
        RAISE_APPLICATION_ERROR(
            -20002,
            'Use USER_PATIENT<n>_P2, without a leading zero.'
        );
    END IF;

    SELECT COUNT(*)
    INTO v_count
    FROM ALL_USERS
    WHERE USERNAME = v_username;

    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(
            -20003,
            'Account already exists. No password or permissions changed.'
        );
    END IF;

    v_password := REPLACE(v_username, '_', '');

    -- Concatenation is limited to the strictly validated username.
    EXECUTE IMMEDIATE
        'CREATE USER "' || v_username ||
        '" IDENTIFIED BY "' || v_password ||
        '" ACCOUNT UNLOCK';

    EXECUTE IMMEDIATE
        'GRANT ROLE_PATIENT_P2 TO "' || v_username || '"';

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;

        -- CREATE USER cannot be undone by this rollback.
        -- No account is locked or deleted here.
        RAISE;
END;



  CREATE OR REPLACE NONEDITIONABLE FUNCTION "SYSTEM"."P2_OLS_EXISTS" (
    p_lookup_type IN VARCHAR2,
    p_value       IN VARCHAR2
)
RETURN NUMBER
AUTHID DEFINER
AS
    v_count  NUMBER;
    v_number NUMBER;
BEGIN
    CASE UPPER(TRIM(p_lookup_type))

        WHEN 'GROUP_NAME' THEN
            EXECUTE IMMEDIATE
                'SELECT COUNT(*)
                 FROM DBA_SA_GROUPS
                 WHERE POLICY_NAME = :policy
                   AND SHORT_NAME = :group_name'
            INTO v_count
            USING 'HOSPITAL_POL', UPPER(TRIM(p_value));

        WHEN 'GROUP_NUMBER' THEN
            v_number := TO_NUMBER(p_value);

            EXECUTE IMMEDIATE
                'SELECT COUNT(*)
                 FROM DBA_SA_GROUPS
                 WHERE POLICY_NAME = :policy
                   AND GROUP_NUM = :group_num'
            INTO v_count
            USING 'HOSPITAL_POL', v_number;

        WHEN 'LABEL_TAG' THEN
            v_number := TO_NUMBER(p_value);

            EXECUTE IMMEDIATE
                'SELECT COUNT(*)
                 FROM DBA_SA_LABELS
                 WHERE POLICY_NAME = :policy
                   AND LABEL_TAG = :label_tag'
            INTO v_count
            USING 'HOSPITAL_POL', v_number;

        ELSE
            RAISE_APPLICATION_ERROR(
                -20030,
                'Invalid OLS lookup type.'
            );
    END CASE;

    RETURN v_count;
END;

--Step 6
GRANT ROLE_P2_OLS_LOOKUP
TO FUNCTION SYSTEM.P2_OLS_EXISTS;

GRANT EXECUTE ON SYSTEM.P2_OLS_EXISTS
TO PROJ_TWO;

--Step 7
CREATE SEQUENCE PROJ_TWO.P2_PATIENT_GROUP_SEQ
    START WITH 1000
    INCREMENT BY 1
    MAXVALUE 9999
    NOCYCLE
    NOCACHE;


CREATE SEQUENCE PROJ_TWO.P2_PATIENT_LABEL_SEQ
    START WITH 1000
    INCREMENT BY 1
    MAXVALUE 1099
    NOCYCLE
    NOCACHE;

--Step 8
CREATE TABLE PROJ_TWO.P2_PATIENT_REG_REQUEST (
    REQUEST_ID NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    ORACLE_USERNAME VARCHAR2(30 BYTE) NOT NULL UNIQUE,
    PATIENT_NAME VARCHAR2(100 BYTE) NOT NULL,
    DOB DATE NOT NULL,
    PHONE VARCHAR2(30 BYTE),

    SENSITIVITY VARCHAR2(1 BYTE) NOT NULL
        CHECK (SENSITIVITY IN ('C', 'R')),

    REQUESTED_BY VARCHAR2(128 BYTE) NOT NULL,
    REQUEST_SESSION_LABEL VARCHAR2(4000 BYTE) NOT NULL,

    ALLOW_EXISTING_SETUP CHAR(1 BYTE) DEFAULT 'N' NOT NULL
        CHECK (ALLOW_EXISTING_SETUP IN ('N', 'Y')),

    STATUS VARCHAR2(12 BYTE) DEFAULT 'QUEUED' NOT NULL
        CHECK (
            STATUS IN (
                'QUEUED',
                'PROCESSING',
                'READY',
                'COMPLETE',
                'FAILED'
            )
        ),

    GROUP_NUM NUMBER,
    LABEL_TAG NUMBER,
    ROW_LABEL VARCHAR2(4000 BYTE),
    PATIENT_ID NUMBER,

    STAGE VARCHAR2(100 BYTE),
    ERROR_TEXT VARCHAR2(2000 BYTE),

    CREATED_AT TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    UPDATED_AT TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL
);

--Step 9
CREATE OR REPLACE PROCEDURE PROJ_TWO.P2_PATIENT_OLS_WORKER
AUTHID CURRENT_USER
AS
    v_req PROJ_TWO.P2_PATIENT_REG_REQUEST%ROWTYPE;

    v_count NUMBER;
    v_suffix VARCHAR2(30);
    v_group_name VARCHAR2(30);
    v_group_num NUMBER;
    v_label_tag NUMBER;
    v_row_label VARCHAR2(4000);
    v_read_label VARCHAR2(4000);
    v_stage VARCHAR2(100);
    v_error VARCHAR2(2000);
BEGIN
    IF SYS_CONTEXT('USERENV', 'SESSION_USER') <> 'PROJ_TWO'
       OR SYS_CONTEXT('USERENV', 'CURRENT_USER') <> 'PROJ_TWO'
    THEN
        RAISE_APPLICATION_ERROR(
            -20050,
            'Private PROJ_TWO worker.'
        );
    END IF;

    FOR item IN (
        SELECT request_id
        FROM PROJ_TWO.P2_PATIENT_REG_REQUEST
        WHERE status = 'QUEUED'
        ORDER BY request_id
        FETCH FIRST 20 ROWS ONLY
    ) LOOP
        -- Claim the request before operations that can commit independently.
        UPDATE PROJ_TWO.P2_PATIENT_REG_REQUEST
        SET status = 'PROCESSING',
            stage = 'validating request',
            updated_at = SYSTIMESTAMP,
            error_text = NULL
        WHERE request_id = item.request_id
          AND status = 'QUEUED';

        IF SQL%ROWCOUNT = 0 THEN
            CONTINUE;
        END IF;

        COMMIT;

        BEGIN
            SELECT *
            INTO v_req
            FROM PROJ_TWO.P2_PATIENT_REG_REQUEST
            WHERE request_id = item.request_id;

            v_stage := 'validating request';

            IF NOT REGEXP_LIKE(
                    v_req.oracle_username,
                    '^USER_PATIENT[1-9][0-9]*_P2$',
                    'c'
               )
               OR v_req.requested_by NOT IN (
                    'USER_RECEPTIONIST1_P2',
                    'USER_RECEPTIONIST2_P2'
               )
            THEN
                RAISE_APPLICATION_ERROR(
                    -20051,
                    'Invalid registration request.'
                );
            END IF;

            IF v_req.sensitivity = 'R'
               AND (
                    v_req.requested_by <> 'USER_RECEPTIONIST1_P2'
                    OR NVL(
                        REGEXP_SUBSTR(
                            v_req.request_session_label,
                            '^[^:]+'
                        ),
                        '?'
                    ) <> 'R'
               )
            THEN
                RAISE_APPLICATION_ERROR(
                    -20052,
                    'VIP registration requires the R supervisor.'
                );
            END IF;

            v_suffix := REGEXP_SUBSTR(
                v_req.oracle_username,
                '[0-9]+'
            );

            v_group_name := 'PATIENT_' ||
                CASE
                    WHEN LENGTH(v_suffix) = 1 THEN '0' || v_suffix
                    ELSE v_suffix
                END;

            v_row_label :=
                v_req.sensitivity ||
                ':ADMIN:ADMINISTRATION,' ||
                v_group_name;

            v_read_label :=
                v_req.sensitivity ||
                ':ADMIN,FIN,LAB,PHARM:' ||
                v_group_name;

            v_stage := 'creating the Oracle account';

            SELECT COUNT(*)
            INTO v_count
            FROM ALL_USERS
            WHERE username = v_req.oracle_username;

            IF v_count = 0 THEN
                SYSTEM.P2_CREATE_PATIENT_ACCOUNT(
                    v_req.oracle_username
                );
            ELSIF v_req.allow_existing_setup <> 'Y' THEN
                RAISE_APPLICATION_ERROR(
                    -20053,
                    'Account already exists; administrator review is required.'
                );
            END IF;

            v_stage := 'creating the patient group';

            IF SYSTEM.P2_OLS_EXISTS(
                    'GROUP_NAME',
                    v_group_name
               ) = 0
            THEN
                LOOP
                    v_group_num :=
                        PROJ_TWO.P2_PATIENT_GROUP_SEQ.NEXTVAL;

                    EXIT WHEN SYSTEM.P2_OLS_EXISTS(
                        'GROUP_NUMBER',
                        TO_CHAR(v_group_num)
                    ) = 0;
                END LOOP;

                UPDATE PROJ_TWO.P2_PATIENT_REG_REQUEST
                SET group_num = v_group_num,
                    stage = v_stage,
                    updated_at = SYSTIMESTAMP
                WHERE request_id = v_req.request_id;

                COMMIT;

                LBACSYS.SA_COMPONENTS.CREATE_GROUP(
                    policy_name => 'HOSPITAL_POL',
                    group_num   => v_group_num,
                    short_name  => v_group_name,
                    long_name   => v_group_name,
                    parent_name => 'PATIENT_ACCESS'
                );

            ELSIF v_req.allow_existing_setup = 'Y'
                  AND v_req.group_num IS NOT NULL
            THEN
                -- Reserved for administrator-approved recovery.
                v_group_num := v_req.group_num;

            ELSE
                RAISE_APPLICATION_ERROR(
                    -20054,
                    'Group already exists; administrator review is required.'
                );
            END IF;

            v_stage := 'creating the patient row label';

            LOOP
                v_label_tag :=
                    PROJ_TWO.P2_PATIENT_LABEL_SEQ.NEXTVAL;

                EXIT WHEN SYSTEM.P2_OLS_EXISTS(
                    'LABEL_TAG',
                    TO_CHAR(v_label_tag)
                ) = 0;
            END LOOP;

            IF v_label_tag < 1000 OR v_label_tag > 1099 THEN
                RAISE_APPLICATION_ERROR(
                    -20055,
                    'PATIENT label tags must be 1000-1099.'
                );
            END IF;

            UPDATE PROJ_TWO.P2_PATIENT_REG_REQUEST
            SET group_num = v_group_num,
                label_tag = v_label_tag,
                row_label = v_row_label,
                stage = v_stage,
                updated_at = SYSTIMESTAMP
            WHERE request_id = v_req.request_id;

            COMMIT;

            LBACSYS.SA_LABEL_ADMIN.CREATE_LABEL(
                policy_name => 'HOSPITAL_POL',
                label_tag   => v_label_tag,
                label_value => v_row_label,
                data_label  => TRUE
            );

            v_stage := 'configuring patient OLS authorisations';

            LBACSYS.SA_USER_ADMIN.SET_USER_LABELS(
                policy_name     => 'HOSPITAL_POL',
                user_name       => v_req.oracle_username,
                max_read_label  => v_read_label,
                max_write_label => v_req.sensitivity,
                min_write_label => 'I',
                def_label       => v_read_label,
                row_label       => 'I'
            );

            LBACSYS.SA_USER_ADMIN.SET_USER_PRIVS(
                policy_name => 'HOSPITAL_POL',
                user_name   => v_req.oracle_username,
                privileges  => NULL
            );

            UPDATE PROJ_TWO.P2_PATIENT_REG_REQUEST
            SET status = 'READY',
                stage = 'awaiting patient-row insertion',
                error_text = NULL,
                updated_at = SYSTIMESTAMP
            WHERE request_id = v_req.request_id;

            COMMIT;

        EXCEPTION
            WHEN OTHERS THEN
                v_error := SUBSTR(
                    v_stage || ': ' || SQLERRM,
                    1,
                    1900
                );

                ROLLBACK;

                UPDATE PROJ_TWO.P2_PATIENT_REG_REQUEST
                SET status = 'FAILED',
                    stage = v_stage,
                    error_text = v_error,
                    updated_at = SYSTIMESTAMP
                WHERE request_id = item.request_id;

                COMMIT;

                -- No DROP USER, password reset, ACCOUNT LOCK,
                -- or automatic retry.
        END;
    END LOOP;
END;
/

SHOW ERRORS PROCEDURE PROJ_TWO.P2_PATIENT_OLS_WORKER

--Step 10
CREATE OR REPLACE PROCEDURE PROJ_TWO.REGISTER_PATIENT_P2 (
    p_sensitivity     IN VARCHAR2,
    p_name            IN VARCHAR2,
    p_dob             IN DATE,
    p_oracle_username IN VARCHAR2,
    p_phone           IN VARCHAR2 DEFAULT NULL
)
AUTHID DEFINER
AS
    PRAGMA AUTONOMOUS_TRANSACTION;

    v_login VARCHAR2(128) :=
        SYS_CONTEXT('USERENV', 'SESSION_USER');

    v_level VARCHAR2(10) :=
        UPPER(TRIM(p_sensitivity));

    v_username VARCHAR2(128) :=
        UPPER(TRIM(p_oracle_username));

    v_label VARCHAR2(4000);
    v_session_level VARCHAR2(30);
    v_comps VARCHAR2(4000);
    v_groups VARCHAR2(4000);
    v_write_groups VARCHAR2(4000);

    v_suffix VARCHAR2(30);
    v_group_name VARCHAR2(30);
    v_count NUMBER;
    v_request_id NUMBER;
    v_patient_id NUMBER;
    v_found BOOLEAN := TRUE;

    v_req PROJ_TWO.P2_PATIENT_REG_REQUEST%ROWTYPE;
BEGIN
    IF v_login NOT IN (
        'USER_RECEPTIONIST1_P2',
        'USER_RECEPTIONIST2_P2'
    ) THEN
        RAISE_APPLICATION_ERROR(
            -20010,
            'Only the two receptionist accounts may register patients.'
        );
    END IF;

    IF v_level IS NULL OR v_level NOT IN ('C', 'R') THEN
        RAISE_APPLICATION_ERROR(
            -20011,
            'Sensitivity must be C or R.'
        );
    END IF;

    IF v_username IS NULL
       OR LENGTH(v_username) > 30
       OR NOT REGEXP_LIKE(
            v_username,
            '^USER_PATIENT[1-9][0-9]*_P2$',
            'c'
       )
    THEN
        RAISE_APPLICATION_ERROR(
            -20012,
            'Use USER_PATIENT<n>_P2 without leading zeros; maximum 30 characters.'
        );
    END IF;

    IF TRIM(p_name) IS NULL
       OR LENGTHB(TRIM(p_name)) > 100
    THEN
        RAISE_APPLICATION_ERROR(
            -20013,
            'Name is required and must fit 100 bytes.'
        );
    END IF;

    IF p_dob IS NULL
       OR TRUNC(p_dob) > TRUNC(SYSDATE)
    THEN
        RAISE_APPLICATION_ERROR(
            -20014,
            'DOB is required and cannot be in the future.'
        );
    END IF;

    IF LENGTHB(TRIM(p_phone)) > 30 THEN
        RAISE_APPLICATION_ERROR(
            -20015,
            'Phone must fit 30 bytes; it may be omitted.'
        );
    END IF;

    v_label := LBACSYS.SA_SESSION.LABEL('HOSPITAL_POL');

    v_session_level := REGEXP_SUBSTR(
        v_label,
        '^[^:]+'
    );

    v_comps := REGEXP_SUBSTR(
        v_label,
        '^[^:]*:([^:]*):',
        1,
        1,
        'c',
        1
    );

    v_groups := REGEXP_SUBSTR(
        v_label,
        '^[^:]*:[^:]*:(.*)$',
        1,
        1,
        'c',
        1
    );

    v_write_groups :=
        LBACSYS.SA_SESSION.GROUP_WRITE('HOSPITAL_POL');

    IF NVL(v_session_level, '?') NOT IN ('C', 'R') THEN
        RAISE_APPLICATION_ERROR(
            -20016,
            'The receptionist session must be at C or R.'
        );
    END IF;

    IF INSTR(
            ',' || REPLACE(v_comps, ' ', '') || ',',
            ',ADMIN,'
       ) = 0
       OR INSTR(
            ',' || REPLACE(v_groups, ' ', '') || ',',
            ',ADMINISTRATION,'
       ) = 0
       OR INSTR(
            ',' || REPLACE(v_write_groups, ' ', '') || ',',
            ',ADMINISTRATION,'
       ) = 0
    THEN
        RAISE_APPLICATION_ERROR(
            -20017,
            'Session needs ADMIN and read/write access to ADMINISTRATION.'
        );
    END IF;

    IF v_level = 'R'
       AND (
            v_login <> 'USER_RECEPTIONIST1_P2'
            OR v_session_level <> 'R'
       )
    THEN
        RAISE_APPLICATION_ERROR(
            -20018,
            'Only USER_RECEPTIONIST1_P2 with an R session may register a VIP.'
        );
    END IF;

    BEGIN
        SELECT *
        INTO v_req
        FROM PROJ_TWO.P2_PATIENT_REG_REQUEST
        WHERE oracle_username = v_username;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_found := FALSE;
    END;

    IF v_found THEN
        -- Retry only the same registration by its original receptionist.
        IF v_req.requested_by <> v_login
           OR v_req.sensitivity <> v_level
           OR v_req.patient_name <> TRIM(p_name)
           OR v_req.dob <> TRUNC(p_dob)
           OR (
                v_req.phone IS NULL
                AND TRIM(p_phone) IS NOT NULL
           )
           OR (
                v_req.phone IS NOT NULL
                AND TRIM(p_phone) IS NULL
           )
           OR v_req.phone <> TRIM(p_phone)
        THEN
            RAISE_APPLICATION_ERROR(
                -20019,
                'A different registration request already uses this username.'
            );
        END IF;

        v_request_id := v_req.request_id;

    ELSE
        SELECT COUNT(*)
        INTO v_count
        FROM ALL_USERS
        WHERE username = v_username;

        IF v_count > 0 THEN
            RAISE_APPLICATION_ERROR(
                -20020,
                'Account already exists without an approved registration request.'
            );
        END IF;

        v_suffix := REGEXP_SUBSTR(
            v_username,
            '[0-9]+'
        );

        v_group_name := 'PATIENT_' ||
            CASE
                WHEN LENGTH(v_suffix) = 1 THEN '0' || v_suffix
                ELSE v_suffix
            END;

        IF SYSTEM.P2_OLS_EXISTS(
                'GROUP_NAME',
                v_group_name
           ) > 0
        THEN
            RAISE_APPLICATION_ERROR(
                -20021,
                'Patient group already exists; administrator review is required.'
            );
        END IF;

        INSERT INTO PROJ_TWO.P2_PATIENT_REG_REQUEST (
            oracle_username,
            patient_name,
            dob,
            phone,
            sensitivity,
            requested_by,
            request_session_label
        )
        VALUES (
            v_username,
            TRIM(p_name),
            TRUNC(p_dob),
            TRIM(p_phone),
            v_level,
            v_login,
            v_label
        )
        RETURNING request_id INTO v_request_id;

        -- Make the request visible to the separate worker.
        COMMIT;
    END IF;

    -- Wait up to about 30 seconds.
    -- The scheduled worker checks every 5 seconds.
    FOR attempt IN 1..61 LOOP
        SELECT *
        INTO v_req
        FROM PROJ_TWO.P2_PATIENT_REG_REQUEST
        WHERE request_id = v_request_id;

        EXIT WHEN v_req.status IN (
            'READY',
            'COMPLETE',
            'FAILED'
        );

        IF attempt < 61 THEN
            DBMS_SESSION.SLEEP(0.5);
        END IF;
    END LOOP;

    IF v_req.status = 'FAILED' THEN
        RAISE_APPLICATION_ERROR(
            -20022,
            SUBSTR(
                'OLS setup failed. Existing accounts remain unlocked. ' ||
                v_req.error_text,
                1,
                1900
            )
        );

    ELSIF v_req.status IN ('QUEUED', 'PROCESSING') THEN
        COMMIT;

        DBMS_OUTPUT.PUT_LINE(
            'PENDING request ' || v_request_id ||
            '. Run the same registration call again after setup finishes.'
        );

        RETURN;
    END IF;

    SELECT *
    INTO v_req
    FROM PROJ_TWO.P2_PATIENT_REG_REQUEST
    WHERE request_id = v_request_id
    FOR UPDATE;

    IF v_req.status = 'COMPLETE' THEN
        COMMIT;

        DBMS_OUTPUT.PUT_LINE(
            'Already completed. PATIENT_ID = ' ||
            v_req.patient_id
        );

        RETURN;

    ELSIF v_req.status <> 'READY' THEN
        RAISE_APPLICATION_ERROR(
            -20023,
            'Request is not ready for the patient insert.'
        );
    END IF;

    -- Refresh OLS state after the background setup.
    -- Preserve the caller's session label and default row label.
    DECLARE
        l_saved_session_label VARCHAR2(4000) :=
            LBACSYS.SA_SESSION.LABEL('HOSPITAL_POL');

        l_saved_row_label VARCHAR2(4000) :=
            LBACSYS.SA_SESSION.ROW_LABEL('HOSPITAL_POL');
    BEGIN
        LBACSYS.SA_SESSION.RESTORE_DEFAULT_LABELS(
            'HOSPITAL_POL'
        );

        IF LBACSYS.SA_SESSION.LABEL('HOSPITAL_POL')
                <> l_saved_session_label
        THEN
            LBACSYS.SA_SESSION.SET_LABEL(
                'HOSPITAL_POL',
                l_saved_session_label
            );
        END IF;

        IF LBACSYS.SA_SESSION.ROW_LABEL('HOSPITAL_POL')
                <> l_saved_row_label
        THEN
            LBACSYS.SA_SESSION.SET_ROW_LABEL(
                'HOSPITAL_POL',
                l_saved_row_label
            );
        END IF;
    END;

    INSERT INTO PROJ_TWO.PATIENT (
        NAME,
        DOB,
        PHONE,
        ORACLE_USERNAME,
        IS_VIP,
        OLS_LABEL
    )
    VALUES (
        v_req.patient_name,
        v_req.dob,
        v_req.phone,
        v_req.oracle_username,
        CASE
            WHEN v_req.sensitivity = 'R' THEN 1
            ELSE 0
        END,
        v_req.label_tag
    )
    RETURNING PATIENT_ID INTO v_patient_id;

    UPDATE PROJ_TWO.P2_PATIENT_REG_REQUEST
    SET status = 'COMPLETE',
        patient_id = v_patient_id,
        stage = 'registration completed',
        updated_at = SYSTIMESTAMP
    WHERE request_id = v_request_id;

    COMMIT;

    DBMS_OUTPUT.PUT_LINE(
        'SUCCESS: ' || v_username
    );

    DBMS_OUTPUT.PUT_LINE(
        'PATIENT_ID: ' || v_patient_id
    );

    DBMS_OUTPUT.PUT_LINE(
        'Group number: ' || v_req.group_num
    );

    DBMS_OUTPUT.PUT_LINE(
        'Label tag: ' || v_req.label_tag
    );

    DBMS_OUTPUT.PUT_LINE(
        'Row label: ' || v_req.row_label
    );

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/

SHOW ERRORS PROCEDURE PROJ_TWO.REGISTER_PATIENT_P2

--Step 11
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM USER_CODE_ROLE_PRIVS
    WHERE object_name = 'REGISTER_PATIENT_P2'
      AND role = 'HOSPITAL_POL_DBA';

    IF v_count > 0 THEN
        EXECUTE IMMEDIATE
            'REVOKE HOSPITAL_POL_DBA FROM PROCEDURE ' ||
            'PROJ_TWO.REGISTER_PATIENT_P2';
    END IF;
END;
/

--Step 12
BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name => 'PROJ_TWO.P2_PATIENT_OLS_JOB',

        job_type => 'PLSQL_BLOCK',

        job_action => q'[
            BEGIN
                DBMS_SESSION.SET_ROLE('HOSPITAL_POL_DBA');
                PROJ_TWO.P2_PATIENT_OLS_WORKER;
            END;
        ]',

        start_date => SYSTIMESTAMP,

        repeat_interval => 'FREQ=SECONDLY;INTERVAL=5',

        enabled => FALSE,

        auto_drop => FALSE,

        comments =>
            'Private account/OLS setup for validated patient registrations'
    );

    DBMS_SCHEDULER.SET_ATTRIBUTE(
        name => 'PROJ_TWO.P2_PATIENT_OLS_JOB',
        attribute => 'logging_level',
        value => DBMS_SCHEDULER.LOGGING_FAILED_RUNS
    );

    DBMS_SCHEDULER.ENABLE(
        'PROJ_TWO.P2_PATIENT_OLS_JOB'
    );
END;
/

--Step 13
GRANT EXECUTE ON PROJ_TWO.REGISTER_PATIENT_P2
TO ROLE_RECEPTIONIST_P2;

REVOKE INSERT ON PROJ_TWO.PATIENT
FROM ROLE_RECEPTIONIST_P2;

--Step 14
SELECT OWNER, OBJECT_NAME, OBJECT_TYPE, STATUS
FROM DBA_OBJECTS
WHERE (
    OWNER = 'SYSTEM'
    AND OBJECT_NAME IN (
        'P2_CREATE_PATIENT_ACCOUNT',
        'P2_OLS_EXISTS'
    )
    AND OBJECT_TYPE IN ('PROCEDURE', 'FUNCTION')
)
OR (
    OWNER = 'PROJ_TWO'
    AND OBJECT_NAME IN (
        'REGISTER_PATIENT_P2',
        'P2_PATIENT_OLS_WORKER',
        'P2_PATIENT_REG_REQUEST'
    )
    AND OBJECT_TYPE IN ('PROCEDURE', 'TABLE')
)
ORDER BY OWNER, OBJECT_TYPE, OBJECT_NAME;


SELECT OWNER,
       JOB_NAME,
       ENABLED,
       STATE,
       REPEAT_INTERVAL,
       JOB_ACTION
FROM DBA_SCHEDULER_JOBS
WHERE OWNER = 'PROJ_TWO'
  AND JOB_NAME = 'P2_PATIENT_OLS_JOB';