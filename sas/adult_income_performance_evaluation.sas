/******************************************************************************
   EXAMPLE: adult_confusion_matrix.sas

   DATA: adult_train (training data)
         adult_test  (test data)

   DESCRIPTION: The Adult data set contains demographic and employment
                information such as age, education, occupation, and hours
                worked per week. The target variable indicates whether an
                individual earns more than $50K per year.

   PURPOSE: In this example, we build a Random Forest classification model
            on the Adult training data to predict income level. We then
            score the test data using the saved ASTORE and evaluate model
            performance using PROC ASSESS, which produces Lift charts, ROC
            curves, and fit statistics. Results are broken out by SEX to
            examine whether model performance differs across demographic groups.
******************************************************************************/

options nosource;
proc import
    datafile="&WORKSPACE_PATH./sas-trustworthy-ai-examples/data/adult_train.csv"
    out=adult_train dbms=csv replace;
run;
proc import
    datafile="&WORKSPACE_PATH./sas-trustworthy-ai-examples/data/adult_test.csv"
    out=adult_test dbms=csv replace;
run;
options source;

title2 'Portion of adult_train input data';
proc print data=adult_train(obs=10);
run;

/******************************************************************************

 Since the data is now available for the SAS® analytic procedures to use,
 we are ready to start the analysis. We will start by building a Forest model
 on the ADULT_TRAIN data set and save the model as an analytic store.

******************************************************************************/

/******************************************************************************
   Build a Random Forest classification model on the ADULT_TRAIN data set.

   PROC FOREST builds an ensemble of decision trees to predict the binary
   income target. The trained model is saved as an ASTORE for subsequent
   scoring. All input variables are copied to the scored output data set
   for use in downstream assessment steps.
******************************************************************************/

title2 'FOREST on adult_train data';

proc forest data=adult_train seed=12345;
    /* Continuous predictor variables                                        */
    input age fnlwgt education_num capital_gain
          capital_loss hours_per_week / level=interval;
    /* Categorical predictor variables                                       */
    input workclass education marital_status occupation
          relationship race sex native_country / level=nominal;
    target target / level=nominal;            /* Binary income target variable  */
    savestate rstore=dtstore;                 /* Save trained model to ASTORE   */
    output out=adult_scored copyVars=(_ALL_); /* Score training data, keep all vars */
run;

/* Print a sample of the scored training output to verify predictions        */
proc print data=adult_scored(obs=5);
run;


/******************************************************************************
   Describe the ASTORE model and score the held-out test data.

   Describing the ASTORE gives us metadata about the trained model structure.
   We then use it to score the test data and save the predictions in the
   ADULT_SCOREOUT data set. A sample of the results are printed for review.
******************************************************************************/

title2 'ASTORE describe and scoring';
proc astore;
    describe rstore=dtstore;                /* Display model metadata            */
    score data=adult_test rstore=dtstore    /* Score the held-out test data      */
          out=adult_scoreout;
run;

/* Print a sample of the test scoring results                                */
proc print data=adult_scoreout(obs=5);
run;


/******************************************************************************
   Save the trained ASTORE model to a persistent file on disk.

   ASTOREs can be saved as files for use in subsequent programs or entirely
   different environments, enabling model reuse without retraining.
******************************************************************************/

title2 'Saving the astore into a file';
proc astore;
    download rstore=dtstore store="/tmp/dtstore.sasast"; /* Persist model to disk */
run;


/******************************************************************************
   Evaluate model performance using Lift, ROC, and fit statistics.

   PROC ASSESS computes a comprehensive set of model evaluation metrics for
   the binary classification model:

   - Lift chart:    Shows how much better the model identifies the positive
                    class (">50K") compared to a random selection baseline.
   - ROC curve:     Plots the true positive rate against the false positive
                    rate across all classification thresholds, summarized by
                    the area under the curve (AUC).
   - Fit statistics: Includes the confusion matrix, misclassification rate,
                    Gini coefficient, and KS statistic.

   Results are stratified by SEX using the BY statement so that performance
   differences across demographic groups can be identified and compared.
******************************************************************************/

title2 'Lift/ROC and Fit Statistics';

proc assess data=adult_scored;
    var    P_target_50K;                    /* Predicted probability for >50K    */
    target I_target / event  = ">50K"       /* Observed target, positive event   */
                      level  = nominal;
    fitstat pvar   = P_target__50K /        /* Predicted probability for <=50K   */
            pevent = "<=50K";               /* Non-event level for fit statistics */
by sex;                                     /* Stratify all metrics by SEX       */
run;




