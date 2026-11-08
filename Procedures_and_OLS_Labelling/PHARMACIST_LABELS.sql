-- Pharmacist OLS authorizations
BEGIN
    LBACSYS.SA_USER_ADMIN.SET_USER_LABELS(
        policy_name     => 'HOSPITAL_POL',
        user_name       => 'USER_PHARMACIST1_P2',
        max_read_label  => 'R:ADMIN,PHARM:PHARMACY',
        max_write_label => 'R:PHARM:PHARMACY',
        min_write_label => 'C',
        def_label       => 'C:ADMIN,PHARM:PHARMACY',
        row_label       => 'C:PHARM:PHARMACY'
    );

    LBACSYS.SA_USER_ADMIN.SET_USER_LABELS(
        policy_name     => 'HOSPITAL_POL',
        user_name       => 'USER_PHARMACIST2_P2',
        max_read_label  => 'C:ADMIN,PHARM:PHARMACY',
        max_write_label => 'C:PHARM:PHARMACY',
        min_write_label => 'C',
        def_label       => 'C:ADMIN,PHARM:PHARMACY',
        row_label       => 'C:PHARM:PHARMACY'
    );
END;
/
