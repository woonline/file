%macro select_samples(
    highrisk_ds=,      /* High-risk population dataset */
    context_ds=,       /* Context-based population dataset */
    context_var=,      /* Subcategory variable in context dataset */
    lowrisk1_ds=,      /* Low-risk1 population dataset */
    lowrisk2_ds=,      /* Low-risk2 population dataset */
    output_ds=,        /* Output dataset name */
    seed=12345,        /* Random seed for reproducibility */
    lms_weight=75,     /* LMS subcategory weight (%) */
    sn_weight=15       /* SN subcategory weight (%) */
);

/* Validate context variable exists */
%if %sysfunc(varnum(&syslast,&context_var)) = 0 %then %do;
    %put ERROR: Variable &context_var not found in &context_ds;
    %abort;
%end;

/* Calculate maximum high-risk samples */
proc sql noprint;
    select count(*) into :hr_total from &highrisk_ds;
    select min(25, &hr_total) into :hr_sample from &highrisk_ds;
quit;

/* Calculate remaining capacity */
%let remaining = %eval(65 - &hr_sample);

/* Calculate weighted distribution for remaining slots */
%let total_weight = 105; /* 75 + 25 + 5 */
%let ctx_weight = 75;
%let lr1_weight = 25;
%let lr2_weight = 5;

proc sql noprint;
    /* Get population counts */
    select count(*) into :ctx_total from &context_ds;
    select count(*) into :lr1_total from &lowrisk1_ds;
    select count(*) into :lr2_total from &lowrisk2_ds;
    
    /* Calculate initial allocation */
    select 
        floor(&remaining * &ctx_weight/&total_weight),
        floor(&remaining * &lr1_weight/&total_weight),
        floor(&remaining * &lr2_weight/&total_weight)
    into
        :ctx_alloc, :lr1_alloc, :lr2_alloc
    from &context_ds(obs=1);
quit;

/* ========== ENHANCED CONTEXT-BASED SAMPLING ========== */
%if &ctx_alloc > 0 %then %do;
    /* Get subcategory counts */
    proc sql noprint;
        select count(*) into :lms_count from &context_ds 
            where upcase(&context_var) = 'LMS';
        select count(*) into :sn_count from &context_ds 
            where upcase(&context_var) = 'SN';
        select count(*) into :other_count from &context_ds 
            where upcase(&context_var) not in ('LMS', 'SN');
    quit;

    /* Calculate subcategory allocations */
    %let lms_alloc = %sysevalf(&ctx_alloc * &lms_weight/100, floor);
    %let sn_alloc = %sysevalf(&ctx_alloc * &sn_weight/100, floor);
    %let other_alloc = %eval(&ctx_alloc - &lms_alloc - &sn_alloc);

    /* Adjust for available records */
    %let actual_lms = %sysfunc(min(&lms_alloc, &lms_count));
    %let actual_sn = %sysfunc(min(&sn_alloc, &sn_count));
    %let actual_other = %sysfunc(min(&other_alloc, &other_count));
    
    /* Redistribution logic */
    %let ctx_shortfall = %eval(&ctx_alloc - (&actual_lms + &actual_sn + &actual_other));
    %if &ctx_shortfall > 0 %then %do;
        %let redist_lms = %sysfunc(min(&ctx_shortfall, %eval(&lms_count - &actual_lms)));
        %let actual_lms = %eval(&actual_lms + &redist_lms);
        %let ctx_shortfall = %eval(&ctx_shortfall - &redist_lms);
        
        %if &ctx_shortfall > 0 %then %do;
            %let redist_sn = %sysfunc(min(&ctx_shortfall, %eval(&sn_count - &actual_sn)));
            %let actual_sn = %eval(&actual_sn + &redist_sn);
            %let ctx_shortfall = %eval(&ctx_shortfall - &redist_sn);
        %end;
        
        %if &ctx_shortfall > 0 %then %do;
            %let redist_other = %sysfunc(min(&ctx_shortfall, %eval(&other_count - &actual_other)));
            %let actual_other = %eval(&actual_other + &redist_other);
        %end;
    %end;

    /* Perform stratified sampling */
    %if &actual_lms > 0 %then %do;
        proc surveyselect data=&context_ds(where=(upcase(&context_var)='LMS')) 
            method=srs sampsize=&actual_lms out=ctx_lms seed=&seed noprint;
        run;
    %end;
    
    %if &actual_sn > 0 %then %do;
        proc surveyselect data=&context_ds(where=(upcase(&context_var)='SN')) 
            method=srs sampsize=&actual_sn out=ctx_sn seed=&seed noprint;
        run;
    %end;
    
    %if &actual_other > 0 %then %do;
        proc surveyselect data=&context_ds(where=(upcase(&context_var) not in ('LMS', 'SN'))) 
            method=srs sampsize=&actual_other out=ctx_other seed=&seed noprint;
        run;
    %end;

    /* Combine context samples */
    data ctx_sample;
        set 
            %if &actual_lms > 0 %then %do; ctx_lms %end;
            %if &actual_sn > 0 %then %do; ctx_sn %end;
            %if &actual_other > 0 %then %do; ctx_other %end;
        ;
    run;
%end;

/* ========== LOW-RISK SAMPLING (REMAINS SAME) ========== */
/* ... (maintain existing low-risk sampling logic) ... */

/* Combine all samples */
data &output_ds;
    set 
        hr_sample
        %if &ctx_alloc > 0 %then %do; ctx_sample %end;
        %if &lr1_sample > 0 %then %do; lr1_sample %end;
        %if &lr2_sample > 0 %then %do; lr2_sample %end;
    ;
run;

proc datasets library=work nolist;
    delete hr_sample ctx_sample lr1_sample lr2_sample 
           ctx_lms ctx_sn ctx_other;
quit;

%mend select_samples;

%select_samples(
    highrisk_ds=high_risk_pop,
    context_ds=context_pop,
    context_var=risk_category,
    lowrisk1_ds=low_risk1,
    lowrisk2_ds=low_risk2,
    output_ds=final_sample,
    seed=20231115,
    lms_weight=78,   /* Override default 75% */
    sn_weight=12
);



proc sql;
    select 'High Risk' as category, count(*) as count from hr_sample
    union
    select 'Context LMS', count(*) from ctx_lms
    union
    select 'Context SN', count(*) from ctx_sn
    union
    select 'Context Other', count(*) from ctx_other
    union
    select 'Low Risk1', count(*) from lr1_sample
    union
    select 'Low Risk2', count(*) from lr2_sample;
quit;
