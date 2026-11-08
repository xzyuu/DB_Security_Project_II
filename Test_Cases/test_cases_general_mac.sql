-- CS5322 Project 2: general MAC (OLS) test cases
-- Connect as the DATABASE USER of each case in a new session before running it,
-- so the case starts at the user's default session label.

-- MAC-01a | DATABASE USER: USER_PHARMACIST1_P2
SELECT COUNT(*) FROM proj_two.prescription WHERE status IN ('Dispensed','Cancelled');

-- MAC-01b | DATABASE USER: USER_PHARMACIST2_P2
SELECT COUNT(*) FROM proj_two.prescription WHERE status IN ('Dispensed','Cancelled');
SELECT COUNT(*) FROM proj_two.prescription;

-- MAC-02a | DATABASE USER: USER_LAB_TECH1_P2
SELECT COUNT(*) FROM proj_two.lab_result;

-- MAC-02b | DATABASE USER: USER_LAB_TECH2_P2
SELECT COUNT(*) FROM proj_two.lab_result;

-- MAC-03a | DATABASE USER: USER_NURSE1_P2
EXEC SA_SESSION.SET_LABEL('HOSPITAL_POL','C:ADMIN,CLINICAL,LAB,PHARM:NEURO,PHARMACY,CARDIOLOGY,GENERAL_MED,ADMINISTRATION,LAB_SERVICES')
SELECT COUNT(*) FROM proj_two.lab_result;

-- MAC-03b | DATABASE USER: USER_LAB_TECH1_P2
SELECT COUNT(*) FROM proj_two.patient;

-- MAC-04a | DATABASE USER: USER_DOCTOR1_P2
SELECT COUNT(*) FROM proj_two.medical_record;

-- MAC-04b | DATABASE USER: USER_DOCTOR2_P2
SELECT COUNT(*) FROM proj_two.medical_record WHERE ols_label = CHAR_TO_LABEL('HOSPITAL_POL','C:CLINICAL:CARDIOLOGY');

-- MAC-05a | DATABASE USER: USER_PATIENT1_P2
SELECT name FROM proj_two.view_patient_portal_patient;

-- MAC-05b | DATABASE USER: USER_PATIENT2_P2
SELECT COUNT(*) FROM proj_two.view_patient_portal_patient WHERE oracle_username = 'USER_PATIENT1_P2';

-- MAC-06a | DATABASE USER: USER_BILLING1_P2
SELECT COUNT(*) FROM proj_two.bill;

-- MAC-06b | DATABASE USER: USER_PATIENT1_P2
SELECT COUNT(*) FROM proj_two.view_patient_portal_bill;

-- MAC-07a | DATABASE USER: USER_BILLING1_P2
SELECT COUNT(*) FROM proj_two.patient WHERE patient_id <= 35;
EXEC SA_SESSION.SET_LABEL('HOSPITAL_POL','R:ADMIN,FIN:ADMINISTRATION')
SELECT COUNT(*) FROM proj_two.patient WHERE patient_id <= 35;

-- MAC-07b | DATABASE USER: USER_BILLING2_P2
EXEC SA_SESSION.SET_LABEL('HOSPITAL_POL','R:ADMIN,FIN:ADMINISTRATION')
SELECT COUNT(*) FROM proj_two.patient WHERE patient_id <= 35;

-- MAC-08a | DATABASE USER: USER_RECEPTIONIST1_P2
SELECT COUNT(*) FROM proj_two.ward;

-- MAC-08b | DATABASE USER: USER_NURSE1_P2
SELECT COUNT(*) FROM proj_two.ward;

-- MAC-08c | DATABASE USER: USER_RECEPTIONIST1_P2
SELECT COUNT(*) FROM proj_two.nurse_ward_assignment;

-- MAC-09a | DATABASE USER: USER_RECEPTIONIST1_P2
UPDATE proj_two.room SET status = 'Maintenance' WHERE room_id = 2;
SELECT status || ' ' || LABEL_TO_CHAR(ols_label) FROM proj_two.room WHERE room_id = 2;
ROLLBACK;

-- MAC-09b | DATABASE USER: USER_RECEPTIONIST1_P2
UPDATE proj_two.room SET room_type = 'Double' WHERE room_id = 2;
ROLLBACK;

-- MAC-10a | DATABASE USER: USER_DOCTOR1_P2
UPDATE proj_two.appointment SET status = status WHERE appointment_id = 1;
ROLLBACK;

-- MAC-10b | DATABASE USER: USER_DOCTOR1_P2
SELECT COUNT(*) FROM proj_two.appointment WHERE appointment_id = 3;
UPDATE proj_two.appointment SET status = status WHERE appointment_id = 3;
ROLLBACK;

-- MAC-11a | DATABASE USER: USER_RECEPTIONIST1_P2
UPDATE proj_two.patient SET phone = phone WHERE patient_id = 35;
ROLLBACK;

