-- Write procedures and private guard package
DECLARE
    v_guard_grants PLS_INTEGER;
BEGIN
    IF SYS_CONTEXT('USERENV', 'SESSION_USER') <> 'PROJ_TWO' THEN
        RAISE_APPLICATION_ERROR(-20000, 'Connect as PROJ_TWO to install.');
    END IF;

    SELECT COUNT(*)
    INTO v_guard_grants
    FROM user_tab_privs_made
    WHERE table_name = 'HOSPITAL_WRITE_GUARDS'
      AND privilege = 'EXECUTE';

    IF v_guard_grants <> 0 THEN
        RAISE_APPLICATION_ERROR(-20018, 'The internal guard package must have no EXECUTE grants.');
    END IF;
END;
/

CREATE OR REPLACE PACKAGE PROJ_TWO.HOSPITAL_WRITE_GUARDS AUTHID DEFINER AS
    FUNCTION caller_doctor_id RETURN NUMBER;
    FUNCTION caller_pharmacist_id RETURN NUMBER;
    PROCEDURE require_billing_officer;
    FUNCTION has_dispensing(p_prescription_id IN NUMBER) RETURN BOOLEAN;
END HOSPITAL_WRITE_GUARDS;
/

CREATE OR REPLACE PACKAGE BODY PROJ_TWO.HOSPITAL_WRITE_GUARDS AS
    FUNCTION caller_doctor_id RETURN NUMBER IS
        v_doctor_id PROJ_TWO.DOCTOR.DOCTOR_ID%TYPE;
    BEGIN
        SELECT d.doctor_id
        INTO v_doctor_id
        FROM PROJ_TWO.DOCTOR d
        JOIN PROJ_TWO.STAFF s ON s.staff_id = d.staff_id
        WHERE s.oracle_username = SYS_CONTEXT('USERENV', 'SESSION_USER')
          AND s.role = 'ROLE_DOCTOR_P2';

        RETURN v_doctor_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001, 'No doctor is mapped to this login.');
    END caller_doctor_id;

    FUNCTION caller_pharmacist_id RETURN NUMBER IS
        v_pharmacist_id PROJ_TWO.PHARMACIST.PHARMACIST_ID%TYPE;
    BEGIN
        SELECT p.pharmacist_id
        INTO v_pharmacist_id
        FROM PROJ_TWO.PHARMACIST p
        JOIN PROJ_TWO.STAFF s ON s.staff_id = p.staff_id
        WHERE s.oracle_username = SYS_CONTEXT('USERENV', 'SESSION_USER')
          AND s.role = 'ROLE_PHARMACIST_P2';

        RETURN v_pharmacist_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20002, 'No pharmacist is mapped to this login.');
    END caller_pharmacist_id;

    PROCEDURE require_billing_officer IS
        v_staff_id PROJ_TWO.STAFF.STAFF_ID%TYPE;
    BEGIN
        SELECT s.staff_id
        INTO v_staff_id
        FROM PROJ_TWO.STAFF s
        WHERE s.oracle_username = SYS_CONTEXT('USERENV', 'SESSION_USER')
          AND s.role = 'ROLE_BILLING_P2';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20003, 'No billing officer is mapped to this login.');
    END require_billing_officer;

    FUNCTION has_dispensing(p_prescription_id IN NUMBER) RETURN BOOLEAN IS
        v_count PLS_INTEGER;
    BEGIN
        SELECT COUNT(*)
        INTO v_count
        FROM PROJ_TWO.DISPENSING
        WHERE prescription_id = p_prescription_id
          AND ROWNUM = 1;

        RETURN v_count = 1;
    END has_dispensing;
END HOSPITAL_WRITE_GUARDS;
/

CREATE OR REPLACE PROCEDURE PROJ_TWO.CREATE_PRESCRIPTION (
    p_appointment_id IN PROJ_TWO.APPOINTMENT.APPOINTMENT_ID%TYPE,
    p_medication     IN PROJ_TWO.PRESCRIPTION.MEDICATION%TYPE,
    p_dosage         IN PROJ_TWO.PRESCRIPTION.DOSAGE%TYPE
) AUTHID DEFINER AS
    v_doctor_id PROJ_TWO.DOCTOR.DOCTOR_ID%TYPE;
