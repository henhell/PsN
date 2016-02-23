$PROBLEM    MOXONIDINE PK,,ALL DATA
;; No covariates 
;; IOV on CL, KA

;;
$INPUT      ID VISI XAT2=DROP DGRP=DROP DOSE=DROP FLAG=DROP ONO=DROP
            XIME=DROP DVO=DROP NEUY=DROP SCR AGE SEX NYHA WT DROP ACE
            DIG DIU NUMB=DROP TAD TIME VIDD=DROP CLCR AMT SS II DROP
            CMT=DROP CONO=DROP DV EVID=DROP OVID=DROP DROP SHR2=DROP

$DATA       mx19_1.csv IGNORE=@ IGN(VISI>3)
$SUBROUTINE ADVAN2 TRANS1
$OMEGA  BLOCK(2)
 0.0819
 0.0413  0.0564  ; IIV (CL-V)
$OMEGA  BLOCK(1)
 2.82  ;     IIV KA

$PK

   TVCL  = THETA(1)
   TVV   = THETA(2)

   CL    = TVCL*EXP(ETA(1))
   V     = TVV*EXP(ETA(2))
   KA    = THETA(3)*EXP(ETA(3))
   ALAG1 = THETA(4)
   K     = CL/V
   S2    = V

$ERROR

     IPRED = LOG(.025)
     WA     = THETA(5)
     W      = WA
     IF(F.GT.0) IPRED = LOG(F)
     IRES  = IPRED-DV
     IWRES = IRES/W
     Y     = IPRED+ERR(1)*W

$THETA  (0,26.7) ; TVCL
$THETA  (0,110) ; TVV
$THETA  (0,4.5) ; TVKA
$THETA  (0,0.2149) ; LAG
$THETA  (0,0.331) ; RES ERR
$SIGMA  1  FIX
$ESTIMATION METHOD=1 MAXEVALS=9999
;$COV
$TABLE ID TIME IPRED IWRES CWRES NOPRINT ONEHEADER FILE=sdtab1
$TABLE ID CL V ETA(1) ETA(2) NOPRINT NOAPPEND ONEHEADER FILE=patab1
$TABLE ID AGE SEX ACE DIG DIU NYHA SCR CLCR WT NOPRINT NOAPPEND ONEHEADER FILE=cotab1