-- MAC-11b | DATABASE USER: USER_RECEPTIONIST2_P2
UPDATE proj_two.patient SET phone = phone WHERE patient_id = 35;
ROLLBACK;

-- MAC-12a | DATABASE USER: USER_DOCTOR2_P2
UPDATE proj_two.medical_record SET clinical_notes = 'MAC test' WHERE record_id = 1;
ROLLBACK;

-- MAC-12b | DATABASE USER: USER_DOCTOR2_P2
UPDATE proj_two.medical_record SET clinical_notes = 'MAC test' WHERE record_id = 3;
ROLLBACK;

-- MAC-13a | DATABASE USER: USER_BILLING1_P2
INSERT INTO proj_two.bill (patient_id, admission_id, amount) VALUES (21, 2, 100);
SELECT LABEL_TO_CHAR(ols_label) FROM proj_two.bill WHERE bill_id = (SELECT MAX(bill_id) FROM proj_two.bill);
ROLLBACK;

-- MAC-13b | DATABASE USER: USER_BILLING1_P2
UPDATE proj_two.bill SET ols_label = CHAR_TO_LABEL('HOSPITAL_POL','C:FIN:ADMINISTRATION') WHERE bill_id = 2;
ROLLBACK;

-- MAC-14a | DATABASE USER: USER_DOCTOR2_P2
INSERT INTO proj_two.medical_record (patient_id, author_doctor_id, visit_date, diagnosis, clinical_notes) VALUES (21, 2, SYSDATE, 'MAC test', 'MAC test');
SELECT COUNT(*) FROM proj_two.medical_record WHERE diagnosis = 'MAC test';
ROLLBACK;

-- MAC-14b | DATABASE USER: USER_DOCTOR2_P2
INSERT INTO proj_two.medical_record (patient_id, author_doctor_id, visit_date, diagnosis, clinical_notes) VALUES (23, 4, SYSDATE, 'MAC test', 'MAC test');
ROLLBACK;

-- MAC-15a | DATABASE USER: USER_PHARMACIST1_P2
UPDATE proj_two.prescription SET status = 'Dispensed' WHERE prescription_id = 19;
SELECT LABEL_TO_CHAR(ols_label) FROM proj_two.prescription WHERE prescription_id = 19;
ROLLBACK;

-- MAC-16a | DATABASE USER: USER_LAB_TECH1_P2
EXEC proj_two.release_lab_result(7)
SELECT released_flag || ' ' || LABEL_TO_CHAR(ols_label) FROM proj_two.lab_result WHERE result_id = 7;
ROLLBACK;

-- MAC-16b | DATABASE USER: USER_LAB_TECH2_P2
EXEC proj_two.release_lab_result(7)
ROLLBACK;

-- MAC-17 | DATABASE USER: USER_LAB_TECH1_P2
UPDATE proj_two.lab_result SET released_flag = 1 WHERE result_id = 9;
ROLLBACK;

-- MAC-18e | DATABASE USER: USER_RECEPTIONIST1_P2
INSERT INTO proj_two.admission (patient_id, room_id, admit_date, ols_label) VALUES (29, 3, SYSDATE, CHAR_TO_LABEL('HOSPITAL_POL','C:ADMIN:NEURO,ADMINISTRATION,PATIENT_09'));
ROLLBACK;

-- MAC-18g | DATABASE USER: USER_RECEPTIONIST1_P2
INSERT INTO proj_two.patient (name, dob, phone, oracle_username, ols_label) VALUES ('MAC test', DATE '1990-01-01', '00000000', 'USER_PATIENT99_P2', CHAR_TO_LABEL('HOSPITAL_POL','C:ADMIN:ADMINISTRATION'));
ROLLBACK;

-- MAC-18b | DATABASE USER: USER_RECEPTIONIST1_P2
UPDATE proj_two.admission SET ols_label = CHAR_TO_LABEL('HOSPITAL_POL','C:ADMIN:ADMINISTRATION') WHERE admission_id = 2;
ROLLBACK;

-- MAC-18c | DATABASE USER: USER_DOCTOR1_P2
DESC proj_two.medical_record
DESC proj_two.lab_result

-- MAC-18d | DATABASE USER: PROJ_TWO
INSERT INTO proj_two.ward (department_id, name, location, ols_label) VALUES (1, 'MAC Test Ward', 'Test Wing', CHAR_TO_LABEL('HOSPITAL_POL','C'));
SELECT LABEL_TO_CHAR(ols_label) FROM proj_two.ward WHERE name = 'MAC Test Ward';
ROLLBACK;

-- MAC-19 | DATABASE USER: USER_RECEPTIONIST1_P2
SELECT COUNT(*) FROM proj_two.doctor;

-- MAC-20 | DATABASE USER: USER_PATIENT1_P2
-- Known gap: removed from the final suite; the portal view was dropped.
SELECT COUNT(*) FROM proj_two.view_patient_portal_lab_result;
