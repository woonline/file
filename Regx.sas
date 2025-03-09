/* 1. Enhanced pattern_info including Investment domain with broadened product/service terms, updated action terms, and a compliance record */
data pattern_info;
    length domain $50 category $50 component $20 pattern $500 description $200;
    infile datalines dlm='@' truncover;
    input domain $
          category $
          component $
          pattern :$500.
          description :$200.;
    datalines;
Credit Card@Reference@CC_Reference@/\b(credit[\s-]?card(s)?|cc)\b/i@Matches credit card references (credit card(s) or CC)
Credit Card@Reference - Rate Related@CC_Rate@/\b(apr|annual percentage rate|interest rate|monthly rate|purchase rate)\b/i@Matches rate-related terms like APR and interest rates
Credit Card@Reference - Fee Related@CC_Fee@/\b(annual fee|late fee|service charge|processing fee|balance transfer fee|foreign transaction fee|over-limit fee)\b/i@Matches fee-related charges
Credit Card@Reference - Reward Related@CC_Reward@/\b(rewards points|cashback|bonus points|travel miles|redemption options|sign-up bonus|welcome offer)\b/i@Matches reward program terms
Credit Card@Reference - Feature Related@CC_Feature@/\b(balance transfer|credit limit|payment due date|contactless|chip card|virtual card|authorized user|grace period)\b/i@Matches card features and functionality
Credit Card@Reference - Security Related@CC_Security@/\b(fraud protection|security code|cvv|cvc|emv|identity theft|zero liability|3d secure)\b/i@Matches security features and protections
Investment@Reference@INV_Reference@/\b(invest(?:ment|ments|ing|ed))\b/i@Matches basic investment references
Investment@Reference - Product Related@INV_Product@/\b(mutual fund[s]?|ETF[s]?|exchange[-\s]?traded fund[s]?|stock[s]?|bond[s]?|securit(?:y|ies)|derivativ(?:es)?|option[s]?|future[s]?|commodity(?:s)?|real estate investment trust[s]?|REIT[s]?|crypto(?: currency|asset[s]?)?)\b/i@Matches a broader range of investment product terms
Investment@Reference - Service Related@INV_Service@/\b(portfolio management|financial planning|wealth management|advisory|asset management|investment banking|risk management|private banking|capital markets|investment advisory|financial consulting)\b/i@Matches a broader range of investment service terms
Investment@Reference - Action Related@INV_Action@/\b(recommend(?:s|ed|ing)?|suggest(?:s|ed|ing)?|advise(?:s|d|ing)?|propose(?:s|d|ing)?|endorse(?:s|d|ing)?|advocate(?:s|d|ing)?|urge(?:s|d|ing)?|encourage(?:s|d|ing)?|support(?:s|ed|ing)?)\b/i@Matches robust action terms for investment
Investment@Reference - Compliance@INV_Compliance@/\b(compliance|regulatory(?:\s?(issues|concerns|requirements))?|SEC|FINRA|FCA|oversight|risk disclosure|AML|KYC)\b/i@Matches potential compliance issues in financial communications
;
run;

proc print data=pattern_info;
run;

/* 2. Macro to create contextual patterns for Credit Card and Investment */
/* For Investment, for categories "Reference - Product Related", "Reference - Service Related" and "Reference - Compliance", 
   we combine the Investment Reference pattern, the specific subpattern (product, service, or compliance),
   and the robust action pattern (INV_Action) using lookahead to ensure all three exist.
   For other records, the final pattern remains unchanged. */
%macro create_contextual_patterns;
    /* For Credit Card domain, extract base Reference pattern */
    proc sql noprint;
        select prxchange('s/^\/(.*)\/.*$/$1/', -1, pattern)
        into :cc_base trimmed
        from pattern_info
        where domain = 'Credit Card' and category = 'Reference';
    quit;
    
    /* For Investment domain, extract base patterns for Reference and Action */
    proc sql noprint;
        select prxchange('s/^\/(.*)\/.*$/$1/', -1, pattern)
        into :inv_ref trimmed
        from pattern_info
        where domain = 'Investment' and category = 'Reference';
        
        select prxchange('s/^\/(.*)\/.*$/$1/', -1, pattern)
        into :inv_action trimmed
        from pattern_info
        where domain = 'Investment' and category = 'Reference - Action Related';
    quit;
    
    /* Create valid combined patterns */
    data final_patterns;
        set pattern_info;
        length sub_core $1000 final_pattern $1000;
        /* For Credit Card non-reference categories */
        if domain = 'Credit Card' and category ne 'Reference' then do;
            sub_core = prxchange('s/^\/(.*)\/.*$/$1/', -1, pattern);
            final_pattern = cats('/\b(', "&cc_base", ')\b.*?\b(', sub_core,
                                ')\b|\b(', sub_core, ')\b.*?\b(', "&cc_base", ')\b/i');
        end;
        /* For Investment categories that use the combined pattern */
        else if domain = 'Investment' and 
           (category in ('Reference - Product Related','Reference - Service Related','Reference - Compliance')) then do;
            sub_core = prxchange('s/^\/(.*)\/.*$/$1/', -1, pattern);
            /* Build a combined pattern that requires:
               - the basic investment reference term (INV_Reference)
               - the specific subpattern (product, service, or compliance)
               - a robust action term (INV_Action)
            */
            final_pattern = cats('/(?=.*\b(', "&inv_ref", ')\b)(?=.*\b(', sub_core,
                                ')\b)(?=.*\b(', "&inv_action", ')\b)/i');
        end;
        /* For other cases, leave final_pattern unchanged */
        else do;
            final_pattern = pattern;
        end;
        keep domain category component final_pattern description;
    run;
    
    proc print data=final_patterns;
        var domain category final_pattern;
        format final_pattern $1000.;
    run;
