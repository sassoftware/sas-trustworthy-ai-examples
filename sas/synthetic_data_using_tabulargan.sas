/******************************************************************************
   EXAMPLE: synthetic_data_using_tabulargan.sas

   DATA: sampsio.hmeq (first 600 observations)

   DESCRIPTION: The HMEQ data set contains characteristics of home equity
                loan applicants, including credit history, loan amount,
                and employment information.

   PURPOSE: In this example, we use PROC TABULARGAN to train a Generative
            Adversarial Network (GAN) that synthesizes tabular data based
            on the HMEQ sample. The synthetic output can be used for data
            augmentation or privacy-preserving data sharing.
******************************************************************************/   
    
    
/******************************************************************************
   Load a subset of the HMEQ data.

   Read the first 600 observations from the SAMPSIO.HMEQ library data set
   into a local work data set for use in subsequent steps.
******************************************************************************/
    
 data hmeq;
    set sampsio.hmeq (obs=600);
 run;

/* Train the GAN model using PROC TABULARGAN.*/ 
 proc tabulargan         data=hmeq seed=123 numSamples=5 ;
      input               value clage/level=interval;/* Continuous inputs   */
      input               bad job/level=nominal; /* Categorical inputs  */
      gmm                 alpha=1 maxClusters=10 seed=42 VB(maxVbIter=30);/* GMM prior with VB  */
      aeoptimization      ADAM LearningRate=0.0001 numEpochs=3; /* Autoencoder phase   */
      ganoptimization     ADAM(beta1=0.55 beta2=0.95)  numEpochs=5; /* GAN training phase  */
      train               embeddingDim=64 miniBatchSize=300 useOrigLevelFreq;
      savestate           rstore=astore; /* Persist model state */
      output              out=out; /* Synthetic data out  */
 run;


 /******************************************************************************
   Print the synthetic output data.

   Display all observations in the OUT data set to verify that the GAN
   produced synthetic records with the expected variables and value ranges.
******************************************************************************/
 proc print   data = out;
 run;

 





