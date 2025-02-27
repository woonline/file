OPTIONS NONOTES NOSTIMER NOSOURCE NOSYNTAXCHECK;

/* Test comments dataset */
data Comment_Text;
infile datalines dlm='|' dsd truncover;
input Flagged_Word : $20.
	Target_Population : $20.
	violation_category : $30.
	Random : $1.
	Exc_ID : $20.
	comments : $200.;
datalines;
credit card| Teller|Customer Engagement | Y | Teller_CE_CC | "consent" credit card options
DISCUSS | Banker| Customer Engagement| Y |Banker CE|$250K FOR PREMIER PROMO. WANTS TO DISCUSS OPTIONS TO MOVE THEIR MONEY. HUSBAND HAS $500K AT CHASE FOR HIS RETIR 
discuss| Banker | Customer Engagement | Y |Banker_CE|$3.5 million will be wire into account tomorrow, walked over to fa to discuss options
credit card| Teller| Customer Engagement |Y|Teller_CE_CC| (10:00am) She did a deposit. She is interested in a new credit card and wants to know the benefits.
credit card|Teller|Customer Engagement|Y|Teller_CE_CC| (2:00pm) Customer came in to cash a check. He just completed a year and is interested in a credit card.
credit card| Teller | Customer Engagement |Y|Teller_CE_CC| (2:00pm) She wants to know about the benefits of a credit card to apply•
credit card|Teller|Customer Engagement|Y|Teller_CE_CC| (financial coaching) customer interested in credit card. Credit building credit card|Teller|Custoner Engagement|Y|Teller_CE_CC| (financial coaching) customer wants to build credit apply credit card Credit card|Teller| Customer Engagement |X|Teller_CE_CC|***CUST REQUESTS CALL AFTER 3:30 PM ***Cust is intersted in appling for Credit card. Mentioned he was des payments|Teller| Collections|X|Teller_Coll_Pymt|- Inquring about automatic payments had some questions
;
run;


/* Exception logic dataset */
/* data exception_logic; */
/*     informat category $20. name $50. pattern $5000.; */
/*     infile datalines delimiter = ','; */
/*     input category name pattern; */
/*     datalines; */
/* EXCLUSION,wire_related,\b(?:wire[-\\s]*(?:transfer|xfr?|tf))\b */
/* EXCLUSION,advisor_related,\b(advisor(?:'s|s)?|advisory|advisor's|annuities)\b */
/* INCLUSION,complaint_related,\bcompl[aeiou]+nt[s]?[e]?s?\b */
/* EXCLUSION,CC_related,\b^(?!.*\s*(features|promotion rate|balance rate|transfer high-rate balances|interest rate|cash reward(s)?|bonus|introductory rate|annual fee|APR|active cash|autograph|bilt mastercard|reflect|choice privileges|points|balance transfer|rewards))\b(apply(ing)?|applt|appt|open a(n)?|interested in|primary wf|automatic payment(s)?)\b */
/* INCLUSION,payment_related,(?!.*\b(?:auto|car|card|monthly\/automatic|reacurring\/mortgage|stop|set up|make(?:a)?|last\/online|(?:accepting)?|and)\s*(?:credit\/debit)?\s*card\s*payments?\b(?!.*\b(?:behind(?:in| on)?)(?=\s*(?:payment[s]?|pymts))\b)) */
/* ; */
/* run; */

data Exception_Logic;
infile datalines dlm='09'x dsd truncover;
input
Exc_ID : $20.
Category : $20.
NAME : $30.
pattern : $500.
;
format EFF_START_DT EFF_END_DT mnddyy10.;
datalines;
Teller_CE_CC	EXCLUSION	CC_related	\b^(?!.*\s*(features|promotion rate|balance rate|transfer high-rate balances|interest rate|cash reward(s)?|bonus|introductory rate|annual fee|APR|active cash|autograph|bilt mastercard|reflect|choice privileges|points|balance transfer|rewards))\b(apply(ing)?|applt|appt|open a(n)?|interested in|primary wf|automatic payment(s)?)\b	
	INCLUSION	complaint_related	complaint_related,\bcompl[aeiou]+nt[s]?[e]?s?\b
;
run;

%macro analyze_comments_dynamic(input_ds=, output_ds=, text_var=comments, logic_ds=exception_logic);
/* 
Purpose: Analyzes freeform text comments and applies exception logics for monitoring.
Parameters:
    input_ds  - Input dataset containing comments
    output_ds - Output dataset with indicators and audit trail
    text_var  - Name of the text variable (default: comments)
    logic_ds  - Dataset with exception logics (default: exception_logic)
*/