/******************************************************************************
   EXAMPLE: proc_assess_explainability.sas

   DATA: adult_train.csv — Model training period used as baseline
         adult_test.csv  — Model scoring period used as current

   DESCRIPTION: This example demonstrates the use of PROC ASSESS in SAS Viya
                Workbench to evaluate model performance through explainability
                and transparency lenses. PROC ASSESS reports key metrics
                including ROC curves, AUC, KS statistic, and gains charts
                that help stakeholders understand not just how well a model
                performs but where, why, and for whom it performs differently
                across population segments of the Adult Census dataset.

   PURPOSE: In this example, we use PROC ASSESS to produce discrimination
            metrics, segment-level performance breakdowns, and visual
            diagnostic outputs that support transparent model reporting.
            These outputs enable data scientists, model validators, and
            business stakeholders to interpret model behavior, identify
            performance gaps across demographic groups, and make informed
            decisions about model deployment, monitoring, and retraining.
******************************************************************************/


/******************************************************************************
   STEP 1: Import baseline and current datasets
           Suppress source echo during import to reduce log noise, then
           restore after import completes. Training data serves as the
           baseline reference period; test data represents the current
           scoring period used for out-of-sample performance evaluation
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
   STEP 2: Train logistic regression model on baseline data
           PROC LOGISTIC fits a binary classification model predicting
           whether income exceeds 50K. The OUTMODEL= option saves the
           fitted model object so it can be applied to the test dataset
           without refitting, ensuring a fair out-of-sample evaluation.
           OUTPUT statement writes predicted probabilities to a dataset
           for use in PROC ASSESS performance evaluation downstream
******************************************************************************/

/* Fit logistic regression model and save predicted probabilities            */
proc logistic data=adult_train outmodel=logit_model;
    class workclass education marital_status
          occupation relationship race sex / param=ref;
    model target(event='>50K') =
          age education_num capital_gain
          capital_loss hours_per_week
          workclass education marital_status
          occupation relationship race sex;

    /* Write predicted probabilities to output dataset for PROC ASSESS       */
    output out=scored_train predicted=pred_prob;
run;


/******************************************************************************
   STEP 3: Score the current (test) dataset using the saved model
           Applying the saved model object to unseen test data produces
           out-of-sample predicted probabilities that reflect true model
           generalization. This separation of training and scoring is
           essential for transparent and unbiased performance reporting
******************************************************************************/

/* Apply saved model to test data and generate predicted probabilities       */
proc logistic inmodel=logit_model;
    score data=adult_test
          out=scored_test
          predicted=pred_prob;
run;


/******************************************************************************
   STEP 4: Overall model performance — ROC curve and AUC
           PROC ASSESS computes the Area Under the ROC Curve (AUC) which
           measures overall discrimination ability of the model. An AUC
           of 1.0 is perfect; 0.5 is no better than random guessing.
           The ROC curve plots sensitivity against 1-specificity across
           all classification thresholds, providing a transparent visual
           summary of the tradeoff between true and false positive rates.
           NBINS=10 groups predictions into deciles for gains chart output
******************************************************************************/

title2 'Overall Model Performance — ROC Curve and AUC';

proc assess data=scored_test
            nbins=10;

    /* Specify predicted probability variable as model input score           */
    input pred_prob;

    /* Specify binary target variable and the event level being predicted    */
    target target / event='>50K' level=nominal;

    /* ROC statement produces the ROC curve and AUC discrimination metric    */
    roc;

    /* KS statement produces the Kolmogorov-Smirnov separation statistic
       measuring maximum separation between event and non-event score
       distributions — a key metric for model ranking transparency           */
    ks;

    /* FITSTAT produces model fit statistics including AUC, Gini coefficient
       and other discrimination metrics written to an output dataset          */
    fitstat pvar=pred_prob /
            out=assess_overall;

run;

title2;


/******************************************************************************
   STEP 5: Segment-level performance — explainability by demographic group
           Evaluating model performance separately across demographic
           segments reveals whether the model discriminates equally well
           for all subpopulations. Performance gaps across race, sex, or
           education groups are a key explainability and fairness concern
           that must be documented for transparent model governance
******************************************************************************/

/* Performance assessment segmented by sex                                   */
title2 'Model Performance by Sex — Explainability Segment View';

proc assess data=scored_test
            nbins=10;
    input pred_prob;
    target target / event='>50K' level=nominal;

    /* BY statement produces separate ROC and KS metrics per sex category    */
    by sex;
    roc;
    ks;
    fitstat pvar=pred_prob /
            out=assess_by_sex;
run;

title2;

/* Performance assessment segmented by race                                  */
title2 'Model Performance by Race — Explainability Segment View';

proc assess data=scored_test
            nbins=10;
    input pred_prob;
    target target / event='>50K' level=nominal;

    /* BY statement produces separate metrics per race category               */
    by race;
    roc;
    ks;
    fitstat pvar=pred_prob /
            out=assess_by_race;
