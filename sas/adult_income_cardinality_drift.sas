
/******************************************************************************
   EXAMPLE: adult_income_cardinality_drift.sas

   DATA: adult_train.csv — Model training period used as baseline
         adult_test.csv  — Model scoring period used as current

   DESCRIPTION: This example demonstrates the use of PROC CARDINALITY in
                SAS Viya Workbench to detect structural data changes between
                a baseline (training) period and a current (scoring) period
                of the Adult Census dataset. Structural changes detected
                include new or disappearing category levels and shifts in
                missing value rates across all input variables.

   PURPOSE: In this example, we use PROC CARDINALITY to profile all variables
            in both the baseline and current datasets, then compare the two
            profiles using PROC SQL to flag variables where cardinality or
            missing rates have changed. This technique serves as an early
            warning system for input data pipeline changes that may silently
            degrade model performance over time.
******************************************************************************/


/******************************************************************************
   STEP 1: Import baseline and current datasets
           Suppress source echo during import to reduce log noise, then
           restore after import completes. Training data serves as the
           baseline reference period; test data represents the current
           scoring batch arriving in the production pipeline
******************************************************************************/

options nosource;

/* Import the training data from CSV into the ADULT_BASELINE work data set   */
proc import
    datafile="&WORKSPACE_PATH./sas-trustworthy-ai-examples/data/adult_train.csv"
    out=adult_baseline dbms=csv replace;
run;

/* Import the test data from CSV into the ADULT_CURRENT work data set        */
proc import
    datafile="&WORKSPACE_PATH./sas-trustworthy-ai-examples/data/adult_test.csv"
    out=adult_current dbms=csv replace;
run;

/* Restore source echo to log for all subsequent program steps               */
options source;


/******************************************************************************
   STEP 2: Run PROC CARDINALITY on baseline and current datasets
           PROC CARDINALITY scans all variables and produces a summary of
           distinct value counts, missing counts, and category levels.
           MAXLEVELS=50 instructs the procedure to store up to 50 distinct
           values per variable in the output dataset for detailed inspection
******************************************************************************/

/* Profile all variables in the baseline (training) dataset                  */
proc cardinality data=adult_baseline
                outcard=card_baseline
                maxlevels=50;
run;

/* Profile all variables in the current (scoring) dataset                    */
proc cardinality data=adult_current
                outcard=card_current
                maxlevels=50;
run;


/******************************************************************************
   STEP 3: Compare baseline vs current cardinality profiles
           Join the two cardinality output datasets on variable name and
           compute three key drift indicators per variable:
             1. Level change     — new or disappeared category levels
             2. Missing rate     — shift in proportion of missing values
             3. Overall status   — ALERT or OK flag for downstream filtering
           Results are sorted so ALERT variables appear first, with the
           largest cardinality changes ranked at the top
******************************************************************************/

proc sql;
    create table structural_drift as
    select
        /* Variable name and type from the baseline cardinality profile      */
        a._varname_                             as variable,
        a._type_                                as var_type,

        /* Cardinality comparison — flag new or lost category levels         */
        a._cardinality_                         as levels_baseline,
        b._cardinality_                         as levels_current,
        b._cardinality_ - a._cardinality_       as level_change,
        case
            when b._cardinality_ gt a._cardinality_
                then 'New Categories Added'
            when b._cardinality_ lt a._cardinality_
                then 'Categories Disappeared'
            else 'No Change'
        end                                     as cardinality_status,

        /* Missing rate comparison — flag increases above 5% and 10%        */
        a._nmiss_                               as missing_baseline,
        b._nmiss_                               as missing_current,
        round((b._nmiss_ - a._nmiss_) /
               a._nobs_ * 100, 0.01)            as missing_rate_change_pct,
        case
            when abs(round((b._nmiss_ - a._nmiss_) /
                 a._nobs_ * 100, 0.01)) gt 10
                then 'High Missing Drift'
            when abs(round((b._nmiss_ - a._nmiss_) /
                 a._nobs_ * 100, 0.01)) gt 5
                then 'Moderate Missing Drift'
            else 'Stable'
        end                                     as missing_status,

        /* Overall alert flag — triggered by any cardinality or missing
           rate change exceeding the defined monitoring thresholds            */
        case
            when b._cardinality_ ne a._cardinality_
              or abs(round((b._nmiss_ - a._nmiss_) /
                 a._nobs_ * 100, 0.01)) gt 5
                then 'ALERT'
            else 'OK'
        end                                     as overall_status

    from card_baseline a
    join card_current  b
        on a._varname_ = b._varname_

    /* Sort so ALERT variables appear first, largest changes at the top      */
    order by overall_status desc,
             abs(level_change) desc;