BEGIN
    v_doctor_id := PROJ_TWO.HOSPITAL_WRITE_GUARDS.caller_doctor_id();

    INSERT INTO PROJ_TWO.PRESCRIPTION (appointment_id, patient_id, doctor_id, medication, dosage)
    SELECT a.appointment_id, a.patient_id, a.doctor_id, p_medication, p_dosage
    FROM PROJ_TWO.APPOINTMENT a
    WHERE a.appointment_id = p_appointment_id
      AND a.doctor_id = v_doctor_id;

    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20004, 'Appointment is unavailable or assigned to another doctor.');
    END IF;
END CREATE_PRESCRIPTION;
/

CREATE OR REPLACE PROCEDURE PROJ_TWO.EDIT_PRESCRIPTION (
    p_prescription_id IN PROJ_TWO.PRESCRIPTION.PRESCRIPTION_ID%TYPE,
    p_medication      IN PROJ_TWO.PRESCRIPTION.MEDICATION%TYPE,
    p_dosage          IN PROJ_TWO.PRESCRIPTION.DOSAGE%TYPE
) AUTHID DEFINER AS
    v_doctor_id PROJ_TWO.DOCTOR.DOCTOR_ID%TYPE;
    v_locked_id PROJ_TWO.PRESCRIPTION.PRESCRIPTION_ID%TYPE;
BEGIN
    SAVEPOINT hospital_edit_rx;
    v_doctor_id := PROJ_TWO.HOSPITAL_WRITE_GUARDS.caller_doctor_id();

    BEGIN
        SELECT r.prescription_id
        INTO v_locked_id
        FROM PROJ_TWO.PRESCRIPTION r
        WHERE r.prescription_id = p_prescription_id
          AND r.doctor_id = v_doctor_id
          AND r.status = 'Pending'
        FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20005, 'No editable pending prescription for this doctor.');
    END;

    IF PROJ_TWO.HOSPITAL_WRITE_GUARDS.has_dispensing(v_locked_id) THEN
        RAISE_APPLICATION_ERROR(-20006, 'A dispensing record already exists for this prescription.');
    END IF;

    UPDATE PROJ_TWO.PRESCRIPTION
    WHERE prescription_id = v_locked_id
      AND doctor_id = v_doctor_id
      AND status = 'Pending';

    IF SQL%ROWCOUNT <> 1 THEN
        RAISE_APPLICATION_ERROR(-20005, 'No editable pending prescription for this doctor.');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK TO hospital_edit_rx;
        RAISE;
END EDIT_PRESCRIPTION;
/

CREATE OR REPLACE PROCEDURE PROJ_TWO.CANCEL_PRESCRIPTION (
    p_prescription_id IN PROJ_TWO.PRESCRIPTION.PRESCRIPTION_ID%TYPE
) AUTHID DEFINER AS
    v_doctor_id PROJ_TWO.DOCTOR.DOCTOR_ID%TYPE;
    v_locked_id PROJ_TWO.PRESCRIPTION.PRESCRIPTION_ID%TYPE;
BEGIN
    SAVEPOINT hospital_cancel_rx;
    v_doctor_id := PROJ_TWO.HOSPITAL_WRITE_GUARDS.caller_doctor_id();

    BEGIN
        SELECT r.prescription_id
        INTO v_locked_id
        FROM PROJ_TWO.PRESCRIPTION r
        WHERE r.prescription_id = p_prescription_id
          AND r.doctor_id = v_doctor_id
          AND r.status = 'Pending'
        FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20007, 'No cancellable pending prescription for this doctor.');
    END;

    IF PROJ_TWO.HOSPITAL_WRITE_GUARDS.has_dispensing(v_locked_id) THEN
        RAISE_APPLICATION_ERROR(-20006, 'A dispensing record already exists for this prescription.');
    END IF;

    UPDATE PROJ_TWO.PRESCRIPTION
    WHERE prescription_id = v_locked_id
      AND doctor_id = v_doctor_id
      AND status = 'Pending';

    IF SQL%ROWCOUNT <> 1 THEN
        RAISE_APPLICATION_ERROR(-20007, 'No cancellable pending prescription for this doctor.');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK TO hospital_cancel_rx;
        RAISE;
