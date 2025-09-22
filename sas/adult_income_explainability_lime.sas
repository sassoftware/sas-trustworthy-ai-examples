/******************************************************************************
   EXAMPLE: adult_income_lime_explainability.sas

   DATA: adult_train.csv — Model training data used as reference population
         adult_test.csv  — Model scoring data from which query observation
                           is selected for individual prediction explanation

   DESCRIPTION: This example demonstrates the use of PROC FOREST, PROC ASTORE,
                and PROC LIME in SAS Viya Workbench to train a random forest
                model on the Adult Census dataset and generate locally
                interpretable explanations for individual predictions.
                PROC LIME (Local Interpretable Model-agnostic Explanations)
                explains why the model assigned a specific predicted income
                class to a single observation by identifying which input
                features contributed most to that individual prediction.

   PURPOSE: In this example, we train a random forest classifier to predict
            whether individual income exceeds 50K annually, save the trained
            model as an analytic store (ASTORE), extract the DS2 scoring code
            for use by PROC LIME, and generate a local explanation for a
            single query observation selected from the test dataset. This
            technique supports model explainability and transparency by
            providing human-interpretable feature-level explanations for
            individual predictions — a key requirement for trustworthy AI
            governance and regulatory compliance in high-stakes decisions.
******************************************************************************/


/******************************************************************************
   STEP 1: Import training and test datasets
           Suppress source echo during import to reduce log noise, then
           restore after import completes. Training data is used to fit
           the random forest model and serves as the reference population
           for PROC LIME local explanation generation. Test data provides
           the query observation whose prediction will be explained
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

/* Print a sample of training data to confirm successful import              */
title2 'Portion of adult_train input data';
proc print data=adult_train(obs=10);
run;
title2;


/******************************************************************************
   STEP 2: Prepare the reference dataset for model training and LIME
           Select the variables relevant to income prediction and assign
           a unique row identifier using the automatic _N_ variable.
           The ID variable is required by PROC LIME to link local
           explanations back to specific observations in the reference
           population. Only numeric and key categorical features are
           retained to keep the model focused and interpretable
******************************************************************************/

/* Prepare training reference dataset with unique row ID and selected vars   */
data adult_reference;
    set adult_train;

    /* Assign unique observation identifier for PROC LIME linkage            */
    id = _N_;

    /* Retain continuous interval variables for model input                  */
    /* Retain key categorical nominal variables for model input              */
    /* Retain binary income target variable for model training               */
    keep id
         age education_num capital_gain capital_loss hours_per_week
         workclass marital_status occupation sex race
         target;
run;


/******************************************************************************
   STEP 3: Prepare the query observation for individual explanation
           Select a single observation from the test dataset whose
           prediction the model will explain using PROC LIME. The query
           observation represents a real individual whose income prediction
           requires a human-interpretable explanation — for example to
           support a loan decision, audit review, or regulatory inquiry.
           _N_ = 20 selects the 20th observation; adjust as needed
******************************************************************************/

/* Select a single query observation from the test dataset for explanation   */
data adult_query;
    set adult_test;

    /* Retain the same input variables used during model training            */
    keep age education_num capital_gain capital_loss hours_per_week
         workclass marital_status occupation sex race
         target;

    /* Select the 20th observation as the individual prediction to explain   */
    if _N_ = 5;
run;

/* Print the selected query observation to confirm correct record selected   */
title2 'Query Observation Selected for LIME Explanation';
proc print data=adult_query noobs;
run;
title2;


/******************************************************************************
   STEP 4: Train random forest classifier using PROC FOREST
           PROC FOREST fits an ensemble of decision trees to predict the
           binary income target variable. MAXDEPTH=4 limits individual
           tree depth to prevent overfitting and improve interpretability
           of the underlying model structure. SEED= ensures reproducibility
           of the random forest training process across runs.
           SAVESTATE writes the trained model to an analytic store (ASTORE)
           object which preserves the full model for scoring and explanation
           without requiring retraining in downstream procedures
******************************************************************************/