quit;


/******************************************************************************
   STEP 4: Print full structural drift report across all variables
           Displays cardinality and missing rate changes side by side for
           every variable in the dataset to provide a complete audit trail
           of structural changes between the baseline and current periods
******************************************************************************/

proc print data=structural_drift noobs;
    title "Structural Data Drift Report — Adult Dataset";
    var variable var_type
        levels_baseline levels_current level_change cardinality_status
        missing_baseline missing_current missing_rate_change_pct
        missing_status overall_status;
run;


/******************************************************************************
   STEP 5: Isolate variables flagged as ALERT for immediate action
           Filters the full drift report to show only variables requiring
           investigation before the next model scoring run proceeds.
           These variables should be reviewed by the modeling team to
           determine whether retraining or data remediation is needed
******************************************************************************/

proc print data=structural_drift noobs;
    where overall_status = 'ALERT';
    var variable cardinality_status level_change
        missing_status missing_rate_change_pct;
    title "ACTION REQUIRED — Variables with Structural Changes";
run;


/******************************************************************************
   STEP 6: Drill into specific variable detail using PROC FREQ
           Occupation is a common drifter in the Adult dataset as job
           categories evolve over time. Comparing exact levels between
           baseline and current identifies which specific values changed,
           appeared, or disappeared across the two scoring periods
******************************************************************************/

/* Display occupation category levels from the baseline training data        */
proc freq data=adult_baseline;
    tables occupation / missing nocum;
    title "Occupation Levels — Baseline";
run;

/* Display occupation category levels from the current scoring batch
   and manually inspect for new or missing values vs baseline                */
proc freq data=adult_current;
    tables occupation / missing nocum;
    title "Occupation Levels — Current (check for new/missing levels)";
run;


/******************************************************************************
   STEP 7: Append drift results to longitudinal history table
           Adding a check_date timestamp allows trend monitoring over
           multiple scoring periods to track whether drift is worsening,
           stable, or resolving across the model deployment lifecycle.
           PROC APPEND adds current results without overwriting history
******************************************************************************/

/* Add today's date as the monitoring checkpoint timestamp                   */
data structural_drift_dated;
    set structural_drift;
    check_date = today();
    format check_date date9.;
run;

/* Append current period results to the persistent drift history table       */
proc append base=structural_drift_history
            data=structural_drift_dated
            force;
run;


/******************************************************************************
   STEP 8: Visualize category level changes across all variables
           Horizontal bar chart colored by magnitude of change helps
           prioritize which variables need the most urgent investigation.
           Green indicates stable, yellow moderate, red significant change.
           The gray reference line at zero distinguishes variables where
           categories were gained from those where categories were lost
******************************************************************************/

proc sgplot data=structural_drift;
    hbar variable / response=level_change
                    colorresponse=level_change
                    colormodel=(green yellow red);

    /* Reference line at zero distinguishes gains from losses in levels      */
    refline 0 / axis=x lineattrs=(color=gray);

    title "Category Level Change by Variable — Baseline vs Current";
    xaxis label="Change in Number of Distinct Levels";
    yaxis label="Variable";
run;