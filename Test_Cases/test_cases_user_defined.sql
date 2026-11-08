-- CS5322 Project 2: user-defined test cases (procedure and role workflows)
-- Connect as the DATABASE USER of each case in a new session before running it.
SET SERVEROUTPUT ON

-- ======================================================================
-- PATIENT
-- ======================================================================

-- PAT-01 | DATABASE USER: USER_PATIENT1_P2
SELECT * FROM PROJ_TWO.VIEW_PATIENT_PORTAL;

-- PAT-02 | DATABASE USER: USER_PATIENT1_P2
SELECT * FROM PROJ_TWO.VIEW_PATIENT_PORTAL_PATIENT;

-- PAT-03 | DATABASE USER: USER_PATIENT1_P2
SELECT * FROM PROJ_TWO.VIEW_PATIENT_PORTAL_APPOINTMENT;

-- PAT-04 | DATABASE USER: USER_PATIENT1_P2
SELECT * FROM PROJ_TWO.VIEW_PATIENT_PORTAL_ADMISSION;

-- PAT-05 | DATABASE USER: USER_PATIENT1_P2
SELECT * FROM PROJ_TWO.VIEW_PATIENT_PORTAL_PRESCRIPTION;

-- PAT-06 | DATABASE USER: USER_PATIENT1_P2
SELECT * FROM PROJ_TWO.VIEW_PATIENT_PORTAL_DISPENSING;

-- PAT-07 | DATABASE USER: USER_PATIENT1_P2
SELECT * FROM PROJ_TWO.VIEW_PATIENT_PORTAL_BILL;

-- PAT-08 | DATABASE USER: USER_PATIENT1_P2
SELECT * FROM PROJ_TWO.PATIENT;

-- PAT-09 | DATABASE USER: USER_PATIENT1_P2
SELECT * FROM PROJ_TWO.APPOINTMENT;

-- PAT-10 | DATABASE USER: USER_PATIENT1_P2
SELECT * FROM PROJ_TWO.ADMISSION;

-- PAT-11 | DATABASE USER: USER_PATIENT1_P2
SELECT * FROM PROJ_TWO.PRESCRIPTION;

-- PAT-12 | DATABASE USER: USER_PATIENT1_P2
SELECT * FROM PROJ_TWO.DISPENSING;

-- PAT-13 | DATABASE USER: USER_PATIENT1_P2
SELECT * FROM PROJ_TWO.BILL;

-- PAT-14 | DATABASE USER: USER_PATIENT13_P2
SELECT * FROM PROJ_TWO.VIEW_PATIENT_PORTAL;

-- PAT-15 | DATABASE USER: USER_PATIENT13_P2
SELECT * FROM PROJ_TWO.VIEW_PATIENT_PORTAL_PATIENT;

-- PAT-16 | DATABASE USER: USER_PATIENT13_P2
SELECT * FROM PROJ_TWO.VIEW_PATIENT_PORTAL_APPOINTMENT;

-- PAT-17 | DATABASE USER: USER_PATIENT13_P2
SELECT * FROM PROJ_TWO.VIEW_PATIENT_PORTAL_ADMISSION;

-- PAT-18 | DATABASE USER: USER_PATIENT13_P2
SELECT * FROM PROJ_TWO.VIEW_PATIENT_PORTAL_PRESCRIPTION;

-- PAT-19 | DATABASE USER: USER_PATIENT13_P2
SELECT * FROM PROJ_TWO.VIEW_PATIENT_PORTAL_DISPENSING;

-- PAT-20 | DATABASE USER: USER_PATIENT13_P2
SELECT * FROM PROJ_TWO.VIEW_PATIENT_PORTAL_BILL;

-- PAT-21 | DATABASE USER: USER_PATIENT13_P2
SELECT * FROM PROJ_TWO.PATIENT;

-- PAT-22 | DATABASE USER: USER_PATIENT13_P2
SELECT * FROM PROJ_TWO.APPOINTMENT;

