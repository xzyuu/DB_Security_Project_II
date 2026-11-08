--Step 1
SET ROLE ALL;

BEGIN
    SA_USER_ADMIN.SET_PROG_PRIVS(
        policy_name       => 'HOSPITAL_POL',
        schema_name       => 'PROJ_TWO',
        program_unit_name => 'P2_ADMISSION_APPOINTMENT_LABEL',
        privileges        => 'READ'
    );
END;
/

--Step 2
GRANT EXECUTE
ON PROJ_TWO.P2_APPOINTMENT_LABEL
TO LBACSYS;

GRANT EXECUTE
ON PROJ_TWO.P2_ADMISSION_LABEL
TO LBACSYS;

GRANT EXECUTE
ON PROJ_TWO.P2_APPOINTMENT_LABEL
TO LBAC_TRIGGER;

GRANT EXECUTE
ON PROJ_TWO.P2_ADMISSION_LABEL
TO LBAC_TRIGGER;

--Step 3
SET SERVEROUTPUT ON
SET ROLE ALL;

DECLARE
    v_valid_functions PLS_INTEGER;

    PROCEDURE P2_ADMISSION_APPOINTMENT_APPLY (
        p_table_name IN VARCHAR2,
        p_function   IN VARCHAR2
    )
    IS
        v_options      VARCHAR2(4000);
        v_old_function VARCHAR2(1024);
        v_predicate    VARCHAR2(256);
        v_status       VARCHAR2(8);
        v_normalised   VARCHAR2(4000);
        v_error        VARCHAR2(2000);
        v_count        PLS_INTEGER;
    BEGIN
        SELECT table_options,
               function,
               predicate,
               status
        INTO   v_options,
               v_old_function,
               v_predicate,
               v_status
        FROM ALL_SA_TABLE_POLICIES
        WHERE policy_name = 'HOSPITAL_POL'
          AND schema_name = 'PROJ_TWO'
          AND table_name = p_table_name;

        v_normalised :=
            ',' ||
            REPLACE(UPPER(NVL(v_options, '')), ' ', '') ||
            ',';

        -- Require the necessary enforcement controls.
        IF NVL(v_status, 'DISABLED') <> 'ENABLED'
           OR INSTR(v_normalised, ',NO_CONTROL,') > 0
           OR INSTR(v_normalised, ',READ_CONTROL,') = 0
           OR INSTR(v_normalised, ',CHECK_CONTROL,') = 0
           OR (
               INSTR(v_normalised, ',WRITE_CONTROL,') = 0
               AND (
                   INSTR(v_normalised, ',INSERT_CONTROL,') = 0
                   OR INSTR(v_normalised, ',UPDATE_CONTROL,') = 0
               )
           )
        THEN
            RAISE_APPLICATION_ERROR(
                -20120,
                p_table_name ||
                ': expected enabled read, insert, update and check controls.'
            );
        END IF;

        -- Avoid replacing an unrelated labelling function.
        IF v_old_function IS NOT NULL
           AND UPPER(REPLACE(v_old_function, ' ', '')) <>
               UPPER(REPLACE(p_function, ' ', ''))
        THEN
            RAISE_APPLICATION_ERROR(
                -20121,
                p_table_name ||
                ': a different labelling function already exists.'
            );
        END IF;

        SA_POLICY_ADMIN.REMOVE_TABLE_POLICY(
            policy_name => 'HOSPITAL_POL',
            schema_name => 'PROJ_TWO',
            table_name  => p_table_name,
            drop_column => FALSE
        );

        BEGIN
            SA_POLICY_ADMIN.APPLY_TABLE_POLICY(
                policy_name    => 'HOSPITAL_POL',
                schema_name    => 'PROJ_TWO',
                table_name     => p_table_name,
                table_options  => v_options,
                label_function => p_function,
                predicate      => v_predicate
            );

        EXCEPTION
            WHEN OTHERS THEN
                v_error := SQLERRM;

                BEGIN
                    -- Remove any partially applied configuration.
                    SELECT COUNT(*)
                    INTO v_count
                    FROM ALL_SA_TABLE_POLICIES
                    WHERE policy_name = 'HOSPITAL_POL'
                      AND schema_name = 'PROJ_TWO'
                      AND table_name = p_table_name;

                    IF v_count > 0 THEN
                        SA_POLICY_ADMIN.REMOVE_TABLE_POLICY(
                            policy_name => 'HOSPITAL_POL',
                            schema_name => 'PROJ_TWO',
                            table_name  => p_table_name,
                            drop_column => FALSE
                        );
                    END IF;

                    -- Restore the previous policy configuration.
                    SA_POLICY_ADMIN.APPLY_TABLE_POLICY(
                        policy_name    => 'HOSPITAL_POL',
                        schema_name    => 'PROJ_TWO',
                        table_name     => p_table_name,
                        table_options  => v_options,
                        label_function => v_old_function,
                        predicate      => v_predicate
                    );

                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE_APPLICATION_ERROR(
                            -20122,
                            p_table_name ||
                            ': attachment AND restoration failed. ' ||
                            'Check policy protection before further use. ' ||
                            SUBSTR(SQLERRM, 1, 600) ||
                            ' Original error: ' ||
                            SUBSTR(v_error, 1, 600)
                        );
                END;

                RAISE_APPLICATION_ERROR(
                    -20123,
                    p_table_name ||
                    ': previous configuration restored after failure. ' ||
                    SUBSTR(v_error, 1, 1400)
                );
        END;

        DBMS_OUTPUT.PUT_LINE(
            p_table_name || ': labelling function attached.'
        );
    END P2_ADMISSION_APPOINTMENT_APPLY;

BEGIN
    IF SYS_CONTEXT('USERENV', 'SESSION_USER') <> 'PROJ_TWO' THEN
        RAISE_APPLICATION_ERROR(
            -20124,
            'Run this block while connected as PROJ_TWO.'
        );
    END IF;

    -- Check all three functions before changing either policy.
    SELECT COUNT(*)
    INTO v_valid_functions
    FROM USER_OBJECTS
    WHERE object_type = 'FUNCTION'
      AND status = 'VALID'
      AND object_name IN (
          'P2_ADMISSION_APPOINTMENT_LABEL',
          'P2_APPOINTMENT_LABEL',
          'P2_ADMISSION_LABEL'
      );

    IF v_valid_functions <> 3 THEN
        RAISE_APPLICATION_ERROR(
            -20125,
            'All three labelling functions must exist and be VALID.'
        );
    END IF;

    P2_ADMISSION_APPOINTMENT_APPLY(
        'APPOINTMENT',
        'PROJ_TWO.P2_APPOINTMENT_LABEL(:new.PATIENT_ID,:new.DOCTOR_ID)'
    );

    P2_ADMISSION_APPOINTMENT_APPLY(
        'ADMISSION',
        'PROJ_TWO.P2_ADMISSION_LABEL(:new.PATIENT_ID,:new.ROOM_ID)'
    );
END;
/

