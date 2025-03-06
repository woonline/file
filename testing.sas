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
;
run;

data test_results;
    set freeform;
    retain re;
    /* 
       Compile the enhanced regular expression:
       - (?i) sets case-insensitive matching.
       - Two alternatives are provided:
           1. Credit card reference (or "CC") comes first, then later an action word.
              In this case the action word is captured in group 1.
           2. An action word comes first (captured in group 2), then later the credit card reference.
       - The action words group now includes "apply", "applying", "question", "ask", "questions", 
         and "switch" with variants (switch, switched, switching).
       - The negative lookahead excludes records with words like discuss, rate, feature, or employee.
    */
    if _n_ = 1 then do;
        re = prxparse('/(?i)(?:(?:(?:credit\s+cards?|CC)\b.*?\b((?:apply|applying|aply|applt|open(?:\s+up)?|want(?:s)?(?:\s+information)?|interested|question|ask|questions|switch(?:ed|ing)?)))|(?:(?:(apply|applying|aply|applt|open(?:\s+up)?|want(?:s)?(?:\s+information)?|interested|question|ask|questions|switch(?:ed|ing)?))\b.*?\b(?:credit\s+cards?|CC)))(?!.*\b(?:discuss|rate|feature|employee)\b)/');
        if missing(re) then do;
            put "ERROR: Invalid regular expression.";
            stop;
        end;
    end;

    /* Apply the regular expression to the text field */
    match = prxmatch(re, text);
    
    /* Initialize the reasoning variable */
    length reasoning $200;
    if match then do;
        /* Extract captured action word from either group 1 or group 2 by passing the source string */
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
        reasoning = 'Not flagged: Pattern did not match';
    end;
    
    drop action1 action2;
run;

proc print data=test_results noobs;
    var text match reasoning;
    title "Enhanced Pattern Test Results with Reasoning";
run;
