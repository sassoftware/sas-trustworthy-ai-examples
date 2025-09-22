/******************************************************************************
   EXAMPLE: adult_assess_bias.sas

   DATA: adult_train.csv (training data)
         adult_test.csv  (test data)

   DESCRIPTION: The Adult data set contains demographic and employment
                information such as age, education, occupation, and hours
                worked per week. The target variable indicates whether an
                individual earns more than $50K per year.

   PURPOSE: In this example, we build a Random Forest classification model
            on the Adult training data to predict income level. We then
            score the test data using the saved ASTORE, persist the model
            to disk, and assess the model for bias across the sensitive
            variable SEX using PROC ASSESSBIAS.
******************************************************************************/


/******************************************************************************
   Load the training and test data and show that the data is ready for use.
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

options source;

/* Print a sample of the training data to confirm successful import          */
title2 'Portion of adult_train input data';
proc print data=adult_train(obs=10);
run;


/******************************************************************************
   Build a Random Forest classification model on the ADULT_TRAIN data set.

   Since the data is now available for the SAS analytic procedures to use,
   we are ready to start the analysis. PROC FOREST builds an ensemble of
   decision trees to predict the binary income target. The trained model is
   saved as an ASTORE for subsequent scoring and deployment. All input
   variables are copied to the scored output data set for downstream use.
******************************************************************************/

title2 'FOREST on adult_train data';

proc forest data=adult_train seed=12345;
    /* Continuous predictor variables                                        */
    input age fnlwgt education_num capital_gain
          capital_loss hours_per_week / level=interval;
    /* Categorical predictor variables                                       */
    input workclass education marital_status occupation
          relationship race sex native_country / level=nominal;
    target target / level=nominal;          /* Binary income target variable */
    savestate rstore=dtstore;               /* Save trained model to ASTORE  */
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
    describe rstore=dtstore;                          /* Display model metadata   */
    score data=adult_test rstore=dtstore              /* Score the test data      */
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
   Assess the Random Forest model for bias across the sensitive variable SEX.

   PROC ASSESSBIAS evaluates whether the model's predicted probabilities and
   classifications differ systematically across demographic groups. Here we
   examine whether predicted income outcomes are equitable across SEX, using
   5 cutpoints and 5 bins for the analysis.
******************************************************************************/

proc assessbias data=adult_scored ncuts=5 nbins=5;
    var P_target_50K;                          /* Predicted probability variable  */
    target I_target / event=">50K"             /* Observed target, positive event */
                      level=nominal;
    fitstat pvar=P_target__50K /               /* Fit statistics for the model    */
            pevent="<=50K";
    sensitiveVar sex;                          /* Demographic variable to assess  */
run;