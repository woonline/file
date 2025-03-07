OPTIONS NONOTES NOSTIMER NOSOURCE NOSYNTAXCHECK;

/* Step 1. Create the Pattern Components Table */
data pattern_info;
   length domain $15 component $30 pattern $300 description $150;
   /* --- Credit Card Domain --- */
   domain = "CreditCard";
   component = 'CreditCardReference';
   pattern = '\b(?:credit\s*card(?:s)?|CC)\b';
   description = 'Matches the credit card reference (credit card(s) or CC)';
   output;
   
   domain = "CreditCard";
   component = 'FeatureTermKeywords';
   pattern = '\b(?:interest\s*rate(?:s)?|annual\s*fee|promotion\s*rate(?:s)?|balance\s*transfer(?:s)?|APR|reward(?:s)?|cash\s*back|credit\s*limit|late\s*fee|grace\s*period|\d+%[ -]*apr|introductory[ -]+rate|minimum[ -]+payment)\b';
   description = 'Matches keywords related to credit card features, terms, or rates';
   output;
   
   domain = "CreditCard";
   component = 'CreditCardAlternation';
   /* Use safe placeholders <<CREDIT>> and <<FEATURE>> to avoid macro resolution issues */
   pattern = '(?:(?:(?:<<CREDIT>>).*?(?:<<FEATURE>>))|(?:(?:<<FEATURE>>).*?(?:<<CREDIT>>)))';
   description = 'Combines credit card reference and feature keywords with alternation';
   output;
   
   /* --- Investment Domain --- */
   domain = "Investment";
   component = 'InvestmentReference';
   pattern = '\b(?:investment(?:s)?|mutual\s*fund(?:s)?|stocks?|bonds?|securities?|portfolio(?:s)?)\b';
   description = 'Matches references to investment products or services';
   output;
   
   domain = "Investment";
   component = 'InvestmentActionKeywords';
   pattern = '\b(?:recommend(?:ing|ed)?|suggest(?:ing|ed)?|discuss(?:ing|ed)?)\b';
   description = 'Matches keywords related to recommending or discussing investment products';
   output;
   
   domain = "Investment";
   component = 'InvestmentAlternation';
   /* Use safe placeholders <<INVESTMENT>> and <<ACTION>> */
   pattern = '(?:(?:(?:<<INVESTMENT>>).*?(?:<<ACTION>>))|(?:(?:<<ACTION>>).*?(?:<<INVESTMENT>>)))';
   description = 'Combines investment reference and action keywords with alternation';
   output;
run;

/* Step 2. Macro Function to Build the Final Pattern for a Single Domain */
%macro buildPattern(domain=);
   %local ref action alt fullAlternation finalPattern;
   
   /* Set component names based on the domain */
   %if &domain=CreditCard %then %do;
       %let ref = CreditCardReference;
       %let action = FeatureTermKeywords;
       %let alt = CreditCardAlternation;
   %end;
   %else %if &domain=Investment %then %do;
       %let ref = InvestmentReference;
       %let action = InvestmentActionKeywords;
       %let alt = InvestmentAlternation;
   %end;
   %else %do;
       %put ERROR: Unsupported domain: &domain;
       %return;
   %end;
   
   /* Retrieve patterns from pattern_info */
   proc sql noprint;
       select pattern into :ref trimmed 
         from pattern_info where domain="&domain" and component="&ref";
       select pattern into :action trimmed 
         from pattern_info where domain="&domain" and component="&action";
       select pattern into :alt trimmed 
         from pattern_info where domain="&domain" and component="&alt";
   quit;
   
   /* Replace safe placeholders with actual patterns */
   %if &domain=CreditCard %then %do;
       %let fullAlternation = %sysfunc(prxchange(s/<<CREDIT>>/&ref./, -1, &alt.));
       %let fullAlternation = %sysfunc(prxchange(s/<<FEATURE>>/&action./, -1, &fullAlternation.));
   %end;
   %else %if &domain=Investment %then %do;
       %let fullAlternation = %sysfunc(prxchange(s/<<INVESTMENT>>/&ref./, -1, &alt.));
       %let fullAlternation = %sysfunc(prxchange(s/<<ACTION>>/&action./, -1, &fullAlternation.));
   %end;
   
   /* Wrap with word boundaries and add case-insensitive flag */
   %let finalPattern = %str(/\b(?i)&fullAlternation\b/);
   %put NOTE: The final pattern for &domain is: &finalPattern;
   
   /* Store globally */
   %global finalPattern_&domain;
   %let finalPattern_&domain = &finalPattern;
%mend buildPattern;

/* Step 3. Macro to Build Final Patterns for All Domains and Create a Dataset */
%macro buildAllPatterns;
   %local i d domains;
   /* Retrieve unique domains */
   proc sql noprint;
      select distinct domain into :domains separated by ' ' from pattern_info;
   quit;
   
   /* Build final pattern for each domain */
   %let i = 1;
   %do %while (%scan(&domains, &i) ne );
      %let d = %scan(&domains, &i);
      %buildPattern(domain=&d);
      %let i = %eval(&i + 1);
   %end;
   
   /* Create dataset with final patterns (set length to 1000 to avoid truncation) */
   data final_patterns;
      length domain $15 final_pattern $1000;
      %let i = 1;
      %do %while (%scan(&domains, &i) ne );
         %let d = %scan(&domains, &i);
         domain = "&d";
         final_pattern = symget("finalPattern_&d");
         output;
         %let i = %eval(&i + 1);
      %end;
      stop;
   run;
%mend buildAllPatterns;

%buildAllPatterns

/* Merge final patterns with original pattern_info for an audit trail */
proc sql;
   create table pattern_final as
   select a.*, b.final_pattern
   from pattern_info as a left join final_patterns as b
   on a.domain = b.domain;
quit;

proc print data=pattern_final noobs;
   title "Final Pattern Information";
run;


/* Step 3. Create Test Records for Both Domains */
data input_data;
   length text $300;
   infile datalines dlm='|' dsd truncover;
   input text $char300.;
   datalines;
I would like to discuss the annual fee and interest rate on our credit cards.
Our CC offers a promotional rate and balance transfer option.
Please review the credit card terms including APR and late fee details.
Our customer received a 15% - apr offer on her new credit card.
They advertised an introductory-rate on the credit card.
Be sure to mention the minimum-payment requirements for the card.
This text does not mention any feature terms.
The advisor recommended a new mutual fund for her portfolio.
Our client was discussing investment options for stocks and bonds.
She suggested investing in securities to diversify her portfolio.
I need more details on the investment service.
Please review our credit card products.
;
run;

/* Step 4. Test the Patterns on the Input Data */
data test_results;
   set input_data;
   length match_credit match_invest 8;
   /* Apply Credit Card pattern */
   match_credit = prxmatch("&&finalPattern_CreditCard", text);
   /* Apply Investment pattern */
   match_invest = prxmatch("&&finalPattern_Investment", text);
run;

proc print data=test_results noobs;
   var text match_credit match_invest;
   title "Test Results for Credit Card and Investment Patterns";
run;