-- PAT-23 | DATABASE USER: USER_PATIENT13_P2
SELECT * FROM PROJ_TWO.ADMISSION;

-- PAT-24 | DATABASE USER: USER_PATIENT13_P2
SELECT * FROM PROJ_TWO.PRESCRIPTION;

-- PAT-25 | DATABASE USER: USER_PATIENT13_P2
SELECT * FROM PROJ_TWO.DISPENSING;

-- PAT-26 | DATABASE USER: USER_PATIENT13_P2
SELECT * FROM PROJ_TWO.BILL;

-- PAT-27 | DATABASE USER: USER_PATIENT25_P2
SELECT * FROM PROJ_TWO.VIEW_PATIENT_PORTAL;

-- PAT-28 | DATABASE USER: USER_PATIENT13_P2
INSERT INTO PROJ_TWO.PATIENT (NAME, DOB, ORACLE_USERNAME, IS_VIP, OLS_LABEL) SELECT 'Permission Test', DATE '1995-05-20', 'USER_PATIENT13_P2', 0, 1000 FROM DUAL WHERE 1=0;

-- PAT-29 | DATABASE USER: USER_PATIENT13_P2
UPDATE PROJ_TWO.PATIENT SET PHONE = '99999999' WHERE 1=0;

-- PAT-30 | DATABASE USER: USER_PATIENT13_P2
DELETE FROM PROJ_TWO.PATIENT WHERE 1=0;

-- ======================================================================
-- DOCTOR
-- ======================================================================

-- DOC-01 | DATABASE USER: USER_DOCTOR1_P2
-- Create a prescription for Doctor 1 and Patient 21 using owned appointment 16, then verify rollback.
DECLARE
v_medication VARCHAR2(200) := 'INSERT TEST ' || RAWTOHEX(SYS_GUID());
v_prescription_id NUMBER;
v_count NUMBER;
BEGIN
 SAVEPOINT test_case_start;
 IF SYS_CONTEXT('USERENV', 'SESSION_USER') NOT IN ('USER_DOCTOR1_P2') THEN
 RAISE_APPLICATION_ERROR(-20990, 'Use the login listed for this case.');
 END IF;
PROJ_TWO.CREATE_PRESCRIPTION(16, v_medication, 'Temporary test dosage');
SELECT prescription_id INTO v_prescription_id
FROM PROJ_TWO.PRESCRIPTION
WHERE appointment_id = 16 AND medication = v_medication
 AND doctor_id = 1 AND patient_id = 21 AND status = 'Pending'
 AND LABEL_TO_CHAR(ols_label) = 'C:PHARM:PHARMACY,PATIENT_01';
ROLLBACK TO test_case_start;
SELECT COUNT(*) INTO v_count FROM PROJ_TWO.PRESCRIPTION
WHERE prescription_id = v_prescription_id;
IF v_count <> 0 THEN
 RAISE_APPLICATION_ERROR(-20990, 'Test prescription remains after rollback.');
END IF;
DBMS_OUTPUT.PUT_LINE('PASS DOC-01: Created and rolled back.');
 ROLLBACK TO test_case_start;
EXCEPTION
 WHEN OTHERS THEN
 ROLLBACK TO test_case_start;
 RAISE;
END;
/

-- DOC-02 | DATABASE USER: USER_DOCTOR1_P2
DECLARE
 v_appointment_id NUMBER;
 v_patient_id NUMBER;
 v_prescription_id NUMBER;
 v_remaining NUMBER;
 v_medication VARCHAR2(200) := 'ALT RX TEST ' || RAWTOHEX(SYS_GUID());
 v_dosage VARCHAR2(50) := '10 mg once daily';