/* Train random forest model and save to analytic store for PROC LIME use    */
proc forest
    data=adult_reference
    maxDepth=4
    seed=1234;

    /* Continuous interval inputs: age, education, capital gains and hours   */
    input age education_num capital_gain capital_loss hours_per_week /
          level=interval;

    /* Categorical nominal inputs: employment, marital, occupation, demographics */
    input workclass marital_status occupation sex race /
          level=nominal;

    /* Binary target: income above or below 50K annual threshold             */
    target target;

    /* Save trained model as analytic store for use in PROC ASTORE and LIME  */
    savestate rstore=forest_astore;
run;


/******************************************************************************
   STEP 5: Extract DS2 scoring code from the analytic store using PROC ASTORE
           PROC ASTORE describes the saved analytic store and exports the
           DS2 scoring code that implements the trained random forest model.
           This DS2 code is required by PROC LIME to score the synthetic
           neighborhood observations it generates around the query point
           during local explanation construction. The code is written to
           a file path accessible to the SAS Viya compute server session
******************************************************************************/

/* Extract DS2 scoring code from analytic store to file for PROC LIME use    */
proc astore;
    describe rstore=forest_astore
             epcode="&WORKSPACE_PATH./DS2code.sas";
run;


/******************************************************************************
   STEP 6: Modify extracted DS2 scoring code for PROC LIME compatibility
           PROC LIME requires the DS2 scoring code to not contain KEEP
           statements that would drop variables needed during local
           explanation scoring. This DATA step reads the raw DS2 code,
           accumulates it into a single character string, removes all
           KEEP statements using PRXCHANGE regular expression substitution,
           and writes the modified code to a new file. The modified file
           is then passed to PROC LIME via the CODE= option in Step 7
******************************************************************************/

/* Remove KEEP statements from DS2 scoring code for PROC LIME compatibility  */
data _null_;
    /* Declare long character variable to accumulate full DS2 code content   */
    length allcode $30000.;
    retain allcode;

    /* Write modified DS2 code to new file for PROC LIME consumption         */
    file "&WORKSPACE_PATH./DS2Code_modified.sas";

    /* Read raw DS2 code line by line from the file produced by PROC ASTORE  */
    infile "&WORKSPACE_PATH./DS2code.sas" end=eof;
    input;

    /* Append each line to the accumulated code string with newline separator */
    allcode = cats(allcode, _infile_, '0A'x);

    /* On final line: remove all KEEP statements then write modified code    */
    if eof then do;

        /* PRXCHANGE applies regex substitution to remove keep[...]; blocks  */
        allcode = prxchange('s/keep[^;]*;//', 1, allcode);

        /* Write the cleaned DS2 code to the modified output file            */
        put allcode;
    end;
run;


/******************************************************************************
   STEP 7: Generate local prediction explanation using PROC LIME
           PROC LIME implements the LIME algorithm which explains individual
           predictions by generating a synthetic neighborhood of perturbed
           observations around the query point, scoring each with the black
           box model, and fitting a simple interpretable surrogate model
           (weighted linear regression) to the local neighborhood scores.
           The surrogate model coefficients identify which features and
           values most influenced the model prediction for that individual.

           Key options:
             DATA=          Query observation requiring explanation
             referenceData= Training population for neighborhood generation
             SEED=          Random seed for reproducible neighborhood sampling
             predictedTarget= Predicted probability variable from model scoring
             astoreModel=   Saved random forest analytic store object
             CODE=          Modified DS2 scoring code for neighborhood scoring
******************************************************************************/

/* Generate LIME local explanation for the selected query observation        */
proc lime
    data=adult_query
    referenceData=adult_reference
    seed=12345;

    /* Continuous interval inputs matching those used in PROC FOREST         */
    input age education_num capital_gain capital_loss hours_per_week /
          level=interval;

    /* Categorical nominal inputs matching those used in PROC FOREST         */
    input workclass marital_status occupation sex race /
          level=nominal;

    /* Predicted probability variable for the income >50K event class        */
    predictedTarget P_target_50K;

    /* Reference to the saved random forest analytic store model object      */
    astoreModel rstore=forest_astore;

    /* Modified DS2 scoring code with KEEP statements removed for LIME use   */
    code file="&WORKSPACE_PATH./DS2Code_modified.sas";
run;