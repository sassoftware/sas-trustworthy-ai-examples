/******************************************************************************
   EXAMPLE: md5_hash.sas

   DATA: N/A (no input data set; demonstrates MD5 hashing on literal strings)

   DESCRIPTION: This example demonstrates the use of the MD5 cryptographic
                hash function within the DS2 programming language. Two string
                literals are hashed and their fixed-length hexadecimal digests
                are written to the SAS log.

   PURPOSE: In this example, we use PROC DS2 to compute MD5 hash values for
            two string literals using the built-in MD5() function. The result
            is a 32-byte binary digest formatted as a hexadecimal string.
            This technique can be applied to anonymize or fingerprint string
            fields in any data set for data masking or integrity verification.
******************************************************************************/

proc ds2;
data _null_;
   method init();
      /* Declare two 32-byte binary variables to store the MD5 hash digests,
         displayed as hexadecimal strings via the $HEX32. format            */
      dcl binary(32) y z having format $hex32.;

      /* Compute the MD5 hash of the literal string 'abc'                   */
      y = md5('abc');

      /* Compute the MD5 hash of the literal string 'access method'         */
      z = md5('access method');

      /* Print both hash digests to the SAS log for verification            */
      put y= ;
      put z= ;
   end;
enddata;
run;
quit;