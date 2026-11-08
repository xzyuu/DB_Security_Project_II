-- Pharmacy and billing data labels
DECLARE
    c_policy CONSTANT VARCHAR2(30) := 'HOSPITAL_POL';
    v_tag NUMBER;
    v_group_count PLS_INTEGER := 0;

    PROCEDURE ensure_base_label(p_tag IN NUMBER, p_label IN VARCHAR2) IS
        v_count PLS_INTEGER;
    BEGIN
        SELECT COUNT(*) INTO v_count
        FROM ALL_SA_LABELS
        WHERE policy_name = c_policy AND label = p_label
          AND label_type = 'USER/DATA LABEL';

        IF v_count = 0 THEN
            LBACSYS.SA_LABEL_ADMIN.CREATE_LABEL(c_policy, p_tag, p_label, TRUE);
        END IF;
    END ensure_base_label;
BEGIN
    ensure_base_label(4001, 'C:PHARM:PHARMACY');
    ensure_base_label(4002, 'R:PHARM:PHARMACY');

    v_tag := TO_DATA_LABEL(c_policy, 'C:FIN:ADMINISTRATION');

    FOR patient_group IN (
        SELECT short_name
        FROM ALL_SA_GROUPS
        WHERE policy_name = c_policy
          AND REGEXP_LIKE(short_name, '^PATIENT_[0-9]+$')
        ORDER BY short_name
    ) LOOP
        v_tag := TO_DATA_LABEL(c_policy, 'C:PHARM:PHARMACY,' || patient_group.short_name);
        v_tag := TO_DATA_LABEL(c_policy, 'R:PHARM:PHARMACY,' || patient_group.short_name);
        v_tag := TO_DATA_LABEL(c_policy, 'C:FIN:ADMINISTRATION,' || patient_group.short_name);
        v_tag := TO_DATA_LABEL(c_policy, 'R:FIN:ADMINISTRATION,' || patient_group.short_name);
        v_group_count := v_group_count + 1;
    END LOOP;

    IF v_group_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20025, 'No PATIENT_nn groups are available under HOSPITAL_POL.');
    END IF;
END;
/
