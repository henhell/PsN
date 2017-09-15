$PROBLEM    MOXONIDINE PK,FINAL ESTIMATES, simulated data
$INPUT      ID VISI XAT2=DROP DGRP DOSE FLAG=DROP ONO=DROP
            XIME=DROP DVO=DROP NEUY SCR AGE SEX NYH=DROP WT DROP ACE
            DIG DIU NUMB=DROP TAD TIME VIDD=DROP CRCL AMT SS II DROP
            CMT=DROP CONO=DROP DV EVID=DROP OVID=DROP
$DATA       mox_simulated.csv IGNORE=@
$SUBROUTINE ADVAN2 TRANS1
$OMEGA  BLOCK(2)
0.0750
0.0467  0.0564  ; IIV (CL-V)
$OMEGA  BLOCK(1)
2.82  ;     IIV KA
$OMEGA  BLOCK(1)
0.0147  ;     IOV CL
$OMEGA  BLOCK(1) SAME
$OMEGA  BLOCK(1) 0.506 ;     IOV KA
$OMEGA  BLOCK(1) SAME

$PK
;-----------OCCASIONS----------
   VIS3               = 0
   IF(VISI.EQ.3) VIS3 = 1
   VIS8               = 0
   IF(VISI.EQ.8) VIS8 = 1

;----------IOV--------------------

   KPCL  = VIS3*ETA(4)+VIS8*ETA(5)
   KPKA  = VIS3*ETA(6)+VIS8*ETA(7)

;---------- PK model ------------------

   TVCL  = THETA(1)
   TVV   = THETA(2)

   CL    = TVCL*EXP(ETA(1)+KPCL)
   V     = TVV*EXP(ETA(2))
   KA    = THETA(3)*EXP(ETA(3)+KPKA)
   ALAG1 = THETA(4)
   K     = CL/V
   S2    = V

$ERROR

     IPRED = LOG(.025)
     WA     = 1
     W      = WA
     IF(F.GT.0) IPRED = LOG(F)
     IRES  = IPRED-DV
     IWRES = IRES/W
     Y     = IPRED+ERR(1)*W

$THETA  (0,26.1) ; TVCL
$THETA  (0,100) ; TVV
$THETA  (0,4.5) ; TVKA
$THETA  (0,0.2149) ; LAG
$SIGMA  0.109
$ETAS FILE=mox1.phi
$ESTIMATION METHOD=1 MAXEVAL=9999

