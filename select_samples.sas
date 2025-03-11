OPTIONS NONOTES NOSTIMER NOSOURCE NOSYNTAXCHECK;

/*----------------------------------------------------------------*/
/* 1. Create Sample Datasets                                      */
/*----------------------------------------------------------------*/
%macro gen_sample(ds=, n=, risk=);
    data &ds;
        call streaminit(123); /* Set seed for reproducibility */
        do id = 1 to &n;
            p = rand("uniform"); /* Random probability for date assignment */
            if p < 0.33 then do;
                rfr_dt = '23FEB2025'd + rand("uniform") * 7; /* Date within first week */
                week_start = '23FEB2025'd;
                week_end   = '01MAR2025'd;
            end;
            else if p < 0.66 then do;
                rfr_dt = '02MAR2025'd + rand("uniform") * 7; /* Date within second week */
                week_start = '02MAR2025'd;
                week_end   = '08MAR2025'd;
            end;
            else do;
                rfr_dt = '09MAR2025'd + rand("uniform") * 7; /* Date within third week */
                week_start = '09MAR2025'd;
                week_end   = '15MAR2025'd;
            end;
            risk_level = "&risk"; /* Assign risk level */
            value = rand("uniform"); /* Additional random value */
            output;
        end;
        format rfr_dt week_start week_end date9.;
    run;
%mend;

/* Generate sample datasets */
%gen_sample(ds=high_risk_pop, n=30, risk=High_Risk);
%gen_sample(ds=context_pop,   n=100, risk=Context);
%gen_sample(ds=low_risk1,     n=50, risk=Low_Risk1);
%gen_sample(ds=low_risk2,     n=20, risk=Low_Risk2);

/*----------------------------------------------------------------*/
/* 2. Revised %select_samples Macro                               */
/*----------------------------------------------------------------*/
%macro select_samples(
    highrisk_ds=,
    context_ds=,
    lowrisk1_ds=,
    lowrisk2_ds=,
    output_ds=,
    week_start=,  /* Pass as SAS date number */
    week_end=,    /* Pass as SAS date number */
    seed=12345
);
    %local hr_total ctx_total lr1_total lr2_total;
    %local hr_sample remaining total_available ctx_weight lr1_weight lr2_weight;
    %local ctx_sample_size lr1_sample_size lr2_sample_size;

    %put NOTE: Running sample selection for week %sysfunc(putn(&week_start, date9.)) to %sysfunc(putn(&week_end, date9.));

    /* Helper macro for filtering a dataset by the week using an upper bound of week_end + 1 */
    %macro filter_ds(ds=, out=);
        data &out;
            set &ds;
            /* Include any rfr_dt from week_start up to (but not including) the day after week_end */
            if (&week_start <= rfr_dt) and (rfr_dt < (&week_end + 1));
        run;
    %mend filter_ds;

    /* Filter each dataset by week dates */
    %filter_ds(ds=&highrisk_ds, out=hr_filtered);
    %filter_ds(ds=&context_ds,  out=ctx_filtered);
    %filter_ds(ds=&lowrisk1_ds,   out=lr1_filtered);
    %filter_ds(ds=&lowrisk2_ds,   out=lr2_filtered);

    /* Get counts for each filtered dataset */
    proc sql noprint;
        select count(*) into :hr_total  from hr_filtered;
        select count(*) into :ctx_total from ctx_filtered;
        select count(*) into :lr1_total from lr1_filtered;
        select count(*) into :lr2_total from lr2_filtered;
    quit;

    /* Set count variables to 0 if missing */
    %if %length(&hr_total)=0 %then %let hr_total=0;
    %if %length(&ctx_total)=0 %then %let ctx_total=0;
    %if %length(&lr1_total)=0 %then %let lr1_total=0;
    %if %length(&lr2_total)=0 %then %let lr2_total=0;

    %put NOTE: HR_TOTAL=&hr_total;
    %put NOTE: CTX_TOTAL=&ctx_total;
    %put NOTE: LR1_TOTAL=&lr1_total;
    %put NOTE: LR2_TOTAL=&lr2_total;

    /* Calculate sample sizes */
    %let hr_sample = %sysfunc(min(&hr_total,25)); /* High-risk capped at 25 */
    %let remaining = %eval(65 - &hr_sample);       /* Remaining sample size */

    /* Total available records in other groups */
    %let total_available = %eval(&ctx_total + &lr1_total + &lr2_total);

    %if &total_available > 0 %then %do;
        /* Proportional allocation for context and low-risk groups */
        %let ctx_weight = %sysevalf((&remaining * &ctx_total) / &total_available, floor);
        %let lr1_weight = %sysevalf((&remaining * &lr1_total) / &total_available, floor);
        %let lr2_weight = %sysevalf((&remaining * &lr2_total) / &total_available, floor);

        /* Ensure sample sizes do not exceed available records */
        %let ctx_sample_size = %sysfunc(min(&ctx_weight, &ctx_total));
        %let lr1_sample_size = %sysfunc(min(&lr1_weight, &lr1_total));
        %let lr2_sample_size = %sysfunc(min(&lr2_weight, &lr2_total));
    %end;
    %else %do;
        %let ctx_sample_size = 0;
        %let lr1_sample_size = 0;
        %let lr2_sample_size = 0;
    %end;

    %put NOTE: CTX_SAMPLE_SIZE=&ctx_sample_size;
    %put NOTE: LR1_SAMPLE_SIZE=&lr1_sample_size;
    %put NOTE: LR2_SAMPLE_SIZE=&lr2_sample_size;

    /* Macro to sample a dataset if sample size > 0 */
    %macro sample_group(input=, size=, output=);
        %if &size > 0 %then %do;
            proc surveyselect data=&input method=srs 
                sampsize=&size out=&output seed=&seed;
            run;
        %end;
        %else %do;
            data &output;
                set &input;
                if 0; /* Create an empty dataset with the same structure */
            run;
        %end;
    %mend sample_group;

    /* Sample from each filtered dataset */
    %sample_group(input=ctx_filtered, size=&ctx_sample_size, output=ctx_sample);
    %sample_group(input=lr1_filtered, size=&lr1_sample_size, output=lr1_sample);
    %sample_group(input=lr2_filtered, size=&lr2_sample_size, output=lr2_sample);

    /* Combine samples */
    data &output_ds;
        length source $20 week_indicator $25;
        set
            %if &hr_sample > 0 %then hr_filtered (obs=&hr_sample);
            ctx_sample
            lr1_sample
            lr2_sample
        ;
        if missing(source) then do;
            if risk_level in ('High_Risk','Context','Low_Risk1','Low_Risk2') then 
                source = risk_level;
            else 
                source = 'Other';
        end;
        week_indicator = cats("%sysfunc(putn(&week_start, date9.)", " - ", "%sysfunc(putn(&week_end, date9.)");
    run;

    /* Cleanup temporary datasets */
    proc datasets lib=work nolist;
        delete hr_filtered ctx_filtered lr1_filtered lr2_filtered
               ctx_sample lr1_sample lr2_sample;
    quit;