/* Step 1: Create macro variables from the exception logic dataset */
proc sql noprint;
    select count(*) into :total_exc_rules 
    from &logic_ds where category = 'EXCLUSION';

    select count(*) into :total_inc_rules 
    from &logic_ds where category = 'INCLUSION';

    %let total_rules = %eval(&total_exc_rules + &total_inc_rules);

    select category,
           name,
           pattern,
           tranwrd(pattern, "'", "''") as pattern_escaped length=5000
    into :cat1 - :cat%left(&total_rules),
         :name1 - :name%left(&total_rules),
         :pat1 - :pat%left(&total_rules),
         :pat_esc1 - :pat_esc%left(&total_rules)
    from &logic_ds;
quit;

/* Step 2: Print macro variables for validation */
%put === Macro Variables for Validation ===;
%put Total exclusion rules: &total_exc_rules;
%put Total inclusion rules: &total_inc_rules;
%do i=1 %to &total_rules;
    %put Rule &i: Category=&&cat&i, Name=&&name&i, Pattern=%superq(pat&i), Escaped Pattern=%superq(pat_esc&i);
%end;
%put =================================;

/* Step 3: Build CASE statements with proper comma handling */
%let case_statements = ;
%do i = 1 %to &total_rules;
    %let escaped_pattern = %superq(pat_esc&i);
    %let case_statements = &case_statements
        case
            when prxmatch("/&escaped_pattern/i", &text_var) then 1
            else 0
        end as &&name&i
    ;
    %if &i < &total_rules %then %let case_statements = &case_statements,;
%end;

/* Step 4: Create temporary dataset with indicators (fixed composite flag logic) */
proc sql;
    create table temp_output as
    select 
        a.*,  /* Original dataset variables */
        /* Individual indicators */
        &case_statements,
        
        /* Composite flags */
        case when 
            (%do i=1 %to &total_rules;
                %if "&&cat&i" = "EXCLUSION" %then %do;
                    (calculated &&name&i = 1) or 
                %end;
            %end; 0) then 1 else 0
        end as exclusion_flag,
        
        case when 
            (%do i=1 %to &total_rules;
                %if "&&cat&i" = "INCLUSION" %then %do;
                    (calculated &&name&i = 1) or 
                %end;
            %end; 0) then 1 else 0
        end as inclusion_flag
    from &input_ds a;
quit;

/* Step 5: Add binary indicators, audit trail, and validation_key */
data &output_ds;
    set temp_output;
    /* Define lengths based on the number of rules */
    length matched_categories $100 matched_patterns $5000 
           Excl_Ind $&total_exc_rules Incl_Ind $&total_inc_rules
           exc_key $500 inc_key $500 validation_key $5000;
    matched_categories = "";
    matched_patterns = "";
    Excl_Ind = "";
    Incl_Ind = "";
    exc_key = "";
    inc_key = "";
    
    /* Build binary indicators, audit trail, and validation key */
    %do i=1 %to &total_rules;
        if &&name&i = 1 then do;
            matched_categories = catx(", ", matched_categories, "&&cat&i");
            matched_patterns = catx(", ", matched_patterns, "&&pat&i");
            if "&&cat&i" = "EXCLUSION" then do;
                Excl_Ind = cats(Excl_Ind, "1");
                exc_key = catx("; ", exc_key, "&&name&i=1");
            end;
            else if "&&cat&i" = "INCLUSION" then do;
                Incl_Ind = cats(Incl_Ind, "1");
                inc_key = catx(", ", inc_key, "&&name&i=1");
            end;
        end;
        else do;
            if "&&cat&i" = "EXCLUSION" then do;
                Excl_Ind = cats(Excl_Ind, "0");
                exc_key = catx("; ", exc_key, "&&name&i=0");
            end;
            else if "&&cat&i" = "INCLUSION" then do;
                Incl_Ind = cats(Incl_Ind, "0");
                inc_key = catx(", ", inc_key, "&&name&i=0");
            end;
        end;
    %end;
    /* Construct validation_key */
    if exc_key = "" then exc_key = "None=0"; /* Handle case with no exclusion rules */
    if inc_key = "" then inc_key = "None=0"; /* Handle case with no inclusion rules */
    validation_key = "(" || strip(exc_key) || ") | (" || strip(inc_key) || ")";
    
    /* Clean up extra spaces */
    matched_categories = compbl(matched_categories);
    matched_patterns = compbl(matched_patterns);
run;

/* Step 6: Clean up temporary dataset */
proc sql;
    drop table temp_output;
quit;

/* Step 7: Generate a summary report */
proc freq data=&output_ds;
    tables exclusion_flag inclusion_flag 
        %do i=1 %to &total_rules;
            &&name&i
        %end;
        / nocum nopercent;
    title "Dynamic Monitoring Strategy Exception Analysis";
run;

%mend analyze_comments_dynamic;

/* Invoke the macro */
%analyze_comments_dynamic(
    input_ds=Comment_Text,
    output_ds=comment_analysis,
    text_var=comments,
    logic_ds=exception_logic
);

OPTIONS NOTES STIMER SOURCE SYNTAXCHECK;