BEGIN
 SAVEPOINT test_case_start;
 IF SYS_CONTEXT('USERENV', 'SESSION_USER') <> 'USER_DOCTOR1_P2' THEN
 RAISE_APPLICATION_ERROR(-20990, 'Use the login listed for this case.');
 END IF;

 SELECT MIN(appointment_id) INTO v_appointment_id
 FROM PROJ_TWO.APPOINTMENT
 WHERE doctor_id = 1 AND appointment_id <> 16;

 IF v_appointment_id IS NULL THEN
 DBMS_OUTPUT.PUT_LINE('SKIP: No other visible appointment for Doctor 1.');
 RETURN;
 END IF;

 SELECT patient_id INTO v_patient_id
 FROM PROJ_TWO.APPOINTMENT
 WHERE appointment_id = v_appointment_id;

 PROJ_TWO.CREATE_PRESCRIPTION(v_appointment_id, v_medication, v_dosage);

 SELECT prescription_id INTO v_prescription_id
 FROM PROJ_TWO.PRESCRIPTION
 WHERE appointment_id = v_appointment_id AND doctor_id = 1
 AND patient_id = v_patient_id AND medication = v_medication
 AND dosage = v_dosage AND status = 'Pending';

 ROLLBACK TO test_case_start;
 SELECT COUNT(*) INTO v_remaining
 FROM PROJ_TWO.PRESCRIPTION
 WHERE prescription_id = v_prescription_id;
 IF v_remaining <> 0 THEN
 RAISE_APPLICATION_ERROR(-20990, 'Test prescription remains after rollback.');
 END IF;
 DBMS_OUTPUT.PUT_LINE('PASS DOC-02');
EXCEPTION
 WHEN OTHERS THEN
 ROLLBACK TO test_case_start;
 RAISE;
END;
/

-- DOC-03 | DATABASE USER: USER_DOCTOR1_P2
-- Edit the doctor's own visible Pending prescription 22.
DECLARE
v_count NUMBER;
BEGIN
 SAVEPOINT test_case_start;
 IF SYS_CONTEXT('USERENV', 'SESSION_USER') NOT IN ('USER_DOCTOR1_P2') THEN
 RAISE_APPLICATION_ERROR(-20990, 'Use the login listed for this case.');
 END IF;
SELECT COUNT(*) INTO v_count FROM PROJ_TWO.PRESCRIPTION
WHERE prescription_id = 22 AND doctor_id = 1 AND status = 'Pending';
IF v_count <> 1 THEN
 DBMS_OUTPUT.PUT_LINE('SKIP: Prescription 22 must be visible and Pending.');
 RETURN;
END IF;

PROJ_TWO.EDIT_PRESCRIPTION(22, 'TEST medication', 'TEST dosage');
SELECT COUNT(*) INTO v_count FROM PROJ_TWO.PRESCRIPTION
WHERE prescription_id = 22 AND medication = 'TEST medication'
 AND dosage = 'TEST dosage' AND status = 'Pending';
IF v_count <> 1 THEN RAISE_APPLICATION_ERROR(-20990, 'Edit verification failed.'); END IF;
DBMS_OUTPUT.PUT_LINE('PASS DOC-03');
 ROLLBACK TO test_case_start;
EXCEPTION
 WHEN OTHERS THEN
 ROLLBACK TO test_case_start;
 RAISE;
END;
/

-- DOC-04 | DATABASE USER: USER_DOCTOR1_P2
-- Cancel the doctor's own visible Pending prescription 22.
DECLARE
v_count NUMBER;
BEGIN
 SAVEPOINT test_case_start;
 IF SYS_CONTEXT('USERENV', 'SESSION_USER') NOT IN ('USER_DOCTOR1_P2') THEN
 RAISE_APPLICATION_ERROR(-20990, 'Use the login listed for this case.');
 END IF;
SELECT COUNT(*) INTO v_count FROM PROJ_TWO.PRESCRIPTION
WHERE prescription_id = 22 AND doctor_id = 1 AND status = 'Pending';
IF v_count <> 1 THEN
 DBMS_OUTPUT.PUT_LINE('SKIP: Prescription 22 must be visible and Pending.');
 RETURN;
