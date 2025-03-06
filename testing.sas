data freeform;
length flagged_word excption_satus text $500; 
infile datalines dlm = '|';
input flagged_word excption_satus text $; 
datalines;
credit card | Exclusion | wants to open up a credit card 
credit card | Exclusion | apply for credit card
credit card | Exclusion | would like to apply for a credit card for building her credit 
credit card | Exclusion | made appt for credit card questions
credit card | Exclusion | apple for credit card
credit card | Exclusion | switching credit cards and updates to acts
credit card | Exclusion | Interested on learning about credit loans and credit cards
credit card | Exclusion | Wants to ehar about our bi=usiness credit cards. Got referreed in the past but neer got the call
credit card | Exclusion | cust wants information about credit cards 832 723 4147
credit card | Exclusion | I discovered that the customer does not have any credit cards with us and we can help her apply for one 
credit card | Inclusion | credit card with 0% introductory annual fee
credit card | Inclusion | transfer high-rate balances to our new credit card
credit card | Inclusion | apply for active cash credit card
credit card | Inclusion | choice privileges points system for credit card
credit card | Inclusion | rewards program for credit card customers
;
run;

data test_results;
    set freeform;
    retain re;
    
    /* Compile the enhanced regular expression */
    if _n_ = 1 then do;
        re = prxparse('/(?i)(?:(?:(?:credit\s+cards?|CC)\b.*?\b((?:apply|applying|aply|applt|open(?:\s+up)?|want(?:s)?(?:\s+information)?|interested|question|ask|questions|switch(?:ed|ing)?)))|(?:(?:(apply|applying|aply|applt|open(?:\s+up)?|want(?:s)?(?:\s+information)?|interested|question|ask|questions|switch(?:ed|ing)?))\b.*?\b(?:credit\s+cards?|CC)))(?!.*\b((?:discuss|features|promotion\s+rate(?:s)?|balance\s+rate(?:s)?|transfer\s+high-rate\s+balances|interest\s+rate(?:s)?|cash\s+reward(?:s)?|bonu(?:s9)?|(intro|introductory)\s+(annual|rate|fee)|percentage\s+rate|apr|annual\s+fee|active\s+cash|autograph|bilt\s+mastercard|reflect|choice\s+privileges|point(?:s)?|balance\s+transfer|reward(?:s)?))\b)/');

        if missing(re) then do;
            put "ERROR: Invalid regular expression.";
            stop;
        end;
    end;

    /* Apply the regex pattern */
    match = prxmatch(re, text);
    
    /* Initialize the reasoning column */
    length reasoning exclusion_term category $250;
    if match then do;
        action1 = prxposn(re, 1, text);
        action2 = prxposn(re, 2, text);
        if strip(action1) ne '' then 
            reasoning = cats('Flagged: "Credit card" reference followed by action word "', strip(action1), '"');
        else if strip(action2) ne '' then 
            reasoning = cats('Flagged: Action word "', strip(action2), '" found before "credit card" reference');
        else 
            reasoning = 'Flagged: Pattern matched';
    end;
    else do;
        /* Extract the matched exclusion term dynamically */
        exclusion_term = prxposn(re, 3, text);
        
        /* Map the exclusion term to its category dynamically */
        if prxmatch('/\bfeatures\b/i', exclusion_term) then category = 'Feature-related terms';
        else if prxmatch('/\bpromotion\s+rate(?:s)?|balance\s+rate(?:s)?\b/i', exclusion_term) then category = 'Balance Transfers & Interest Rates';
        else if prxmatch('/\btransfer\s+high-rate\s+balances|interest\s+rate(?:s)?\b/i', exclusion_term) then category = 'Balance Transfers & Interest Rates';
        else if prxmatch('/\bcash\s+reward(?:s)?|bonu(?:s9)?\b/i', exclusion_term) then category = 'Rewards & Bonuses';
        else if prxmatch('/\b(intro|introductory)\s+(annual|rate|fee)\b/i', exclusion_term) then category = 'Introductory Offers & Fees';
        else if prxmatch('/\bpercentage\s+rate|apr|annual\s+fee\b/i', exclusion_term) then category = 'Introductory Offers & Fees';
        else if prxmatch('/\bactive\s+cash|autograph|bilt\s+mastercard|reflect|choice\s+privileges\b/i', exclusion_term) then category = 'Specific Card Programs';
        else if prxmatch('/\bpoint(?:s)?|balance\s+transfer|reward(?:s)?\b/i', exclusion_term) then category = 'Rewards & Bonuses';

        /* Assign reasoning based on extracted exclusion category */
        if category ne '' then
            reasoning = cats('Not flagged: Excluded due to "', category, '" (matched term: "', strip(exclusion_term), '")');
        else
            reasoning = 'Not flagged: Pattern did not match';
    end;
    
    drop action1 action2 exclusion_term category;
run;

proc print data=test_results noobs;
    var text match reasoning;
    title "Enhanced Pattern Test Results with Dynamic Exclusion Categories";
run;
