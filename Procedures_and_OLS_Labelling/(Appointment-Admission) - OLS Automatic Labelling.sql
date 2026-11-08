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



CREATE OR REPLACE FUNCTION PROJ_TWO.P2_ADMISSION_APPOINTMENT_LABEL (
    p_encounter_type IN VARCHAR2,
    p_patient_id     IN NUMBER,
    p_related_id     IN NUMBER
)
RETURN VARCHAR2
AUTHID DEFINER
AS
    v_username         VARCHAR2(128);
    v_is_vip           NUMBER;
    v_patient_suffix   VARCHAR2(128);
    v_patient_group    VARCHAR2(128);
 
    v_department_name  VARCHAR2(100);
    v_department_key   VARCHAR2(100);
    v_department_group VARCHAR2(30);
 
    v_sensitivity      VARCHAR2(1);
BEGIN
    SELECT UPPER(TRIM(p.oracle_username)),
           p.is_vip
    INTO   v_username,
           v_is_vip
    FROM PROJ_TWO.PATIENT p
    WHERE p.patient_id = p_patient_id;
 
    IF v_is_vip IS NULL OR v_is_vip NOT IN (0, 1) THEN
        RAISE_APPLICATION_ERROR(
            -20101,
            'Patient IS_VIP must be 0 or 1.'
        );
    END IF;
 
    v_sensitivity :=
        CASE WHEN v_is_vip = 1 THEN 'R' ELSE 'C' END;
 
    IF v_username IS NULL
       OR NOT REGEXP_LIKE(
           v_username,
           '^USER_PATIENT[1-9][0-9]*_P2$'
       )
    THEN
        RAISE_APPLICATION_ERROR(
            -20102,
            'Patient username must follow USER_PATIENT<number>_P2.'
        );
    END IF;
 
    v_patient_suffix := REGEXP_SUBSTR(v_username, '[0-9]+');
 
    v_patient_group :=
        'PATIENT_' ||
        CASE
            WHEN LENGTH(v_patient_suffix) = 1
                THEN '0' || v_patient_suffix
            ELSE v_patient_suffix
        END;
 
    IF LENGTH(v_patient_group) > 30 THEN
        RAISE_APPLICATION_ERROR(
            -20103,
            'Derived patient group exceeds the OLS group-name limit.'
        );
    END IF;
 
    IF p_encounter_type = 'APPOINTMENT' THEN
 
        SELECT dep.name
        INTO v_department_name
        FROM PROJ_TWO.DOCTOR doc
        JOIN PROJ_TWO.DEPARTMENT dep
          ON dep.department_id = doc.department_id
        WHERE doc.doctor_id = p_related_id;
 
    ELSIF p_encounter_type = 'ADMISSION' THEN
 
        SELECT dep.name
        INTO v_department_name
        FROM PROJ_TWO.ROOM rm
        JOIN PROJ_TWO.WARD w
          ON w.ward_id = rm.ward_id
        JOIN PROJ_TWO.DEPARTMENT dep
          ON dep.department_id = w.department_id
        WHERE rm.room_id = p_related_id;
 
    ELSE
        RAISE_APPLICATION_ERROR(
            -20104,
            'Unsupported encounter type.'
        );
    END IF;
 
    v_department_key :=
        REGEXP_REPLACE(
            UPPER(TRIM(v_department_name)),
            '[^A-Z0-9]',
            ''
        );
 
    CASE v_department_key
        WHEN 'NEURO' THEN
            v_department_group := 'NEURO';
        WHEN 'NEUROLOGY' THEN
            v_department_group := 'NEURO';
        WHEN 'CARDIOLOGY' THEN
            v_department_group := 'CARDIOLOGY';
        WHEN 'GENERALMEDICINE' THEN
            v_department_group := 'GENERAL_MED';
        WHEN 'GENERALMED' THEN
            v_department_group := 'GENERAL_MED';
        ELSE
            RAISE_APPLICATION_ERROR(
                -20105,
                'No OLS group mapping for department: ' ||
                v_department_name
            );
    END CASE;
 
    RETURN
        v_sensitivity ||
        ':ADMIN:ADMINISTRATION,' ||
        v_department_group || ',' ||
        v_patient_group;
 
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(
            -20106,
            'Required patient, doctor, room, ward or department was not found.'
        );
END;
/
 
CREATE OR REPLACE FUNCTION PROJ_TWO.P2_APPOINTMENT_LABEL (
    p_patient_id IN NUMBER,
    p_doctor_id  IN NUMBER
)
RETURN LBACSYS.LBAC_LABEL
AUTHID DEFINER
AS
    v_label_text VARCHAR2(4000);
BEGIN
    v_label_text :=
        PROJ_TWO.P2_ADMISSION_APPOINTMENT_LABEL(
            'APPOINTMENT',
            p_patient_id,
            p_doctor_id
        );
 
    IF v_label_text IS NULL THEN
        RAISE_APPLICATION_ERROR(
            -20107,
            'Unable to calculate the appointment label.'
        );
    END IF;
 
    RETURN LBACSYS.TO_LBAC_DATA_LABEL(
        'HOSPITAL_POL',
        v_label_text
    );
END;
/
 
CREATE OR REPLACE FUNCTION PROJ_TWO.P2_ADMISSION_LABEL (
    p_patient_id IN NUMBER,
    p_room_id    IN NUMBER
)
RETURN LBACSYS.LBAC_LABEL
AUTHID DEFINER
AS
    v_label_text VARCHAR2(4000);
BEGIN
    v_label_text :=
        PROJ_TWO.P2_ADMISSION_APPOINTMENT_LABEL(
            'ADMISSION',
            p_patient_id,
            p_room_id
        );
 
    IF v_label_text IS NULL THEN
        RAISE_APPLICATION_ERROR(
            -20108,
            'Unable to calculate the admission label.'
        );
    END IF;
 
    RETURN LBACSYS.TO_LBAC_DATA_LABEL(
        'HOSPITAL_POL',
        v_label_text
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