END IF;

PROJ_TWO.CANCEL_PRESCRIPTION(22);
SELECT COUNT(*) INTO v_count FROM PROJ_TWO.PRESCRIPTION
WHERE prescription_id = 22 AND status = 'Cancelled'
 AND REGEXP_SUBSTR(LABEL_TO_CHAR(ols_label), '^[^:]+') = 'R';
IF v_count <> 1 THEN RAISE_APPLICATION_ERROR(-20990, 'Cancellation or R label verification failed.'); END IF;
DBMS_OUTPUT.PUT_LINE('PASS DOC-04');
 ROLLBACK TO test_case_start;
EXCEPTION
 WHEN OTHERS THEN
 ROLLBACK TO test_case_start;
 RAISE;
END;
/

-- ======================================================================
-- NURSE
-- ======================================================================

-- NUR-01 | DATABASE USER: USER_NURSE2_P2 (NEURO, C)
SELECT * FROM PROJ_TWO.MEDICAL_RECORD;

-- NUR-02 | DATABASE USER: USER_NURSE4_P2 (CARDIOLOGY, C)
SELECT * FROM PROJ_TWO.MEDICAL_RECORD;

-- NUR-03 | DATABASE USER: USER_NURSE2_P2
SELECT * FROM PROJ_TWO.PATIENT;

-- NUR-04 | DATABASE USER: USER_NURSE2_P2
SELECT * FROM PROJ_TWO.PRESCRIPTION;
SELECT * FROM PROJ_TWO.DISPENSING;

-- NUR-05 | DATABASE USER: USER_NURSE2_P2 (C)
SELECT * FROM PROJ_TWO.LAB_RESULT;

-- NUR-06 | DATABASE USER: USER_NURSE1_P2 (Supervisor, R)
SELECT * FROM PROJ_TWO.PATIENT WHERE patient_id = 35;

-- NUR-07 | DATABASE USER: USER_NURSE2_P2 (C)
SELECT * FROM PROJ_TWO.PATIENT WHERE patient_id = 35;

-- NUR-08 | DATABASE USER: USER_NURSE2_P2
-- The sheet only describes this case ("INSERT INTO / UPDATE ..."), so the two
-- statements below are filled in. Expected: ORA-12406 for both.
INSERT INTO PROJ_TWO.MEDICAL_RECORD (patient_id, author_doctor_id, visit_date, diagnosis, clinical_notes)
VALUES (21, 2, SYSDATE, 'NUR-08 test', 'NUR-08 test');
UPDATE PROJ_TWO.MEDICAL_RECORD SET clinical_notes = 'NUR-08 test' WHERE record_id = 1;
ROLLBACK;

-- ======================================================================
-- PHARMACIST
-- ======================================================================

-- PHARM-01 | DATABASE USER: USER_PHARMACIST2_P2
-- Run with the configured C session level.
SELECT COUNT(*) AS visible_restricted_rows
FROM PROJ_TWO.PRESCRIPTION
WHERE status IN ('Dispensed', 'Cancelled');

-- PHARM-02 | DATABASE USER: USER_PHARMACIST2_P2
SELECT COUNT(*) AS visible_dispensing_rows
FROM PROJ_TWO.DISPENSING;

-- PHARM-03 | DATABASE USER: USER_PHARMACIST2_P2
-- Dispense Pending prescription 21 with quantity 1. No linked dispensing row may already exist.
DECLARE
v_count NUMBER;
BEGIN
 SAVEPOINT test_case_start;
 IF SYS_CONTEXT('USERENV', 'SESSION_USER') <> 'USER_PHARMACIST2_P2' THEN
 RAISE_APPLICATION_ERROR(-20990, 'Use the login listed for this case.');
 END IF;