END CANCEL_PRESCRIPTION;
/

CREATE OR REPLACE PROCEDURE PROJ_TWO.DISPENSE_PRESCRIPTION (
    p_prescription_id IN PROJ_TWO.PRESCRIPTION.PRESCRIPTION_ID%TYPE,
    p_quantity        IN PROJ_TWO.DISPENSING.MEDICATION_QUANTITY%TYPE
) AUTHID DEFINER AS
    v_pharmacist_id PROJ_TWO.PHARMACIST.PHARMACIST_ID%TYPE;
    v_locked_id     PROJ_TWO.PRESCRIPTION.PRESCRIPTION_ID%TYPE;
BEGIN
    SAVEPOINT hospital_dispense_rx;

    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        RAISE_APPLICATION_ERROR(-20008, 'Medication quantity must be positive.');
    END IF;

    v_pharmacist_id := PROJ_TWO.HOSPITAL_WRITE_GUARDS.caller_pharmacist_id();

    BEGIN
        SELECT r.prescription_id
        INTO v_locked_id
        FROM PROJ_TWO.PRESCRIPTION r
        WHERE r.prescription_id = p_prescription_id
          AND r.status = 'Pending'
        FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20009, 'No visible pending prescription for dispensing.');
    END;

    IF PROJ_TWO.HOSPITAL_WRITE_GUARDS.has_dispensing(v_locked_id) THEN
        RAISE_APPLICATION_ERROR(-20006, 'A dispensing record already exists for this prescription.');
    END IF;

    INSERT INTO PROJ_TWO.DISPENSING (prescription_id, pharmacist_id, medication_quantity)
    VALUES (v_locked_id, v_pharmacist_id, p_quantity);

    UPDATE PROJ_TWO.PRESCRIPTION
    WHERE prescription_id = v_locked_id
      AND status = 'Pending';

    IF SQL%ROWCOUNT <> 1 THEN
        RAISE_APPLICATION_ERROR(-20009, 'No visible pending prescription for dispensing.');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK TO hospital_dispense_rx;
        RAISE;
END DISPENSE_PRESCRIPTION;
/

CREATE OR REPLACE PROCEDURE PROJ_TWO.UPDATE_DISPENSING_STATUS (
    p_dispense_id IN PROJ_TWO.DISPENSING.DISPENSE_ID%TYPE,
    p_new_status  IN PROJ_TWO.DISPENSING.STATUS%TYPE
) AUTHID DEFINER AS
    v_pharmacist_id PROJ_TWO.PHARMACIST.PHARMACIST_ID%TYPE;
BEGIN
    IF p_new_status IS NULL OR p_new_status <> 'Cancelled' THEN
        RAISE_APPLICATION_ERROR(-20010, 'The permitted transition is Dispensed to Cancelled.');
    END IF;

    v_pharmacist_id := PROJ_TWO.HOSPITAL_WRITE_GUARDS.caller_pharmacist_id();

    UPDATE PROJ_TWO.DISPENSING
    WHERE dispense_id = p_dispense_id
      AND pharmacist_id = v_pharmacist_id
      AND status = 'Dispensed';

    IF SQL%ROWCOUNT <> 1 THEN
        RAISE_APPLICATION_ERROR(-20011, 'No cancellable dispensing record for this pharmacist.');
    END IF;
END UPDATE_DISPENSING_STATUS;
/

