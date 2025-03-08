OPTIONS NONOTES NOSTIMER NOSOURCE NOSYNTAXCHECK;


/* Step 1. Create the Pattern Components Table */
data pattern_info;
   length domain $15 component $30 pattern $5000 description $150;
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
   pattern = '(?:(?:(?:<<CREDIT>>).*?(?:<<FEATURE>>))|(?:(?:<<FEATURE>>).*?(?:<<CREDIT>>)))';
   description = 'Combines credit card reference and feature keywords with alternation';
   output;
   
   /* --- Investment Domain Enhancements --- */
   domain = "Investment";
   component = 'InvestmentReference';
   pattern = '\b(?:invest(?:ment|ing)(?:s)?|mutual\s*funds?|index\s*funds?|stocks?|bonds?|treasur(?:y|ies)|securit(?:y|ies)|portfolio(?:s)?|ETF(?:s)?|REIT(?:s)?|hedge\s*funds?|private\s*equity|venture\s*capital|commodit(?:y|ies)|derivatives?|options?|futures?|swaps?|CFD(?:s)?|IRA(?:s)?|401\(?k\)?s?|Roth\s*IRAs?|brokerage\s*accounts?|wrap\s*accounts?|separate\s*accounts?|financial\s*planning|wealth\s*management|robo[\s-]*advisors?|annuit(?:y|ies)|CD(?:s)?|certificates?\s*of\s*deposit|unit\s*trusts?|structured\s*products?|cryptocurrenc(?:y|ies)|digital\s*assets?|security\s*tokens?|crowdfunding|tax[\s-]*loss\s*harvesting|estate\s*planning|trust\s*services)\b';
   description = 'Matches references to investment products, services, and vehicles';
   output;

   domain = "Investment";
   component = 'ComplianceTerms';
   pattern = '\b(?:fiduciary\s*duty|suitability\s*standard|know\s*your\s*client|KYC|anti[\s-]*money\s*laundering|AML|SEC|FINRA|Form\s*ADV|Form\s*CRS|prospectus|disclosure\s*document|ombudsman|regulatory\s*compliance|accredited\s*investor|sophisticated\s*investor|prudent\s*investor|best\s*execution|soft\s*dollars|conflict\s*of\s*interest|custody\s*rule|blue\s*sky\s*laws|volcker\s*rule|margin\s*agreement)\b';
   description = 'Matches regulatory and compliance terminology in investment communications';
   output;

   domain = "Investment";
   component = 'PerformanceTerms';
   pattern = '\b(?:return(?:s)?\s*on\s*investment|ROI|alpha|beta|sharpe\s*ratio|sortino\s*ratio|standard\s*deviation|volatility|benchmark(?:ing|s)?|outperform(?:ance|ing)?|track\s*record|backtest(?:ed|ing)|compounded\s*return(?:s)?|project(?:ed|ing)\s*return(?:s)?|target(?:ed)?\s*return(?:s)?|yield(?:ing|s)?|dividend(?:s)?|capital\s*gains?|total\s*return|IRR)\b';
   description = 'Matches investment performance metrics and benchmarking terms';
   output;

   domain = "Investment";
   component = 'RiskDisclosures';
   pattern = '\b(?:past\s*performance|not\s*FDIC\s*insured|no\s*bank\s*guarantee|may\s*lose\s*value|market\s*risk|liquidity\s*risk|inflation\s*risk|interest\s*rate\s*risk|credit\s*risk|counterparty\s*risk|concentration\s*risk|principal\s*risk|leverag(?:e|ing)|speculative|unconstrained|emerging\s*markets?|high[\s-]*yield|junk\s*bonds?|volatil(?:e|ity)|drawdown(?:s)?|maximum\s*adverse\s*excursion)\b';
   description = 'Matches required risk disclosures and warnings';
   output;

   domain = "Investment";
   component = 'HighRiskProducts';
   pattern = '\b(?:penny\s*stocks?|microcap|OTC\s*securities?|cryptocurrenc(?:y|ies)|binary\s*options?|CFD(?:s)?|forex|foreign\s*exchange|leveraged\s*ET(?:N|F)s?|inverse\s*ET(?:N|F)s?|illiquid\s*securities?|private\s*placements?|special\s*situations|distressed\s*debt)\b';
   description = 'Matches high-risk investment products requiring special disclosures';
   output;

   domain = "Investment";
   component = 'ActionKeywords';
   pattern = '\b(?:recommend(?:ing|ed|s)?|suggest(?:ing|ed|s)?|advise(?:ing|d|s)?|endorse(?:ing|d|s)?|guarantee(?:ing|d|s)?|promis(?:e|ing|ed)|assur(?:e|ing|ed)|project(?:ing|ed)|target(?:ing|ed)|forecast(?:ing|ed)|outperform(?:ing|ed)|beat\s*the\s*market)\b';
   description = 'Matches action verbs requiring compliance oversight';
   output;

   domain = "Investment";
   component = 'InvestmentAlternation1';
   pattern = '(?:(?:<<INVESTMENT>>).*?(?:<<COMPLIANCE>>))';
   description = 'Combines investment references with compliance terminology';
   output;

   domain = "Investment";
   component = 'InvestmentAlternation2';
   pattern = '(?:(?:<<HIGHRISK>>).*?(?:<<RISKDISCLOSURE>>))';
   description = 'Links high-risk products with required risk disclosures';
   output;

   domain = "Investment";
   component = 'InvestmentAlternation3';
   pattern = '(?:(?:<<PERFORMANCE>>).*?(?:<<RISKDISCLOSURE>>))';
   description = 'Connects performance claims with risk disclosures';
   output;