SELECT COUNT(*) INTO v_count FROM PROJ_TWO.PRESCRIPTION
WHERE prescription_id = 21 AND status = 'Pending';
IF v_count <> 1 THEN
 DBMS_OUTPUT.PUT_LINE('SKIP: Prescription 21 must be visible and Pending.');
 RETURN;
END IF;
PROJ_TWO.DISPENSE_PRESCRIPTION(21, 1);

SELECT COUNT(*) INTO v_count FROM PROJ_TWO.DISPENSING
WHERE prescription_id = 21 AND medication_quantity = 1 AND status = 'Dispensed'
 AND pharmacist_id = CASE SYS_CONTEXT('USERENV', 'SESSION_USER')
 WHEN 'USER_PHARMACIST1_P2' THEN 1 ELSE 2 END;
IF v_count <> 1 THEN RAISE_APPLICATION_ERROR(-20990, 'Dispensing verification failed.'); END IF;
DBMS_OUTPUT.PUT_LINE('PASS PHARM-03');
 ROLLBACK TO test_case_start;
EXCEPTION
 WHEN OTHERS THEN
 ROLLBACK TO test_case_start;
 RAISE;
END;
/

-- PHARM-04 | DATABASE USER: USER_PHARMACIST2_P2
-- The pharmacist cancels the dispensing row they just created.
DECLARE
v_count NUMBER;
v_dispense_id NUMBER;
BEGIN
 SAVEPOINT test_case_start;
 IF SYS_CONTEXT('USERENV', 'SESSION_USER') <> 'USER_PHARMACIST2_P2' THEN
 RAISE_APPLICATION_ERROR(-20990, 'Use the login listed for this case.');
 END IF;
SELECT COUNT(*) INTO v_count FROM PROJ_TWO.PRESCRIPTION
WHERE prescription_id = 21 AND status = 'Pending';
IF v_count <> 1 THEN
 DBMS_OUTPUT.PUT_LINE('SKIP: Prescription 21 must be visible and Pending.');
 RETURN;
END IF;
PROJ_TWO.DISPENSE_PRESCRIPTION(21, 1);

SELECT dispense_id INTO v_dispense_id FROM PROJ_TWO.DISPENSING
WHERE prescription_id = 21;

PROJ_TWO.UPDATE_DISPENSING_STATUS(v_dispense_id, 'Cancelled');
SELECT COUNT(*) INTO v_count FROM PROJ_TWO.DISPENSING
WHERE dispense_id = v_dispense_id AND status = 'Cancelled';
IF v_count <> 1 THEN RAISE_APPLICATION_ERROR(-20990, 'Cancellation verification failed.'); END IF;
DBMS_OUTPUT.PUT_LINE('PASS PHARM-04');
 ROLLBACK TO test_case_start;
EXCEPTION
 WHEN OTHERS THEN
 ROLLBACK TO test_case_start;
 RAISE;
END;
/

-- PHARM-05 | DATABASE USER: USER_PHARMACIST1_P2
-- Run with the configured R session level.
SELECT COUNT(*) AS visible_restricted_rows
FROM PROJ_TWO.PRESCRIPTION
WHERE status IN ('Dispensed', 'Cancelled');

-- PHARM-06 | DATABASE USER: USER_PHARMACIST1_P2
SELECT COUNT(*) AS visible_dispensing_rows
FROM PROJ_TWO.DISPENSING;

-- PHARM-07 | DATABASE USER: USER_PHARMACIST1_P2
-- Dispense Pending prescription 21 with quantity 2. No linked dispensing row may already exist.
DECLARE
v_count NUMBER;
BEGIN
 SAVEPOINT test_case_start;
 IF SYS_CONTEXT('USERENV', 'SESSION_USER') <> 'USER_PHARMACIST1_P2' THEN
 RAISE_APPLICATION_ERROR(-20990, 'Use the login listed for this case.');
 END IF;
