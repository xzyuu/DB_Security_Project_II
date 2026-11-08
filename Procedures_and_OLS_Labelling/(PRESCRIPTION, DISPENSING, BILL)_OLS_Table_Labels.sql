-- Pharmacy and billing table policies
DECLARE
    c_policy CONSTANT VARCHAR2(30) := 'HOSPITAL_POL';
    c_schema CONSTANT VARCHAR2(128) := 'PROJ_TWO';
    c_options CONSTANT VARCHAR2(128) :=
        'READ_CONTROL,INSERT_CONTROL,UPDATE_CONTROL,DELETE_CONTROL';

    PROCEDURE apply_policy(p_table IN VARCHAR2, p_function IN VARCHAR2) IS
        v_status VARCHAR2(8);
        v_options VARCHAR2(4000);
        v_function VARCHAR2(1024);
        v_predicate VARCHAR2(4000);
    BEGIN
        BEGIN
            SELECT status, table_options, "FUNCTION", predicate
            INTO v_status, v_options, v_function, v_predicate
            FROM ALL_SA_TABLE_POLICIES
            WHERE policy_name = c_policy AND schema_name = c_schema
              AND table_name = p_table;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                LBACSYS.SA_POLICY_ADMIN.APPLY_TABLE_POLICY(
                    policy_name    => c_policy,
                    schema_name    => c_schema,
                    table_name     => p_table,
                    table_options  => c_options,
                    label_function => p_function,
                    predicate      => NULL
                );
                RETURN;
        END;

        IF NVL(REGEXP_REPLACE(UPPER(v_function), '[[:space:]]'), '?')
           <> REGEXP_REPLACE(UPPER(p_function), '[[:space:]]')
           OR NVL(REGEXP_REPLACE(UPPER(v_options), '[[:space:]]'), '?')
              NOT IN (c_options, 'READ_CONTROL,WRITE_CONTROL')
           OR v_predicate IS NOT NULL THEN
            RAISE_APPLICATION_ERROR(-20027, 'Review the existing OLS attachment on ' || p_table);
        END IF;

        IF v_status = 'DISABLED' THEN
            LBACSYS.SA_POLICY_ADMIN.ENABLE_TABLE_POLICY(c_policy, c_schema, p_table);
        END IF;
    END apply_policy;
BEGIN
    apply_policy(
        'PRESCRIPTION',
        q'[PROJ_TWO.LBL_PHARMACY('PRESCRIPTION',:new.STATUS,:new.PATIENT_ID,NULL)]'
    );
    apply_policy(
        'DISPENSING',
        q'[PROJ_TWO.LBL_PHARMACY('DISPENSING',NULL,NULL,:new.PRESCRIPTION_ID)]'
    );
    apply_policy('BILL', 'PROJ_TWO.LBL_BILL(:new.PATIENT_ID)');
END;
/
