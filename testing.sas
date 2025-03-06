data test_records;
    length text $200;
    infile datalines dlm='|' dsd truncover;
    input text $char200.;
    datalines;
apply for credit card immediately
I want to apply for a credit card with low rates
credit card apply now please
I have a CC and would like to ask a question about it
ask about credit cards before applying
I want to discuss credit card benefits
credit card
apply
credit card ask
apply credit card, but also discuss features
I would like to know about CC and then apply later
;
run;

data test_results;
    set test_records;
    retain re;
    /* Compile the enhanced regular expression once */
    if _n_ = 1 then do;
        re = prxparse('/(?i)(?:(?:(?:credit\s+cards?|CC)\b.*?\b(?:apply|applying|question|ask|questions))|(?:(?:apply|applying|question|ask|questions)\b.*?\b(?:credit\s+cards?|CC)))(?!.*\b(?:discuss|rate|feature|benefit|employee)\b)/');
        if missing(re) then do;
            put "ERROR: Invalid regular expression.";
            stop;
        end;
    end;
    /* Apply the regular expression to the text field */
    match = prxmatch(re, text);
run;

proc print data=test_results noobs;
    var text match;
    title "Test Results for Enhanced Regular Expression Pattern";
run;