run;

/* a broader range of specific investment related product or service terms and  */
/* potential compliance issues in financial communications */
%macro buildPattern(domain=);
   %local i j num_comps num_alts comp_list;

   /* Clear existing local macro variables */
   proc sql noprint;
       select distinct component into :comp_list separated by ' ' 
       from pattern_info 
       where domain="&domain";
   quit;

   /* Retrieve and store ALL component patterns */
   proc sql noprint;
       select component, pattern into :comp1-:comp999, :pat1-:pat999
       from pattern_info
       where domain="&domain";
       %let num_comps = &sqlobs;
   quit;

   /* Create local macro variables for components */
   %do i=1 %to &num_comps;
       %local &&comp&i;
       %let &&comp&i = %superq(pat&i);
   %end;

   /* Process alternation patterns */
   proc sql noprint;
       select pattern into :alt1-:alt999
       from pattern_info
       where domain="&domain" and component like '%Alternation%';
       %let num_alts = &sqlobs;
   quit;

   %let fullAlternation = ;
   %do j=1 %to &num_alts;
       %let current_alt = %superq(alt&j);
       
       /* Credit Card replacements */
       %if &domain=CreditCard %then %do;
           %let current_alt = %sysfunc(prxchange(s/<<CREDIT>>/%superq(CreditCardReference)/, -1, &current_alt));
           %let current_alt = %sysfunc(prxchange(s/<<FEATURE>>/%superq(FeatureTermKeywords)/, -1, &current_alt));
       %end;
       
       /* Investment replacements */
       %else %if &domain=Investment %then %do;
           %let current_alt = %sysfunc(prxchange(s/<<INVESTMENT>>/%superq(InvestmentReference)/, -1, &current_alt));
           %let current_alt = %sysfunc(prxchange(s/<<COMPLIANCE>>/%superq(ComplianceTerms)/, -1, &current_alt));
           %let current_alt = %sysfunc(prxchange(s/<<HIGHRISK>>/%superq(HighRiskProducts)/, -1, &current_alt));
           %let current_alt = %sysfunc(prxchange(s/<<RISKDISCLOSURE>>/%superq(RiskDisclosures)/, -1, &current_alt));
           %let current_alt = %sysfunc(prxchange(s/<<PERFORMANCE>>/%superq(PerformanceTerms)/, -1, &current_alt));
           %let current_alt = %sysfunc(prxchange(s/<<ACTION>>/%superq(ActionKeywords)/, -1, &current_alt));
       %end;

       %if &j=1 %then %let fullAlternation = &current_alt;
       %else %let fullAlternation = &fullAlternation|&current_alt;
   %end;

   /* Add base components directly to pattern */
   %if &domain=CreditCard %then %do;
       %let fullAlternation = &fullAlternation|%superq(CreditCardReference)|%superq(FeatureTermKeywords);
   %end;
   %else %if &domain=Investment %then %do;
       %let fullAlternation = &fullAlternation|%superq(InvestmentReference)|%superq(ActionKeywords)|%superq(ComplianceTerms)|%superq(PerformanceTerms)|%superq(RiskDisclosures)|%superq(HighRiskProducts);
   %end;

   /* Final pattern assembly */
   %global finalPattern_&domain;
   %let finalPattern_&domain = %str(/(?i)\b(?:&fullAlternation)\b/);
   %put NOTE: Final pattern for &domain: &&finalPattern_&domain;
%mend buildPattern;

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