SELECT COUNT(*) INTO v_count FROM PROJ_TWO.PRESCRIPTION
WHERE prescription_id = 21 AND status = 'Pending';
IF v_count <> 1 THEN
 DBMS_OUTPUT.PUT_LINE('SKIP: Prescription 21 must be visible and Pending.');
 RETURN;
END IF;
PROJ_TWO.DISPENSE_PRESCRIPTION(21, 2);

SELECT COUNT(*) INTO v_count FROM PROJ_TWO.DISPENSING
WHERE prescription_id = 21 AND medication_quantity = 2 AND status = 'Dispensed'
 AND pharmacist_id = CASE SYS_CONTEXT('USERENV', 'SESSION_USER')
 WHEN 'USER_PHARMACIST1_P2' THEN 1 ELSE 2 END;
IF v_count <> 1 THEN RAISE_APPLICATION_ERROR(-20990, 'Dispensing verification failed.'); END IF;
DBMS_OUTPUT.PUT_LINE('PASS PHARM-07');
 ROLLBACK TO test_case_start;
EXCEPTION
 WHEN OTHERS THEN
 ROLLBACK TO test_case_start;
 RAISE;
END;
/

-- PHARM-08 | DATABASE USER: USER_PHARMACIST1_P2
-- The pharmacist cancels the dispensing row they just created.
DECLARE
v_count NUMBER;
v_dispense_id NUMBER;
BEGIN
 SAVEPOINT test_case_start;
 IF SYS_CONTEXT('USERENV', 'SESSION_USER') <> 'USER_PHARMACIST1_P2' THEN
 RAISE_APPLICATION_ERROR(-20990, 'Use the login listed for this case.');
 END IF;
SELECT COUNT(*) INTO v_count FROM PROJ_TWO.PRESCRIPTION
WHERE prescription_id = 21 AND status = 'Pending';
IF v_count <> 1 THEN
 DBMS_OUTPUT.PUT_LINE('SKIP: Prescription 21 must be visible and Pending.');
 RETURN;
END IF;
PROJ_TWO.DISPENSE_PRESCRIPTION(21, 1);

SELECT dispense_id INTO v_dispense_id FROM PROJ_TWO.DISPENSING
WHERE prescription_id = 21;

PROJ_TWO.UPDATE_DISPENSING_STATUS(v_dispense_id, 'Cancelled');
SELECT COUNT(*) INTO v_count FROM PROJ_TWO.DISPENSING
WHERE dispense_id = v_dispense_id AND status = 'Cancelled';
IF v_count <> 1 THEN RAISE_APPLICATION_ERROR(-20990, 'Cancellation verification failed.'); END IF;
DBMS_OUTPUT.PUT_LINE('PASS PHARM-08');
 ROLLBACK TO test_case_start;
EXCEPTION
 WHEN OTHERS THEN
 ROLLBACK TO test_case_start;
 RAISE;
END;
/

-- ======================================================================
-- RECEPTIONIST
-- ======================================================================

-- REC-01 | DATABASE USER: USER_RECEPTIONIST1_P2
-- REGISTER_PATIENT_P2 commits and creates an account: use an unused username.
BEGIN
   PROJ_TWO.REGISTER_PATIENT_P2(
       p_sensitivity     => 'C',
       p_name            => 'Test Patienttwelve',
       p_dob             => DATE '1995-05-20',
       p_oracle_username => 'USER_PATIENT26_P2'
   );
END;
/

-- REC-02 | DATABASE USER: USER_RECEPTIONIST1_P2
-- REGISTER_PATIENT_P2 commits and creates an account: use an unused username.
BEGIN
   PROJ_TWO.REGISTER_PATIENT_P2(
       p_sensitivity     => 'R',
       p_name            => 'Test Patienttwelve',
       p_dob             => DATE '1995-05-20',
       p_oracle_username => 'USER_PATIENT27_P2'
   );
END;
/

