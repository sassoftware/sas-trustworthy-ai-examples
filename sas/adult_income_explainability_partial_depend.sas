/******************************************************************************
   EXAMPLE: adult_income_explainability_partial_depend.sas

   DATA: adult_train

   DESCRIPTION: The Adult data set contains demographic and employment
                information such as age, education, occupation, and hours
                worked per week. The target variable indicates whether an
                individual earns more than $50K per year.

   PURPOSE: In this example, we use PROC PARTIALDEPEND to compute the partial
            dependence of AGE on the predicted probability of earning more
            than $50K. Partial dependence isolates the marginal effect of a
            single input variable by averaging out the contribution of all
            other predictors. The analysis uses a previously trained decision
            tree model loaded from an ASTORE.
******************************************************************************/

/******************************************************************************

 Load the training and test data and show that the data is ready for use.

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


title2 'FOREST on adult_train data';

proc forest data=adult_train seed=12345;
    input age fnlwgt education_num capital_gain
          capital_loss hours_per_week / level=interval;
    input workclass education marital_status occupation
          relationship race sex native_country / level=nominal;
    target target / level=nominal;
    savestate rstore=dtstore;
    output out=adult_scored copyVars=(_ALL_);
    
run;
proc print data =adult_scored(obs=5);
run;
/******************************************************************************

 Describing the astore gives us information about the model. We then use it
 to score the test data and save the result in the ADULT_SCOREOUT data set.
 A sample of the results are printed.

******************************************************************************/

title2 'ASTORE describe and scoring';
proc astore;
    describe rstore=dtstore;
    score data=adult_test rstore=dtstore out=adult_scoreout;
        
run;


proc print data=adult_scoreout(obs=5);
run;

/******************************************************************************

 Astores can be saved as files for use in subsequent programs or entirely
 different environments.

 ******************************************************************************/

title2 'Saving the astore into a file';
proc astore;
    download rstore=dtstore store="/tmp/dtstore.sasast";
run;


/******************************************************************************
   Compute Partial Dependence for the variable AGE using PROC PARTIALDEPEND.
*******************************************************************************/
proc PartialDepend data = adult_train replicateType = MIDPOINTS seed = 12345;
    input age fnlwgt education_num capital_gain
          capital_loss hours_per_week / level=interval;
    input workclass education marital_status occupation
          relationship race sex native_country / level=nominal;
    predictedTarget P_target_50K;
   analysisVariable age;
   astoreModel rstore = dtstore;
run;