run;

title2;

/* Performance assessment segmented by education level                       */
title2 'Model Performance by Education — Explainability Segment View';

proc assess data=scored_test
            nbins=10;
    input pred_prob;
    target target / event='>50K' level=nominal;
    by education;
    roc;
    ks;
    fitstat pvar=pred_prob /
            out=assess_by_education;
run;

title2;


/******************************************************************************
   STEP 6: Consolidate segment AUC scores into a single comparison table
           Collecting AUC values across demographic segments into one table
           enables side-by-side comparison of model discrimination ability
           across groups. Large AUC gaps between segments are a transparency
           red flag that should be disclosed in model documentation and
           reviewed by model risk and governance stakeholders
******************************************************************************/

/* Extract AUC from each segment assessment output and combine               */
proc sql;
    create table segment_auc_summary as

    /* Overall AUC benchmark                                                 */
    select  'Overall'       as segment,
            'All'           as segment_value,
            c_statistic     as auc
    from assess_overall
    where statistic = 'C'

    union all

    /* AUC by sex segment                                                    */
    select  'Sex',
            sex,
            c_statistic
    from assess_by_sex
    where statistic = 'C'

    union all

    /* AUC by race segment                                                   */
    select  'Race',
            race,
            c_statistic
    from assess_by_race
    where statistic = 'C'

    union all

    /* AUC by education segment                                              */
    select  'Education',
            education,
            c_statistic
    from assess_by_education
    where statistic = 'C'

    order by segment, auc desc;
quit;

/* Print segment AUC comparison table for transparency reporting             */
title2 'AUC by Demographic Segment — Model Explainability Report';
proc print data=segment_auc_summary noobs;
    var segment segment_value auc;
    format auc 8.4;
run;
title2;


/******************************************************************************
   STEP 7: Visualize AUC gaps across demographic segments
           A dot plot of AUC scores by segment group provides a transparent
           visual summary of performance equity across the population.
           The overall AUC reference line anchors the chart so stakeholders
           can immediately see which segments are above or below average
           model performance — a key output for fairness documentation
******************************************************************************/

/* Compute overall AUC value for reference line                              */
proc sql noprint;
    select auc into :overall_auc
    from segment_auc_summary
    where segment = 'Overall';
quit;

/* Dot plot of AUC scores across all demographic segments                    */
title2 'Model Performance Equity — AUC by Demographic Segment';

proc sgplot data=segment_auc_summary;

    /* Dot plot shows AUC value per segment level                            */
    dot segment_value / response=auc
                        group=segment
                        markerattrs=(size=10);

    /* Reference line marks overall model AUC for comparison baseline        */
    refline &overall_auc. / axis=x
                            lineattrs=(color=gray pattern=dash)
                            label="Overall AUC";

    title2 "AUC by Segment — Transparency and Fairness View";
    xaxis label="AUC Score" min=0.5 max=1.0;
    yaxis label="Segment Value";
run;

title2;


/******************************************************************************
   STEP 8: Append performance metrics to longitudinal tracking history
           Storing AUC and KS statistics at each scoring period enables
           trend monitoring over the model deployment lifecycle. Declining
           AUC or widening segment gaps over time are early indicators
           that model retraining or recalibration should be initiated
******************************************************************************/

/* Add scoring date timestamp to the overall assessment output               */
data assess_dated;
    set assess_overall;
    score_date = today();
    format score_date date9.;
run;

/* Append current period metrics to persistent performance history table     */
proc append base=performance_history
            data=assess_dated
            force;
run;


/******************************************************************************
   STEP 9: AUC trend chart over time
           Plotting AUC across scoring periods provides a transparent
           longitudinal view of model health. A sustained downward trend
           in AUC signals concept drift and should trigger a formal model
           review, retraining evaluation, or escalation to model governance
******************************************************************************/

/* Line chart of AUC over scoring periods for longitudinal transparency      */
title2 'AUC Trend Over Time — Model Performance Monitoring';

proc sgplot data=performance_history;
    series x=score_date y=c_statistic / markers
                                        lineattrs=(color=blue);

    /* Reference lines mark standard AUC performance thresholds              */
    refline 0.80 / axis=y lineattrs=(color=green  pattern=dash)
                           label="Good (0.80)";
    refline 0.70 / axis=y lineattrs=(color=orange pattern=dash)
                           label="Acceptable (0.70)";
    refline 0.60 / axis=y lineattrs=(color=red    pattern=dash)
                           label="Poor (0.60)";

    title2 "AUC Over Time — Retrain if Sustained Decline Observed";
    xaxis label="Scoring Date";
    yaxis label="AUC" min=0.5 max=1.0;
run;

title2;