-- REC-03 | DATABASE USER: USER_RECEPTIONIST2_P2
-- REGISTER_PATIENT_P2 commits and creates an account: use an unused username.
BEGIN
   PROJ_TWO.REGISTER_PATIENT_P2(
       p_sensitivity     => 'R',
       p_name            => 'Test Patienttwelve',
       p_dob             => DATE '1995-05-20',
       p_oracle_username => 'USER_PATIENT27_P2'
   );
END;
/

-- REC-04 | DATABASE USER: USER_RECEPTIONIST2_P2
-- REGISTER_PATIENT_P2 commits and creates an account: use an unused username.
BEGIN
   PROJ_TWO.REGISTER_PATIENT_P2(
       p_sensitivity     => 'C',
       p_name            => 'Test Patienttwelve',
       p_dob             => DATE '1995-05-20',
       p_oracle_username => 'USER_PATIENT27_P2'
   );
END;
/

-- ======================================================================
-- BILLING
-- ======================================================================

-- BILL-01 | DATABASE USER: USER_BILLING1_P2
SELECT bill_id, admission_id, amount, status
FROM PROJ_TWO.BILL
WHERE bill_id = 2;

-- BILL-02 | DATABASE USER: USER_BILLING1_P2
SELECT bill_id, admission_id, amount, status
FROM PROJ_TWO.BILL
WHERE bill_id = 1;

-- BILL-03 | DATABASE USER: USER_BILLING1_P2
-- Create an admission bill using a visible admission.
DECLARE
v_admission_id NUMBER;
v_count NUMBER;
BEGIN
 SAVEPOINT test_case_start;
 IF SYS_CONTEXT('USERENV', 'SESSION_USER') NOT IN ('USER_BILLING1_P2') THEN
 RAISE_APPLICATION_ERROR(-20990, 'Use the login listed for this case.');
 END IF;
SELECT MIN(a.admission_id) INTO v_admission_id
FROM PROJ_TWO.ADMISSION a
WHERE NOT EXISTS (SELECT 1 FROM PROJ_TWO.BILL b
 WHERE b.admission_id = a.admission_id AND b.amount = 123.45);
IF v_admission_id IS NULL THEN
 DBMS_OUTPUT.PUT_LINE('SKIP: No visible admission suitable for a test bill.');
 RETURN;
END IF;

PROJ_TWO.CREATE_ADMISSION_BILL(v_admission_id, 123.45);
SELECT COUNT(*) INTO v_count FROM PROJ_TWO.BILL b
JOIN PROJ_TWO.ADMISSION a ON a.admission_id = b.admission_id
WHERE b.admission_id = v_admission_id AND b.patient_id = a.patient_id
 AND b.amount = 123.45 AND b.status = 'Open';
IF v_count <> 1 THEN RAISE_APPLICATION_ERROR(-20990, 'Bill creation verification failed.'); END IF;
DBMS_OUTPUT.PUT_LINE('PASS BILL-03');
 ROLLBACK TO test_case_start;
EXCEPTION
 WHEN OTHERS THEN
 ROLLBACK TO test_case_start;
 RAISE;
END;
/

-- BILL-04 | DATABASE USER: USER_BILLING1_P2
-- Create an admission bill for 87.65.
DECLARE
v_admission_id NUMBER;
v_count NUMBER;
BEGIN
 SAVEPOINT test_case_start;
 IF SYS_CONTEXT('USERENV', 'SESSION_USER') NOT IN ('USER_BILLING1_P2') THEN
 RAISE_APPLICATION_ERROR(-20990, 'Use the login listed for this case.');
 END IF;
SELECT MIN(a.admission_id) INTO v_admission_id
FROM PROJ_TWO.ADMISSION a
WHERE NOT EXISTS (SELECT 1 FROM PROJ_TWO.BILL b
 WHERE b.admission_id = a.admission_id AND b.amount = 87.65);