%mend select_samples;

/*----------------------------------------------------------------*/
/* 3. Generate Week List and Execute Macro Dynamically            */
/*----------------------------------------------------------------*/
/* Create week_list dataset with three week ranges */
data week_list;
    format week_start week_end date9.;
    week_start = '23FEB2025'd;
    do i = 1 to 3;
        week_end = week_start + 6;
        output;
        week_start = week_end + 1;
    end;
run;

/* Dynamically execute the sample selection macro for each week */
data _null_;
    set week_list nobs=nobs;
    if nobs = 0 then do;
        put "WARNING: week_list is empty. No macro calls will be executed.";
        stop;
    end;
    call execute(cats(
        '%select_samples(highrisk_ds=high_risk_pop, ',
        'context_ds=context_pop, lowrisk1_ds=low_risk1, ',
        'lowrisk2_ds=low_risk2, output_ds=final_sample_', put(_N_, best.), ', ',
        'week_start=', week_start, ', week_end=', 
        week_end, ', seed=12345);'
    ));
run;

/*----------------------------------------------------------------*/
/* 4. Combine Weekly Results                                      */
/*----------------------------------------------------------------*/
%macro combine_samples;
    data final_sample;
        set 
        %do i = 1 %to 3;
            %if %sysfunc(exist(final_sample_&i)) %then final_sample_&i;
        %end;
        ;
    run;
%mend combine_samples;
%combine_samples;

/*----------------------------------------------------------------*/
/* 5. Generate Summary Report                                     */
/*----------------------------------------------------------------*/
proc freq data=final_sample;
    tables week_indicator * source / nocum nopercent;
run;

OPTIONS NONOTES NOSTIMER NOSOURCE NOSYNTAXCHECK;
