%macro select_samples(
    highrisk_ds=,      /* High-risk population dataset */
    context_ds=,       /* Context-based population dataset */
    lowrisk1_ds=,      /* Low-risk1 population dataset */
    lowrisk2_ds=,      /* Low-risk2 population dataset */
    output_ds=,        /* Output dataset name */
    seed=12345         /* Random seed for reproducibility */
);

/* Step 1: Calculate maximum high-risk samples */
proc sql noprint;
    select count(*) into :hr_total from &highrisk_ds;
    select min(25, &hr_total) into :hr_sample from &highrisk_ds;
quit;

/* Step 2: Calculate remaining capacity */
%let remaining = %eval(65 - &hr_sample);

/* Step 3: Calculate weighted distribution for remaining slots */
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

    /* Calculate remainder */
    %let remainder = %eval(&remaining - (&ctx_alloc + &lr1_alloc + &lr2_alloc));
    
    /* Distribute remainder */
    %if &remainder > 0 %then %do;
        update _allocations
        set ctx_alloc = ctx_alloc + 1
        where mod(&remaining * &ctx_weight, &total_weight) = 
            (select max(mod(&remaining * &ctx_weight, &total_weight),
                        mod(&remaining * &lr1_weight, &total_weight),
                        mod(&remaining * &lr2_weight, &total_weight)));
    %end;
quit;

/* Step 4: Calculate final sample sizes with population caps */
%let ctx_sample = %sysfunc(min(&ctx_alloc, &ctx_total));
%let lr1_sample = %sysfunc(min(&lr1_alloc, &lr1_total));
%let lr2_sample = %sysfunc(min(&lr2_alloc, &lr2_total));

/* Step 5: Handle remaining capacity after initial allocation */
%let allocated = %eval(&ctx_sample + &lr1_sample + &lr2_sample);
%let remaining_final = %eval(&remaining - &allocated);

%if &remaining_final > 0 %then %do;
    %let overflow_ctx = %sysfunc(min(&remaining_final, %eval(&ctx_total - &ctx_sample)));
    %let ctx_sample = %eval(&ctx_sample + &overflow_ctx);
    %let remaining_final = %eval(&remaining_final - &overflow_ctx);
    
    %if &remaining_final > 0 %then %do;
        %let overflow_lr1 = %sysfunc(min(&remaining_final, %eval(&lr1_total - &lr1_sample)));
        %let lr1_sample = %eval(&lr1_sample + &overflow_lr1);
        %let remaining_final = %eval(&remaining_final - &overflow_lr1));
    %end;
    
    %if &remaining_final > 0 %then %do;
        %let overflow_lr2 = %sysfunc(min(&remaining_final, %eval(&lr2_total - &lr2_sample)));
        %let lr2_sample = %eval(&lr2_sample + &overflow_lr2);
    %end;
%end;

/* Step 6: Perform stratified sampling */
proc surveyselect data=&highrisk_ds method=srs 
    sampsize=&hr_sample out=hr_sample seed=&seed noprint;
run;

%if &ctx_sample > 0 %then %do;
    proc surveyselect data=&context_ds method=srs 
        sampsize=&ctx_sample out=ctx_sample seed=&seed noprint;
    run;
%end;

%if &lr1_sample > 0 %then %do;
    proc surveyselect data=&lowrisk1_ds method=srs 
        sampsize=&lr1_sample out=lr1_sample seed=&seed noprint;
    run;
%end;

%if &lr2_sample > 0 %then %do;
    proc surveyselect data=&lowrisk2_ds method=srs 
        sampsize=&lr2_sample out=lr2_sample seed=&seed noprint;
    run;
%end;

/* Step 7: Combine results */
data &output_ds;
    set 
        hr_sample
        %if &ctx_sample > 0 %then %do; ctx_sample %end;
        %if &lr1_sample > 0 %then %do; lr1_sample %end;
        %if &lr2_sample > 0 %then %do; lr2_sample %end;
    ;
run;

/* Cleanup temporary datasets */
proc datasets library=work nolist;
    delete hr_sample ctx_sample lr1_sample lr2_sample;
quit;

%mend select_samples;
