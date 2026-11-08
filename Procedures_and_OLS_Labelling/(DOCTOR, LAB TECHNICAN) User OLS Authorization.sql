



/* =====================================================================
   CONFIGURE DOCTOR OLS AUTHORIZATION
   ===================================================================== */

BEGIN
    -- Doctor 1: Neuro Department Head (R)
    SA_USER_ADMIN.SET_USER_LABELS(
        policy_name     => 'HOSPITAL_POL',
        user_name       => 'USER_DOCTOR1_P2',
        max_read_label  => 'R:ADMIN,CLINICAL,LAB,PHARM:ADMINISTRATION,NEURO,LAB_SERVICES,PHARMACY',
        max_write_label => 'R:CLINICAL,LAB,PHARM:NEURO,LAB_SERVICES,PHARMACY',
        min_write_label => 'C',
        def_label       => 'R:ADMIN,CLINICAL,LAB,PHARM:ADMINISTRATION,NEURO,LAB_SERVICES,PHARMACY',
        row_label       => 'C:CLINICAL:NEURO'
    );

    -- Doctor 2: Neuro (C)
    SA_USER_ADMIN.SET_USER_LABELS(
        policy_name     => 'HOSPITAL_POL',
        user_name       => 'USER_DOCTOR2_P2',
        max_read_label  => 'C:ADMIN,CLINICAL,LAB,PHARM:ADMINISTRATION,NEURO,LAB_SERVICES,PHARMACY',
        max_write_label => 'C:CLINICAL,LAB,PHARM:NEURO,LAB_SERVICES,PHARMACY',
        min_write_label => 'C',
        def_label       => 'C:ADMIN,CLINICAL,LAB,PHARM:ADMINISTRATION,NEURO,LAB_SERVICES,PHARMACY', 
        row_label       => 'C:CLINICAL:NEURO'
    );

    -- Doctor 3: Cardiology Department Head (R)
    SA_USER_ADMIN.SET_USER_LABELS(
        policy_name     => 'HOSPITAL_POL',
        user_name       => 'USER_DOCTOR3_P2',
        max_read_label  => 'R:ADMIN,CLINICAL,LAB,PHARM:ADMINISTRATION,CARDIOLOGY,LAB_SERVICES,PHARMACY',
        max_write_label => 'R:CLINICAL,LAB,PHARM:CARDIOLOGY,LAB_SERVICES,PHARMACY',
        min_write_label => 'C',
        def_label       => 'R:ADMIN,CLINICAL,LAB,PHARM:ADMINISTRATION,CARDIOLOGY,LAB_SERVICES,PHARMACY',
        row_label       => 'C:CLINICAL:CARDIOLOGY'
    );

    -- Doctor 4: Cardiology (C)
    SA_USER_ADMIN.SET_USER_LABELS(
        policy_name     => 'HOSPITAL_POL',
        user_name       => 'USER_DOCTOR4_P2',
        max_read_label  => 'C:ADMIN,CLINICAL,LAB,PHARM:ADMINISTRATION,CARDIOLOGY,LAB_SERVICES,PHARMACY',
        max_write_label => 'C:CLINICAL,LAB,PHARM:CARDIOLOGY,LAB_SERVICES,PHARMACY',
        min_write_label => 'C',
        def_label       => 'C:ADMIN,CLINICAL,LAB,PHARM:ADMINISTRATION,CARDIOLOGY,LAB_SERVICES,PHARMACY', 
        row_label       => 'C:CLINICAL:CARDIOLOGY'
    );

    -- Doctor 5: General Medicine Department Head (R)
    SA_USER_ADMIN.SET_USER_LABELS(
        policy_name     => 'HOSPITAL_POL',
        user_name       => 'USER_DOCTOR5_P2',
        max_read_label  => 'R:ADMIN,CLINICAL,LAB,PHARM:ADMINISTRATION,GENERAL_MED,LAB_SERVICES,PHARMACY',
        max_write_label => 'R:CLINICAL,LAB,PHARM:GENERAL_MED,LAB_SERVICES,PHARMACY',
        min_write_label => 'C',
        def_label       => 'R:ADMIN,CLINICAL,LAB,PHARM:ADMINISTRATION,GENERAL_MED,LAB_SERVICES,PHARMACY',
        row_label       => 'C:CLINICAL:GENERAL_MED'
    );

    -- Doctor 6: General Medicine (C)
    SA_USER_ADMIN.SET_USER_LABELS(
        policy_name     => 'HOSPITAL_POL',
        user_name       => 'USER_DOCTOR6_P2',
        max_read_label  => 'C:ADMIN,CLINICAL,LAB,PHARM:ADMINISTRATION,GENERAL_MED,LAB_SERVICES,PHARMACY',
        max_write_label => 'C:CLINICAL,LAB,PHARM:GENERAL_MED,LAB_SERVICES,PHARMACY',
        min_write_label => 'C',
        def_label       => 'C:ADMIN,CLINICAL,LAB,PHARM:ADMINISTRATION,GENERAL_MED,LAB_SERVICES,PHARMACY',  
        row_label       => 'C:CLINICAL:GENERAL_MED'
    );
END;
/

/* =====================================================================
   CONFIGURE LAB TECHNICIAN OLS AUTHORIZATION
   ===================================================================== */   
BEGIN
    -- Lab Tech 1: Clinical Chemistry Supervisor (R)
    SA_USER_ADMIN.SET_USER_LABELS(
        policy_name     => 'HOSPITAL_POL',
        user_name       => 'USER_LAB_TECH1_P2',
        max_read_label  => 'R:LAB:CLIN_CHEM',
        max_write_label => 'R:LAB:CLIN_CHEM',
        min_write_label => 'C',
        def_label       => 'R:LAB:CLIN_CHEM',
        row_label       => 'C:LAB:CLIN_CHEM' 
    );

    -- Lab Tech 2: Clinical Chemistry (C)
    SA_USER_ADMIN.SET_USER_LABELS(
        policy_name     => 'HOSPITAL_POL',
        user_name       => 'USER_LAB_TECH2_P2',
        max_read_label  => 'C:LAB:CLIN_CHEM',
        max_write_label => 'C:LAB:CLIN_CHEM',
        min_write_label => 'C',
        def_label       => 'C:LAB:CLIN_CHEM',
        row_label       => 'C:LAB:CLIN_CHEM'
    );

    -- Lab Tech 3: Microbiology Supervisor (R)
    SA_USER_ADMIN.SET_USER_LABELS(
        policy_name     => 'HOSPITAL_POL',
        user_name       => 'USER_LAB_TECH3_P2',
        max_read_label  => 'R:LAB:MICROBIO',
        max_write_label => 'R:LAB:MICROBIO',
        min_write_label => 'C',
        def_label       => 'R:LAB:MICROBIO',
        row_label       => 'C:LAB:MICROBIO'
    );

    -- Lab Tech 4: Microbiology (C)
    SA_USER_ADMIN.SET_USER_LABELS(
        policy_name     => 'HOSPITAL_POL',
        user_name       => 'USER_LAB_TECH4_P2',
        max_read_label  => 'C:LAB:MICROBIO',
        max_write_label => 'C:LAB:MICROBIO',
        min_write_label => 'C',
        def_label       => 'C:LAB:MICROBIO',
        row_label       => 'C:LAB:MICROBIO'
    );
END;
/   