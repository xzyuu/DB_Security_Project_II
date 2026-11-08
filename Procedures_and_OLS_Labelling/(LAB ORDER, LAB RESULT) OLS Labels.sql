


-- =====================================================
-- LAB_ORDER AND LAB_RESULT DATA LABELS
-- =====================================================

BEGIN
    -- Clinical Chemistry: Confidential
    SA_LABEL_ADMIN.CREATE_LABEL(
        policy_name => 'HOSPITAL_POL',
        label_tag   => 3001,
        label_value => 'C:LAB:CLIN_CHEM',
        data_label  => TRUE
    );

    -- Microbiology: Confidential
    SA_LABEL_ADMIN.CREATE_LABEL(
        policy_name => 'HOSPITAL_POL',
        label_tag   => 3002,
        label_value => 'C:LAB:MICROBIO',
        data_label  => TRUE
    );

    -- Clinical Chemistry: Restricted
    SA_LABEL_ADMIN.CREATE_LABEL(
        policy_name => 'HOSPITAL_POL',
        label_tag   => 3003,
        label_value => 'R:LAB:CLIN_CHEM',
        data_label  => TRUE
    );

    -- Microbiology: Restricted
    SA_LABEL_ADMIN.CREATE_LABEL(
        policy_name => 'HOSPITAL_POL',
        label_tag   => 3004,
        label_value => 'R:LAB:MICROBIO',
        data_label  => TRUE
    );
END;
/