SET ROLE ALL;

BEGIN
    SA_LABEL_ADMIN.CREATE_LABEL('HOSPITAL_POL', 6021, 'C:CLINICAL:NEURO', TRUE);
    SA_LABEL_ADMIN.CREATE_LABEL('HOSPITAL_POL', 6022, 'C:CLINICAL:CARDIOLOGY', TRUE);
    SA_LABEL_ADMIN.CREATE_LABEL('HOSPITAL_POL', 6023, 'C:CLINICAL:GENERAL_MED', TRUE);
    SA_LABEL_ADMIN.CREATE_LABEL('HOSPITAL_POL', 6031, 'R:CLINICAL:NEURO', TRUE);
    SA_LABEL_ADMIN.CREATE_LABEL('HOSPITAL_POL', 6032, 'R:CLINICAL:CARDIOLOGY', TRUE);
    SA_LABEL_ADMIN.CREATE_LABEL('HOSPITAL_POL', 6033, 'R:CLINICAL:GENERAL_MED', TRUE);
END;

CREATE OR REPLACE FUNCTION PROJ_TWO.DEPT_GROUP (
    p_department_id IN NUMBER
) RETURN VARCHAR2
AS
BEGIN
    RETURN CASE p_department_id
        WHEN 1  THEN 'NEURO'
        WHEN 21 THEN 'CARDIOLOGY'
        WHEN 22 THEN 'GENERAL_MED'
        WHEN 23 THEN 'CLIN_CHEM'
        WHEN 24 THEN 'MICROBIO'
        WHEN 3  THEN 'PHARMACY'
        WHEN 25 THEN 'ADMINISTRATION'
    END;
END DEPT_GROUP;
/


CREATE OR REPLACE FUNCTION PROJ_TWO.LBL_CLINICAL (
    p_doctor_id  IN NUMBER,
    p_patient_id IN NUMBER
) RETURN LBACSYS.LBAC_LABEL
AS
    v_dept  NUMBER;
    v_group VARCHAR2(30);
    v_vip   NUMBER;
BEGIN
    SELECT department_id
    INTO v_dept
    FROM PROJ_TWO.DOCTOR
    WHERE doctor_id = p_doctor_id;
 
    v_group := PROJ_TWO.DEPT_GROUP(v_dept);
 
    IF v_group IS NULL THEN
        RAISE_APPLICATION_ERROR(-20101,
            'lbl_clinical: doctor ' || p_doctor_id || ' has no department group');
    END IF;
 
    SELECT is_vip
    INTO v_vip
    FROM PROJ_TWO.PATIENT
    WHERE patient_id = p_patient_id;
 
    RETURN LBACSYS.TO_LBAC_DATA_LABEL('HOSPITAL_POL',
        CASE WHEN v_vip = 1 THEN 'R' ELSE 'C' END || ':CLINICAL:' || v_group);
 
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20102, 'lbl_clinical: doctor or patient not found');
END LBL_CLINICAL;
/


BEGIN
    SA_USER_ADMIN.SET_PROG_PRIVS(
        policy_name       => 'HOSPITAL_POL',
        schema_name       => 'PROJ_TWO',
        program_unit_name => 'LBL_CLINICAL',
        privileges        => 'READ'
    );
END;
/


BEGIN
    SA_POLICY_ADMIN.APPLY_TABLE_POLICY(
        policy_name    => 'HOSPITAL_POL',
        schema_name    => 'PROJ_TWO',
        table_name     => 'MEDICAL_RECORD',
        table_options  => 'READ_CONTROL,INSERT_CONTROL,UPDATE_CONTROL,DELETE_CONTROL,CHECK_CONTROL,HIDE',
        label_function => 'PROJ_TWO.lbl_clinical(:new.author_doctor_id, :new.patient_id)'
    );
 
    SA_POLICY_ADMIN.APPLY_TABLE_POLICY(
        policy_name    => 'HOSPITAL_POL',
        schema_name    => 'PROJ_TWO',
        table_name     => 'CARE_ASSIGNMENT',
        table_options  => 'READ_CONTROL,INSERT_CONTROL,UPDATE_CONTROL,DELETE_CONTROL,CHECK_CONTROL,HIDE',
        label_function => 'PROJ_TWO.lbl_clinical(:new.doctor_id, :new.patient_id)'
    );
END;
/


-- : label the existing rows (the function runs only when a row is written)
UPDATE PROJ_TWO.MEDICAL_RECORD SET patient_id = patient_id;
 
UPDATE PROJ_TWO.CARE_ASSIGNMENT SET patient_id = patient_id;
 
COMMIT;