/* Create synthetic email dataset */
data work.emails_raw;
	infile datalines dlm='|' dsd truncover;
  input Email_ID Sender: $50. Subject: $100. Email_Content: $500.;
  datalines;
1 |"John Doe" |"Refund Request" |"I am extremely disappointed with the defective product I received. Please process a refund immediately."
2 |"Jane Smith" |"Delivery Feedback" |"The delayed delivery caused major issues. Your logistics team is unresponsive."
3 |"Alex Brown" |"Positive Review" |"I’m happy with the service! The refund policy was clearly explained."
4 |"Maria Garcia" |"Billing Complaint" |"I was overcharged and noticed a billing error. This is unacceptable."
5 |"Sam Wilson" |"Technical Issue" |"The app crashes constantly. Worst experience ever!"
6 |"Emily Davis"| "General Inquiry" |"Can you clarify your pricing plans? Thanks!"
7 |"Chris Lee" |"Security Concern" |"There might be a security breach in my account. Please investigate."
8 |"Laura Kim" |"Cancellation" |"I want to cancel my account due to poor service from rude staff."
9 |"Mike Jones" |"False Advertising" |"Your ad promised features that don’t work. This is false advertising."
10 |"Sarah Miller" |"Happy Customer" |"The product works perfectly. No complaints here!"
;
run;



/* Step 1: Define Enhanced Lexicon */
/*Lexicon with Scenario-Specific Terms*/

data work.lexicon;
infile datalines dlm='|' dsd truncover;
input keyword: $50. category: $20. weight:8.2;
datalines;
unhappy | sentiment | 0.8
refund|financial|0.9
poor service|service_issue|1.0
not working|technical|0.7
overcharged|financial|1.2
defective|product_quality|1.1
delayed delivery|logistics|0.8
ignore my emails|communication|1.0
never again|loyalty|1.5
false advertising|legal|1.3
rude staff|service_issue|1.2
security breach|safety|1.8
waste of money|financial|1.0
sue|legal|1.7
disappointed|sentiment|0.9
frustrated|sentiment|1.0
cancel my account|loyalty|1.4
broken|product_quality|1.1
billing error|financial|1.0
not responding|communication|1.2
;
run;

/* Step 2: Preprocess Email Content */
data work.emails_cleaned;
  set work.emails_raw;
  clean_text = lowcase(compress(Email_Content, , 'punct')); /* Lowercase + remove punctuation */
run;

/* Step 3: Score Emails Using Lexicon */
data work.scored_emails;
  set work.emails_cleaned;
  complaint_score = 0;
  length categories $500.;

  /* Load lexicon into hash object */
  if _n_ = 1 then do;
    declare hash lex(dataset: "work.lexicon");
    lex.defineKey("keyword");
    lex.defineData("weight", "category");
    lex.defineDone();
    declare hiter iter("lex");
  end;

  /* Iterate through lexicon terms */
  do while(iter.next() = 0);
    if prxmatch("/\b" || strip(keyword) || "\b/i", clean_text) > 0 then do;
      complaint_score + weight;
      categories = catx(", ", categories, category);
    end;
  end;

  /* Flag high-risk complaints */
  complaint_flag = ifn(complaint_score >= 1.5, 1, 0);
run;

/* Step 4: Report Flagged Emails */
proc print data=work.scored_emails(where=(complaint_flag=1));
  var Email_ID Sender Subject complaint_score categories Email_Content;
  title "Flagged Complaints";
run;

/* Step 5: Validation Summary */
proc freq data=work.scored_emails;
  tables complaint_flag / nocum;
  title "Complaint Detection Summary";
run;

proc freq data=work.scored_emails;
  tables category*complaint_flag / norow nocol;
  where complaint_flag = 1;
  title "Complaint Category Breakdown";
run;