CREATE OR REPLACE PROCEDURE PROJ_TWO.CREATE_ADMISSION_BILL (
    p_admission_id IN PROJ_TWO.ADMISSION.ADMISSION_ID%TYPE,
    p_amount       IN PROJ_TWO.BILL.AMOUNT%TYPE
) AUTHID DEFINER AS
BEGIN
    PROJ_TWO.HOSPITAL_WRITE_GUARDS.require_billing_officer;

    IF p_amount IS NULL OR p_amount < 0 OR p_amount <> ROUND(p_amount, 2) THEN
        RAISE_APPLICATION_ERROR(-20012, 'Enter a nonnegative amount with at most two decimal places.');
    END IF;

    INSERT INTO PROJ_TWO.BILL (patient_id, admission_id, amount)
    SELECT a.patient_id, a.admission_id, p_amount
    FROM PROJ_TWO.ADMISSION a
    WHERE a.admission_id = p_admission_id;

    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20013, 'Admission is unavailable to this billing officer.');
    END IF;
END CREATE_ADMISSION_BILL;
/

CREATE OR REPLACE PROCEDURE PROJ_TWO.UPDATE_BILL (
    p_bill_id    IN PROJ_TWO.BILL.BILL_ID%TYPE,
    p_amount     IN PROJ_TWO.BILL.AMOUNT%TYPE,
    p_new_status IN PROJ_TWO.BILL.STATUS%TYPE
) AUTHID DEFINER AS
BEGIN
    PROJ_TWO.HOSPITAL_WRITE_GUARDS.require_billing_officer;

    IF p_new_status IS NULL OR p_new_status NOT IN ('Open', 'Paid') THEN
        RAISE_APPLICATION_ERROR(-20014, 'An open bill can be kept Open or marked Paid.');
    END IF;

    IF p_amount < 0 OR p_amount <> ROUND(p_amount, 2) THEN
        RAISE_APPLICATION_ERROR(-20012, 'Enter a nonnegative amount with at most two decimal places.');
    END IF;

    UPDATE PROJ_TWO.BILL
    WHERE bill_id = p_bill_id
      AND status = 'Open';

    IF SQL%ROWCOUNT <> 1 THEN
        RAISE_APPLICATION_ERROR(-20015, 'No visible Open bill can be updated.');
    END IF;
END UPDATE_BILL;
/

DECLARE
    v_valid_objects PLS_INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO v_valid_objects
    FROM user_objects
    WHERE status = 'VALID'
      AND (
          (object_name = 'HOSPITAL_WRITE_GUARDS' AND object_type IN ('PACKAGE', 'PACKAGE BODY'))
          OR (object_type = 'PROCEDURE' AND object_name IN (
              'CREATE_PRESCRIPTION', 'EDIT_PRESCRIPTION', 'CANCEL_PRESCRIPTION',
              'DISPENSE_PRESCRIPTION', 'UPDATE_DISPENSING_STATUS',
              'CREATE_ADMISSION_BILL', 'UPDATE_BILL'
          ))
      );

    IF v_valid_objects <> 9 THEN
        RAISE_APPLICATION_ERROR(-20016, 'Fix the compilation errors before granting access.');
    END IF;

    SA_USER_ADMIN.SET_PROG_PRIVS(
        policy_name       => 'HOSPITAL_POL',
        schema_name       => 'PROJ_TWO',
        program_unit_name => 'HOSPITAL_WRITE_GUARDS',
        privileges        => 'READ'
    );
END;
/

-- OLS labelling functions
CREATE OR REPLACE FUNCTION PROJ_TWO.LBL_PHARMACY(
    p_table           IN VARCHAR2,
    p_status          IN VARCHAR2,
    p_patient_id      IN NUMBER DEFAULT NULL,
    p_prescription_id IN NUMBER DEFAULT NULL
) RETURN LBACSYS.LBAC_LABEL
AUTHID DEFINER
AS
    v_patient_id PROJ_TWO.PATIENT.PATIENT_ID%TYPE;
    v_is_vip PROJ_TWO.PATIENT.IS_VIP%TYPE;
    v_suffix VARCHAR2(128);
    v_group VARCHAR2(128);
    v_level VARCHAR2(1);