%mend;

%create_contextual_patterns;

/* 3. Extended Test Dataset including Investment cases */
data test_records;
    length text $500 expected_matches $200 test_id 8;
    infile datalines dlm='@' truncover;
    input test_id text :$500. expected_matches :$200.;
    datalines;
1@Your credit card's APR increased to 19.99% this month@Reference - Rate Related
2@No foreign transaction fees on our premium CC@Reference - Fee Related
3@Earn double rewards points on grocery purchases with your card@Reference - Reward Related
4@New virtual card feature available in mobile banking app@Reference - Feature Related
5@Zero liability protection covers unauthorized CC transactions@Reference - Security Related
6@The annual fee will be waived for first year of your credit-card@Reference - Fee Related
7@Check your monthly statement for payment due date details@Reference - Feature Related
8@Contactless payment requires chip card authentication@Reference - Feature Related
9@3D Secure technology enhances CVV protection for online purchases@Reference - Security Related
10@Balance transfer offers may affect your credit limit@Reference - Feature Related
11@This savings account has 2.5% interest rate@No Match Expected
12@Loan application requires proof of income@No Match Expected
13@Credit card chip technology combined with fraud protection alerts@Reference - Security Related,Reference - Feature Related
14@APR reduction and bonus points offer for new CC applications@Reference - Rate Related,Reference - Reward Related
15@I recommend investing in ETFs and I recommend this mutual fund for a diversified portfolio@Reference,Reference - Product Related
16@Our wealth management service provides excellent financial planning advice for investments@Reference,Reference - Service Related
17@Investments are risky, but I suggest diversifying with stocks@Reference,Reference - Product Related
18@Investments are growing and I advocate investing in bonds for long-term gains@Reference,Reference - Product Related
19@Our financial consulting team ensures compliance with SEC regulations during investments@Reference,Reference - Compliance
20@The new risk disclosure and regulatory updates affect our investment strategies@No Match Expected
;
run;

/* 4. Enhanced Match Patterns Macro with Audit Trail */
%macro match_patterns_audit(
    input_ds=WORK.FINAL_PATTERNS,
    test_ds=WORK.TEST_RECORDS,
    output_ds=matches_audit
);
    /* 1. Prepare patterns with proper escaping */
    data _patterns;
        set &input_ds;
        length regex_pattern $1000;
        regex_pattern = prxchange('s/(\\\\)/\\/i', -1, final_pattern);
        pattern_id = _N_;
    run;

    /* 2. Enhanced matching logic: accumulate detected categories */
    data &output_ds;
        if _n_ = 1 then do;
            declare hash patterns(dataset:"_patterns");
            patterns.definekey('pattern_id');
            patterns.definedata('domain','category','regex_pattern');
            patterns.definedone();
            if 0 then set _patterns nobs=pattern_count;
        end;

        set &test_ds;
        length clean_text $500 detected_categories $500;
        clean_text = prxchange('s/[^a-zA-Z0-9 ]//', -1, text);
        detected_categories = '';
        
        do pattern_id = 1 to pattern_count;
            if patterns.find() = 0 then do;
                rx = prxparse(regex_pattern);
                if prxmatch(rx, strip(clean_text)) then do;
                    if detected_categories = '' then
                        detected_categories = category;
                    else
                        detected_categories = cats(detected_categories, ';', category);
                end;
            end;
        end;
        if detected_categories ne '' then output;
        keep test_id text detected_categories;
    run;

    /* 3. Validation report using expected vs. detected match counts */
    proc sql;
        create table validation_report as
        select 
            t.test_id,
            t.text,
            t.expected_matches,
            m.detected_categories as matched_categories,
            case
                when t.expected_matches = 'No Match Expected' and missing(m.detected_categories) then 'Pass'
                when t.expected_matches ne 'No Match Expected' and 
                     countw(m.detected_categories, ';') = countw(t.expected_matches, ';') then 'Pass'
                else 'Fail'
            end as validation_status
        from &test_ds t
        left join &output_ds m
            on t.test_id = m.test_id
        order by t.test_id;
    quit;

    proc print data=validation_report noobs label;
        var test_id text expected_matches matched_categories validation_status;
        label 
            test_id = 'Test ID'
            text = 'Test Text'
            expected_matches = 'Expected Matches'
            matched_categories = 'Detected Categories'
            validation_status = 'Status';
        title 'Corrected Pattern Matching Audit Report';
        format text $500.;
    run;
%mend;

%match_patterns_audit(
    input_ds=final_patterns,
    test_ds=test_records,
    output_ds=full_audit
);
