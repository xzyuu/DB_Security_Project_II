--Create Views
CREATE OR REPLACE EDITIONABLE VIEW PROJ_TWO.VIEW_PATIENT_PORTAL AS
SELECT
    p.PATIENT_ID      AS PATIENT_PATIENT_ID,
    p.NAME            AS PATIENT_NAME,
    p.DOB             AS PATIENT_DOB,
    p.PHONE           AS PATIENT_PHONE,
    p.ORACLE_USERNAME AS PATIENT_ORACLE_USERNAME,

    -- All visible appointments for this patient.
    NVL(
        (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'SCHEDULED_AT' VALUE a.SCHEDULED_AT,
                    'STATUS'       VALUE a.STATUS
                    NULL ON NULL
                    RETURNING CLOB
                )
                ORDER BY a.SCHEDULED_AT, a.APPOINTMENT_ID
                RETURNING CLOB
            )
            FROM PROJ_TWO.APPOINTMENT a
            WHERE a.PATIENT_ID = p.PATIENT_ID
        ),
        TO_CLOB('[]')
    ) AS APPOINTMENTS,

    -- All visible admissions for this patient.
    NVL(
        (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'ADMIT_DATE'     VALUE ad.ADMIT_DATE,
                    'DISCHARGE_DATE' VALUE ad.DISCHARGE_DATE,
                    'STATUS'         VALUE ad.STATUS
                    NULL ON NULL
                    RETURNING CLOB
                )
                ORDER BY ad.ADMIT_DATE, ad.ADMISSION_ID
                RETURNING CLOB
            )
            FROM PROJ_TWO.ADMISSION ad
            WHERE ad.PATIENT_ID = p.PATIENT_ID
        ),
        TO_CLOB('[]')
    ) AS ADMISSIONS,

    -- Prescriptions linked to this patient's visible appointments.
    NVL(
        (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'MEDICATION' VALUE pr.MEDICATION,
                    'DOSAGE'     VALUE pr.DOSAGE,
                    'STATUS'     VALUE pr.STATUS
                    NULL ON NULL
                    RETURNING CLOB
                )
                ORDER BY pr.PRESCRIPTION_ID
                RETURNING CLOB
            )
            FROM PROJ_TWO.PRESCRIPTION pr
            JOIN PROJ_TWO.APPOINTMENT a
                ON a.APPOINTMENT_ID = pr.APPOINTMENT_ID
               AND a.PATIENT_ID = pr.PATIENT_ID
            WHERE pr.PATIENT_ID = p.PATIENT_ID
        ),
        TO_CLOB('[]')
    ) AS PRESCRIPTIONS,

    -- Dispensing linked through visible prescriptions and appointments.
    NVL(
        (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'DISPENSE_DATE'       VALUE d.DISPENSE_DATE,
                    'MEDICATION_QUANTITY' VALUE d.MEDICATION_QUANTITY,
                    'STATUS'              VALUE d.STATUS
                    NULL ON NULL
                    RETURNING CLOB
                )
                ORDER BY d.DISPENSE_DATE, d.PRESCRIPTION_ID
                RETURNING CLOB
            )
            FROM PROJ_TWO.DISPENSING d
            JOIN PROJ_TWO.PRESCRIPTION pr
                ON pr.PRESCRIPTION_ID = d.PRESCRIPTION_ID
            JOIN PROJ_TWO.APPOINTMENT a
                ON a.APPOINTMENT_ID = pr.APPOINTMENT_ID
               AND a.PATIENT_ID = pr.PATIENT_ID
            WHERE pr.PATIENT_ID = p.PATIENT_ID
        ),
        TO_CLOB('[]')
    ) AS DISPENSING,

    -- Each bill appears once if linked to a visible appointment
    -- or admission belonging to the same patient.
    NVL(
        (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'AMOUNT' VALUE b.AMOUNT,
                    'STATUS' VALUE b.STATUS
                    NULL ON NULL
                    RETURNING CLOB
                )
                ORDER BY b.AMOUNT, b.STATUS
                RETURNING CLOB
            )
            FROM PROJ_TWO.BILL b
            WHERE b.PATIENT_ID = p.PATIENT_ID
              AND (
                  EXISTS (
                      SELECT 1
                      FROM PROJ_TWO.APPOINTMENT a
                      WHERE a.APPOINTMENT_ID = b.APPOINTMENT_ID
                        AND a.PATIENT_ID = b.PATIENT_ID
                  )
                  OR EXISTS (
                      SELECT 1
                      FROM PROJ_TWO.ADMISSION ad
                      WHERE ad.ADMISSION_ID = b.ADMISSION_ID
                        AND ad.PATIENT_ID = b.PATIENT_ID
                  )
              )
        ),
        TO_CLOB('[]')
    ) AS BILLS

FROM PROJ_TWO.PATIENT p
WITH READ ONLY;

CREATE VIEW PROJ_TWO.VIEW_PATIENT_PORTAL_PATIENT AS
SELECT PATIENT_ID, NAME, DOB, PHONE, ORACLE_USERNAME
FROM PROJ_TWO.PATIENT
WITH READ ONLY;

CREATE VIEW PROJ_TWO.VIEW_PATIENT_PORTAL_APPOINTMENT AS
SELECT SCHEDULED_AT, STATUS
FROM PROJ_TWO.APPOINTMENT
WITH READ ONLY;

CREATE VIEW PROJ_TWO.VIEW_PATIENT_PORTAL_ADMISSION AS
SELECT ADMIT_DATE, DISCHARGE_DATE, STATUS
FROM PROJ_TWO.ADMISSION
WITH READ ONLY;

CREATE VIEW PROJ_TWO.VIEW_PATIENT_PORTAL_PRESCRIPTION AS
SELECT MEDICATION, DOSAGE, STATUS
FROM PROJ_TWO.PRESCRIPTION
WITH READ ONLY;

CREATE VIEW PROJ_TWO.VIEW_PATIENT_PORTAL_DISPENSING AS
SELECT DISPENSE_DATE, MEDICATION_QUANTITY, STATUS
FROM PROJ_TWO.DISPENSING
WITH READ ONLY;

CREATE VIEW PROJ_TWO.VIEW_PATIENT_PORTAL_BILL AS
SELECT AMOUNT, STATUS
FROM PROJ_TWO.BILL
WITH READ ONLY;

--GRANT to Views
GRANT SELECT ON PROJ_TWO.VIEW_PATIENT_PORTAL
TO ROLE_PATIENT_P2;

GRANT SELECT ON PROJ_TWO.VIEW_PATIENT_PORTAL_PATIENT TO ROLE_PATIENT_P2;

GRANT SELECT ON PROJ_TWO.VIEW_PATIENT_PORTAL_APPOINTMENT TO ROLE_PATIENT_P2;

GRANT SELECT ON PROJ_TWO.VIEW_PATIENT_PORTAL_ADMISSION TO ROLE_PATIENT_P2;

GRANT SELECT ON PROJ_TWO.VIEW_PATIENT_PORTAL_PRESCRIPTION TO ROLE_PATIENT_P2;

GRANT SELECT ON PROJ_TWO.VIEW_PATIENT_PORTAL_DISPENSING TO ROLE_PATIENT_P2;

GRANT SELECT ON PROJ_TWO.VIEW_PATIENT_PORTAL_BILL TO ROLE_PATIENT_P2;