/******************************************************************************
   EXAMPLE: adut_income_psi.sas

   DATA: adult_train.csv — Model training period used as Q1 baseline
         adult_test.csv  — Model scoring period used as Q2 current

   DESCRIPTION: This example demonstrates the use of PROC FREQ and PROC SQL
                to detect distributional drift in the race variable of the
                Adult Census dataset across two time periods. A chi-square
                test is used to flag statistical significance of the shift,
                and the Population Stability Index (PSI) is computed manually
                to quantify the magnitude of drift between Q1 and Q2.

   PURPOSE: In this example, we combine training and scoring datasets into a
            single longitudinal dataset, compare the distribution of the race
            variable across periods using PROC FREQ, and compute PSI via
            PROC SQL to classify drift severity as No Drift, Moderate Drift,
            or Significant Drift. This technique supports proactive model
            monitoring by detecting feature distribution changes before they
            silently degrade model performance.
******************************************************************************/


/******************************************************************************
   STEP 1: Suppress source code echo during data import
           OPTIONS NOSOURCE suppresses the SAS source statements from the log
           during import to reduce log noise; restored after import completes
******************************************************************************/

options nosource;

/* Import the training data from CSV into the ADULT_TRAIN work data set      */
proc import
    datafile="&WORKSPACE_PATH./sas-trustworthy-ai-examples/data/adult_train.csv"
    out=adult_train dbms=csv replace;
run;

/* Import the test data from CSV into the ADULT_TEST work data set           */
proc import
    datafile="&WORKSPACE_PATH./sas-trustworthy-ai-examples/data/adult_test.csv"
    out=adult_test dbms=csv replace;
run;

/* Restore source echo to log for all subsequent program steps               */
options source;


/******************************************************************************
   STEP 2: Confirm successful data import
           Print the first 10 observations of the training dataset to verify
           variable names, formats, and values loaded correctly from CSV
******************************************************************************/

/* Print a sample of the training data to confirm successful import          */
title2 'Portion of adult_train input data';
proc print data=adult_train(obs=10);
run;


/******************************************************************************
   STEP 3: Assign period labels to baseline and current datasets
           Tag the training dataset as Q1 (baseline) and the test dataset
           as Q2 (current) to enable period-based comparisons downstream.
           In production, these labels would reflect actual scoring periods
******************************************************************************/

/* Tag training data as Q1 baseline period for longitudinal comparison       */
data adult_baseline;
    set adult_train;
    period="Q1";
run;

/* Tag test data as Q2 current period representing the scoring batch         */
data adult_current;
    set adult_test;
    period="Q2";
run;


/******************************************************************************
   STEP 4: Combine baseline and current datasets into one longitudinal table
           Stacking both periods into a single dataset allows PROC FREQ and
           PROC SQL to compare distributions across periods in one pass
******************************************************************************/

/* Combine Q1 baseline and Q2 current into a single longitudinal dataset     */
data adult_combined;
    set adult_baseline adult_current;
run;


/******************************************************************************
   STEP 5: Chi-square test for distributional shift in race variable
           PROC FREQ cross-tabulates period against race and applies a
           chi-square test to determine whether the difference in race
           distributions between Q1 and Q2 is statistically significant.
           A significant p-value indicates distributional drift has occurred
******************************************************************************/

title2;
title3 'Output of Proc Freq';

proc freq data=adult_combined;
    tables period * race / chisq;
    /* Chi-square p-value flags distributional shift                         */
run;


/******************************************************************************
   STEP 6: Compute raw frequency percentages for PSI calculation
           PROC FREQ with OUTPCT writes column percentages for each
           period-race combination to FREQ_OUT. The NOPRINT option suppresses
           the default output table since the output dataset is used directly
           in the PSI calculation in the next step
******************************************************************************/

/* Compute PSI manually using PROC FREQ output                               */
proc freq data=adult_combined noprint;
    tables period * race / outpct out=freq_out;
run;

title3;


/******************************************************************************
   STEP 7: Compute PSI contribution per race category and total PSI score
           PSI measures the magnitude of distributional shift between Q1
           and Q2 for each race level using the formula:
             PSI = SUM( (pct_curr - pct_base) * LN(pct_curr / pct_base) )
           Each race category contributes a partial PSI value; the total
           PSI score across all categories determines overall drift severity:
             PSI < 0.10  — No Drift
             PSI < 0.20  — Moderate Drift, increase monitoring frequency
             PSI >= 0.20 — Significant Drift, investigate and retrain model
******************************************************************************/

proc sql;
    /* Pivot Q1 and Q2 percentages into columns and compute PSI contribution
       per race category using the standard PSI formula                      */
    create table psi_calc as
    select  race,
            max(case when period='Q1' then pct_col/100 else 0 end) as pct_base,
            max(case when period='Q2' then pct_col/100 else 0 end) as pct_curr,

            /* PSI formula — contribution from each race category            */
            (max(case when period='Q2' then pct_col/100 else 0 end) -
             max(case when period='Q1' then pct_col/100 else 0 end)) *
            log(max(case when period='Q2' then pct_col/100 else 0 end) /
                max(case when period='Q1' then pct_col/100 else 0 end))
                as psi_contrib
    from freq_out
    group by race;

    title4 'Drift status report';

    /* Sum PSI contributions across all race categories and classify drift   
       severity based on standard PSI thresholds used in model monitoring    */
    select sum(psi_contrib) as total_psi,
           case when sum(psi_contrib) < 0.10 then 'No Drift'
                when sum(psi_contrib) < 0.20 then 'Moderate Drift - Monitor'
                else                              'Significant Drift - Action Required'
           end as drift_status
    from psi_calc;

quit;

title4;