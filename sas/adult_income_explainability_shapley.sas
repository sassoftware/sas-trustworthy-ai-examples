/******************************************************************************
   EXAMPLE: shapley_adult.sas

   DATA: adult_sample (explained observations)
   
         adult_scored (reference background data set)

   DESCRIPTION: The Adult data set contains demographic and employment
                information such as age, education, occupation, and hours
                worked per week. The target variable indicates whether an
                individual earns more than $50K per year.

   PURPOSE: In this example, we use PROC SHAPLEY to compute SHAP (SHapley
            Additive exPlanations) values for each predictor variable. SHAP
            values quantify the individual contribution of each input feature
            to the model's predicted probability of earning more than $50K,
            providing a consistent and locally accurate measure of feature
            importance. The KernelSHAP method is used to approximate SHAP
            values efficiently, with adult_scored serving as the background
            reference distribution.
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
data adult_sample;
    set adult_scored (obs=1);
    obs_id = _n_;
run;
proc shapley
   data=adult_sample
   referenceData=adult_scored;
    input age fnlwgt education_num capital_gain
          capital_loss hours_per_week / level=interval;
    input workclass education marital_status occupation
          relationship race sex native_country / level=nominal;
    
   predictedTarget P_target_50K;
   method KERNELSHAP(seed=1234 useRawData);
run;
