/******************************************************************************
   EXAMPLE: adult_income_performance_evaluation.sas

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





    yaxis label="AUC" min=0.5 max=1.0;
run;

title2;