IF v_admission_id IS NULL THEN
 DBMS_OUTPUT.PUT_LINE('SKIP: No visible admission suitable for a test bill.');
 RETURN;
END IF;

PROJ_TWO.CREATE_ADMISSION_BILL(v_admission_id, 87.65);
SELECT COUNT(*) INTO v_count FROM PROJ_TWO.BILL b
JOIN PROJ_TWO.ADMISSION a ON a.admission_id = b.admission_id
WHERE b.admission_id = v_admission_id AND b.patient_id = a.patient_id
 AND b.amount = 87.65 AND b.status = 'Open';
IF v_count <> 1 THEN RAISE_APPLICATION_ERROR(-20990, 'Bill creation verification failed.'); END IF;
DBMS_OUTPUT.PUT_LINE('PASS BILL-04');
 ROLLBACK TO test_case_start;
EXCEPTION
 WHEN OTHERS THEN
 ROLLBACK TO test_case_start;
 RAISE;
END;
/

-- BILL-05 | DATABASE USER: USER_BILLING1_P2
-- Change the amount of existing Open bill 2.
DECLARE
v_count NUMBER;
BEGIN
 SAVEPOINT test_case_start;
 IF SYS_CONTEXT('USERENV', 'SESSION_USER') NOT IN ('USER_BILLING1_P2') THEN
 RAISE_APPLICATION_ERROR(-20990, 'Use the login listed for this case.');
 END IF;
SELECT COUNT(*) INTO v_count FROM PROJ_TWO.BILL
WHERE bill_id = 2 AND status = 'Open';
IF v_count <> 1 THEN
 DBMS_OUTPUT.PUT_LINE('SKIP: Bill 2 must be visible and Open.');
 RETURN;
END IF;

PROJ_TWO.UPDATE_BILL(2, 135.50, 'Open');
SELECT COUNT(*) INTO v_count FROM PROJ_TWO.BILL
WHERE bill_id = 2 AND amount = 135.50 AND status = 'Open';
IF v_count <> 1 THEN RAISE_APPLICATION_ERROR(-20990, 'Bill edit verification failed.'); END IF;
DBMS_OUTPUT.PUT_LINE('PASS BILL-05');
 ROLLBACK TO test_case_start;
EXCEPTION
 WHEN OTHERS THEN
 ROLLBACK TO test_case_start;
 RAISE;
END;
/

-- BILL-06 | DATABASE USER: USER_BILLING1_P2
-- Mark Open bill 2 Paid with NULL amount.
DECLARE
v_count NUMBER;
v_amount NUMBER;
BEGIN
 SAVEPOINT test_case_start;
 IF SYS_CONTEXT('USERENV', 'SESSION_USER') NOT IN ('USER_BILLING1_P2') THEN
 RAISE_APPLICATION_ERROR(-20990, 'Use the login listed for this case.');
 END IF;
SELECT COUNT(*) INTO v_count FROM PROJ_TWO.BILL
WHERE bill_id = 2 AND status = 'Open';
IF v_count <> 1 THEN
 DBMS_OUTPUT.PUT_LINE('SKIP: Bill 2 must be visible and Open.');
 RETURN;
END IF;

SELECT amount INTO v_amount FROM PROJ_TWO.BILL WHERE bill_id = 2;
PROJ_TWO.UPDATE_BILL(2, NULL, 'Paid');
SELECT COUNT(*) INTO v_count FROM PROJ_TWO.BILL
WHERE bill_id = 2 AND amount = v_amount AND status = 'Paid';
IF v_count <> 1 THEN RAISE_APPLICATION_ERROR(-20990, 'Payment verification failed.'); END IF;
DBMS_OUTPUT.PUT_LINE('PASS BILL-06');
 ROLLBACK TO test_case_start;
EXCEPTION
 WHEN OTHERS THEN
 ROLLBACK TO test_case_start;
 RAISE;
END;
/