BEGIN
    CASE p_table
        WHEN 'PRESCRIPTION' THEN
            v_patient_id := p_patient_id;
            IF p_status IN ('Dispensed', 'Cancelled') THEN
                v_level := 'R';
            ELSE
                v_level := 'C';
            END IF;

        WHEN 'DISPENSING' THEN
            BEGIN
                SELECT patient_id INTO v_patient_id
                FROM PROJ_TWO.PRESCRIPTION
                WHERE prescription_id = p_prescription_id;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    RAISE_APPLICATION_ERROR(-20023, 'The dispensing prescription was not found');
            END;
            v_level := 'C';

        ELSE
            RAISE_APPLICATION_ERROR(-20021, 'Unsupported pharmacy table');
    END CASE;

    IF v_patient_id IS NULL OR v_patient_id < 1
       OR v_patient_id <> TRUNC(v_patient_id) THEN
        RAISE_APPLICATION_ERROR(-20022, 'A positive integer patient ID is required');
    END IF;

    SELECT REGEXP_SUBSTR(UPPER(oracle_username), '^USER_PATIENT([0-9]+)_P2$', 1, 1, NULL, 1),
           is_vip
    INTO v_suffix, v_is_vip
    FROM PROJ_TWO.PATIENT
    WHERE patient_id = v_patient_id;

    IF v_suffix IS NULL THEN
        RAISE_APPLICATION_ERROR(-20022, 'The patient username does not identify a patient group');
    END IF;

    IF v_is_vip = 1 THEN
        v_level := 'R';
    END IF;

    v_group := 'PATIENT_' || LPAD(v_suffix, GREATEST(2, LENGTH(v_suffix)), '0');
    RETURN TO_LBAC_DATA_LABEL('HOSPITAL_POL', v_level || ':PHARM:PHARMACY,' || v_group);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20022, 'The patient was not found');
END LBL_PHARMACY;
/

CREATE OR REPLACE FUNCTION PROJ_TWO.LBL_BILL(
    p_patient_id IN NUMBER DEFAULT NULL
) RETURN LBACSYS.LBAC_LABEL
AUTHID DEFINER
AS
    v_is_vip PROJ_TWO.PATIENT.IS_VIP%TYPE;
    v_suffix VARCHAR2(128);
    v_group VARCHAR2(128);
    v_level VARCHAR2(1) := 'C';
BEGIN
    IF p_patient_id IS NULL OR p_patient_id < 1
       OR p_patient_id <> TRUNC(p_patient_id) THEN
        RAISE_APPLICATION_ERROR(-20024, 'A positive integer patient ID is required');
    END IF;

    SELECT REGEXP_SUBSTR(UPPER(oracle_username), '^USER_PATIENT([0-9]+)_P2$', 1, 1, NULL, 1),
           is_vip
    INTO v_suffix, v_is_vip
    FROM PROJ_TWO.PATIENT
    WHERE patient_id = p_patient_id;

    IF v_suffix IS NULL THEN
        RAISE_APPLICATION_ERROR(-20024, 'The patient username does not identify a patient group');
    END IF;

    IF v_is_vip = 1 THEN
        v_level := 'R';
    END IF;

    v_group := 'PATIENT_' || LPAD(v_suffix, GREATEST(2, LENGTH(v_suffix)), '0');
    RETURN TO_LBAC_DATA_LABEL('HOSPITAL_POL', v_level || ':FIN:ADMINISTRATION,' || v_group);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20024, 'The patient was not found');
END LBL_BILL;
/

DECLARE
    v_valid PLS_INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_valid
    FROM user_objects
    WHERE object_type = 'FUNCTION' AND status = 'VALID'
      AND object_name IN ('LBL_PHARMACY', 'LBL_BILL');

    IF v_valid <> 2 THEN
        RAISE_APPLICATION_ERROR(-20026, 'Compile both labeling functions before assigning READ');
    END IF;

    LBACSYS.SA_USER_ADMIN.SET_PROG_PRIVS('HOSPITAL_POL', 'PROJ_TWO', 'LBL_PHARMACY', 'READ');
    LBACSYS.SA_USER_ADMIN.SET_PROG_PRIVS('HOSPITAL_POL', 'PROJ_TWO', 'LBL_BILL', 'READ');
END;
/
