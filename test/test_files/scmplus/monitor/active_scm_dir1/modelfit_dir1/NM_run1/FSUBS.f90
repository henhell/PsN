      MODULE NMPRD4P
      USE SIZES, ONLY: DPSIZE
      USE NMPRD4,ONLY: VRBL
      IMPLICIT NONE
      SAVE
      REAL(KIND=DPSIZE), DIMENSION (:),POINTER ::COM
      REAL(KIND=DPSIZE), POINTER ::CLAPGR,CLCOV,VWGT,VCOV,TVCL,CL,TVV
      REAL(KIND=DPSIZE), POINTER ::V,S1,W,Y,IPRED,IRES,IWRES,A00032
      REAL(KIND=DPSIZE), POINTER ::A00034,A00036,A00038,A00039,A00040
      REAL(KIND=DPSIZE), POINTER ::D00001,D00002,D00003,D00004,D00005
      REAL(KIND=DPSIZE), POINTER ::D00037,D00040,D00039,D00036,D00038
      REAL(KIND=DPSIZE), POINTER ::C00031,D00046,D00048,D00049,D00047
      REAL(KIND=DPSIZE), POINTER ::D00050,D00052,D00055,D00054,D00051
      REAL(KIND=DPSIZE), POINTER ::D00053
      CONTAINS
      SUBROUTINE ASSOCNMPRD4
      COM=>VRBL
      CLAPGR=>COM(00001);CLCOV=>COM(00002);VWGT=>COM(00003)
      VCOV=>COM(00004);TVCL=>COM(00005);CL=>COM(00006);TVV=>COM(00007)
      V=>COM(00008);S1=>COM(00009);W=>COM(00010);Y=>COM(00011)
      IPRED=>COM(00012);IRES=>COM(00013);IWRES=>COM(00014)
      A00032=>COM(00015);A00034=>COM(00016);A00036=>COM(00017)
      A00038=>COM(00018);A00039=>COM(00019);A00040=>COM(00020)
      D00001=>COM(00021);D00002=>COM(00022);D00003=>COM(00023)
      D00004=>COM(00024);D00005=>COM(00025);D00037=>COM(00026)
      D00040=>COM(00027);D00039=>COM(00028);D00036=>COM(00029)
      D00038=>COM(00030);C00031=>COM(00031);D00046=>COM(00032)
      D00048=>COM(00033);D00049=>COM(00034);D00047=>COM(00035)
      D00050=>COM(00036);D00052=>COM(00037);D00055=>COM(00038)
      D00054=>COM(00039);D00051=>COM(00040);D00053=>COM(00041)
      END SUBROUTINE ASSOCNMPRD4
      END MODULE NMPRD4P
      SUBROUTINE PK(ICALL,IDEF,THETA,IREV,EVTREC,NVNT,INDXS,IRGG,GG,NETAS)      
      USE NMPRD4P
      USE SIZES,     ONLY: DPSIZE,ISIZE
      USE PRDIMS,    ONLY: GPRD,HPRD,GERD,HERD,GPKD
      USE NMPRD_REAL,ONLY: ETA,EPS                                            
      USE NMPRD_INT, ONLY: MSEC=>ISECDER,MFIRST=>IFRSTDER,COMACT,COMSAV,IFIRSTEM
      USE NMPRD_INT, ONLY: MDVRES,ETASXI,NPDE_MODE
      USE NMPRD_REAL, ONLY: DV_LOQ
      USE NMPRD_INT, ONLY: IQUIT
      USE PROCM_INT, ONLY: NEWIND=>PNEWIF                                       
      USE NMBAYES_REAL, ONLY: LDF                                             
      IMPLICIT REAL(KIND=DPSIZE) (A-Z)                                          
      REAL(KIND=DPSIZE) :: EVTREC                                               
      SAVE
      INTEGER(KIND=ISIZE) :: FIRSTEM
      INTEGER(KIND=ISIZE) :: ICALL,IDEF,IREV,NVNT,INDXS,IRGG,NETAS              
      DIMENSION :: IDEF(7,*),THETA(*),EVTREC(IREV,*),INDXS(*),GG(IRGG,GPKD+1,*) 
      FIRSTEM=IFIRSTEM
      IF (ICALL <= 1) THEN                                                      
      CALL ASSOCNMPRD4
      IDEF(  1,001)= -9
      IDEF(  1,002)= -1
      IDEF(  1,003)=  0
      IDEF(  1,004)=  0
      IDEF(  2,003)=  0
      IDEF(  2,004)=  0
      IDEF(  3,001)=  3
      CALL GETETA(ETA)                                                          
      IF (IQUIT == 1) RETURN                                                    
      RETURN                                                                    
      ENDIF                                                                     
      IF (NEWIND /= 2) THEN
      IF (ICALL == 4) THEN
      CALL SIMETA(ETA)
      ELSE
      CALL GETETA(ETA)
      ENDIF
      IF (IQUIT == 1) RETURN
      ENDIF
 !  level            0
      WGT=EVTREC(NVNT,004)
      APGR=EVTREC(NVNT,005)
      IF(APGR == 8.D0)THEN 
      CLAPGR=1.D0 
      ENDIF 
      IF(APGR == 7.D0)THEN 
      B00006=1.D0+THETA(005) 
      CLAPGR=B00006 
      ENDIF 
      IF(APGR == 9.D0)THEN 
      B00010=1.D0+THETA(006) 
      CLAPGR=B00010 
      ENDIF 
      IF(APGR == 6.D0)THEN 
      B00014=1.D0+THETA(007) 
      CLAPGR=B00014 
      ENDIF 
      IF(APGR == 5.D0)THEN 
      B00018=1.D0+THETA(008) 
      CLAPGR=B00018 
      ENDIF 
      IF(APGR == 1.D0)THEN 
      B00022=1.D0+THETA(009) 
      CLAPGR=B00022 
      ENDIF 
      IF(APGR == 4.D0)THEN 
      B00026=1.D0+THETA(010) 
      CLAPGR=B00026 
      ENDIF 
      IF(APGR == 3.D0)THEN 
      B00030=1.D0+THETA(011) 
      CLAPGR=B00030 
      ENDIF 
      IF(APGR == 2.D0)THEN 
      B00034=1.D0+THETA(012) 
      CLAPGR=B00034 
      ENDIF 
      IF(APGR == 10.D0)THEN 
      B00038=1.D0+THETA(013) 
      CLAPGR=B00038 
      ENDIF 
      CLCOV=CLAPGR 
      B00040=WGT-1.3D0 
      B00041=1.D0+THETA(004)*B00040 
      VWGT=B00041 
      VCOV=VWGT 
      TVCL=THETA(001) 
      TVCL=CLCOV*TVCL 
      B00043=DEXP(ETA(001)) 
      CL=TVCL*B00043 
      B00044=TVCL 
      TVV=THETA(002) 
      TVV=VCOV*TVV 
      B00046=DEXP(ETA(002)) 
      V=TVV*B00046 
      B00047=TVV 
      S1=V 
      IF (FIRSTEM == 1) THEN
!                      A00032 = DERIVATIVE OF CL W.R.T. ETA(001)
      A00032=B00044*B00043 
!                      A00036 = DERIVATIVE OF V W.R.T. ETA(002)
      A00036=B00047*B00046 
!                      A00039 = DERIVATIVE OF S1 W.R.T. ETA(002)
      A00039=A00036 
      GG(001,1,1)=CL
      GG(001,002,1)=A00032
      GG(002,1,1)=V
      GG(002,003,1)=A00036
      GG(003,1,1)=S1
      GG(003,003,1)=A00039
      ELSE
      GG(001,1,1)=CL
      GG(002,1,1)=V
      GG(003,1,1)=S1
      ENDIF
      IF (MSEC == 1) THEN
!                      A00034 = DERIVATIVE OF A00032 W.R.T. ETA(001)
      A00034=B00044*B00043 
!                      A00038 = DERIVATIVE OF A00036 W.R.T. ETA(002)
      A00038=B00047*B00046 
!                      A00040 = DERIVATIVE OF A00039 W.R.T. ETA(002)
      A00040=A00038 
      GG(001,002,002)=A00034
      GG(002,003,003)=A00038
      GG(003,003,003)=A00040
      ENDIF
      RETURN
      END
      SUBROUTINE ERROR (ICALL,IDEF,THETA,IREV,EVTREC,NVNT,INDXS,F,G,HH)       
      USE NMPRD4P
      USE SIZES,     ONLY: DPSIZE,ISIZE
      USE PRDIMS,    ONLY: GPRD,HPRD,GERD,HERD,GPKD
      USE NMPRD_REAL,ONLY: ETA,EPS                                            
      USE NMPRD_INT, ONLY: MSEC=>ISECDER,MFIRST=>IFRSTDER,IQUIT,IFIRSTEM
      USE NMPRD_INT, ONLY: MDVRES,ETASXI,NPDE_MODE
      USE NMPRD_REAL, ONLY: DV_LOQ
      USE NMPRD_INT, ONLY: NEWL2
      USE PROCM_INT, ONLY: NEWIND=>PNEWIF                                       
      IMPLICIT REAL(KIND=DPSIZE) (A-Z)                                        
      REAL(KIND=DPSIZE) :: EVTREC                                             
      SAVE
      INTEGER(KIND=ISIZE) :: ICALL,IDEF,IREV,NVNT,INDXS                       
      DIMENSION :: IDEF(*),THETA(*),EVTREC(IREV,*),INDXS(*)                   
      REAL(KIND=DPSIZE) :: G(GERD,*),HH(HERD,*)                               
      INTEGER(KIND=ISIZE) :: FIRSTEM
      FIRSTEM=IFIRSTEM
      IF (ICALL <= 1) THEN                                                    
      CALL ASSOCNMPRD4
      IDEF(2)=-1
      IDEF(3)=000
      RETURN
      ENDIF
      IF (ICALL == 4) THEN
      IF (NEWL2 == 1) THEN
      CALL SIMEPS(EPS)
      IF (IQUIT == 1) RETURN
      ENDIF
      ENDIF
      D00001=G(001,1)
      D00002=G(002,1)
 !  level            0
      DV=EVTREC(NVNT,006)
      W=THETA(003) 
      Y=F+W*EPS(001) 
!                      C00031 = DERIVATIVE OF Y W.R.T. EPS(001)
      C00031=W 
      IPRED=F 
      IRES=DV-IPRED 
      IWRES=IRES/W 
      IF (FIRSTEM == 1) THEN !1
!                      D00036 = DERIVATIVE OF Y W.R.T. ETA(002)
      D00036=D00002 
!                      D00037 = DERIVATIVE OF Y W.R.T. ETA(001)
      D00037=D00001 
!                      D00046 = DERIVATIVE OF IRES W.R.T. ETA(001)
      D00046=-D00001 
!                      D00047 = DERIVATIVE OF IRES W.R.T. ETA(002)
      D00047=-D00002 
      B00001=1.D0/W 
!                      D00051 = DERIVATIVE OF IWRES W.R.T. ETA(002)
      D00051=B00001*D00047 
!                      D00052 = DERIVATIVE OF IWRES W.R.T. ETA(001)
      D00052=B00001*D00046 
      G(001,1)=D00037
      G(002,1)=D00036
      ENDIF !1
      HH(001,1)=C00031
      IF (MSEC == 1) THEN
      D00003=G(001,002)
      D00004=G(002,002)
      D00005=G(002,003)
!                      D00038 = DERIVATIVE OF D00036 W.R.T. ETA(002)
      D00038=D00005 
!                      D00039 = DERIVATIVE OF D00037 W.R.T. ETA(002)
      D00039=D00004 
!                      D00040 = DERIVATIVE OF D00037 W.R.T. ETA(001)
      D00040=D00003 
!                      D00048 = DERIVATIVE OF D00046 W.R.T. ETA(001)
      D00048=-D00003 
!                      D00049 = DERIVATIVE OF D00046 W.R.T. ETA(002)
      D00049=-D00004 
!                      D00050 = DERIVATIVE OF D00047 W.R.T. ETA(002)
      D00050=-D00005 
!                      D00053 = DERIVATIVE OF D00051 W.R.T. ETA(002)
      D00053=B00001*D00050 
!                      D00054 = DERIVATIVE OF D00052 W.R.T. ETA(002)
      D00054=B00001*D00049 
!                      D00055 = DERIVATIVE OF D00052 W.R.T. ETA(001)
      D00055=B00001*D00048 
      G(001,002)=D00040
      G(002,002)=D00039
      G(002,003)=D00038
      ENDIF
      F=Y
      RETURN
      END
      SUBROUTINE FSIZESR(NAME_FSIZES,F_SIZES)
      USE SIZES, ONLY: ISIZE
      INTEGER(KIND=ISIZE), DIMENSION(*) :: F_SIZES
      CHARACTER(LEN=*),    DIMENSION(*) :: NAME_FSIZES
      NAME_FSIZES(01)='LTH'; F_SIZES(01)=13
      NAME_FSIZES(02)='LVR'; F_SIZES(02)=3
      NAME_FSIZES(03)='LVR2'; F_SIZES(03)=0
      NAME_FSIZES(04)='LPAR'; F_SIZES(04)=17
      NAME_FSIZES(05)='LPAR3'; F_SIZES(05)=0
      NAME_FSIZES(06)='NO'; F_SIZES(06)=0
      NAME_FSIZES(07)='MMX'; F_SIZES(07)=1
      NAME_FSIZES(08)='LNP4'; F_SIZES(08)=0
      NAME_FSIZES(09)='LSUPP'; F_SIZES(09)=1
      NAME_FSIZES(10)='LIM7'; F_SIZES(10)=0
      NAME_FSIZES(11)='LWS3'; F_SIZES(11)=0
      NAME_FSIZES(12)='MAXIDS'; F_SIZES(12)=59
      NAME_FSIZES(13)='LIM1'; F_SIZES(13)=0
      NAME_FSIZES(14)='LIM2'; F_SIZES(14)=0
      NAME_FSIZES(15)='LIM3'; F_SIZES(15)=0
      NAME_FSIZES(16)='LIM4'; F_SIZES(16)=0
      NAME_FSIZES(17)='LIM5'; F_SIZES(17)=0
      NAME_FSIZES(18)='LIM6'; F_SIZES(18)=0
      NAME_FSIZES(19)='LIM8'; F_SIZES(19)=0
      NAME_FSIZES(20)='LIM11'; F_SIZES(20)=0
      NAME_FSIZES(21)='LIM13'; F_SIZES(21)=0
      NAME_FSIZES(22)='LIM15'; F_SIZES(22)=0
      NAME_FSIZES(23)='LIM16'; F_SIZES(23)=0
      NAME_FSIZES(24)='MAXRECID'; F_SIZES(24)=200
      NAME_FSIZES(25)='PC'; F_SIZES(25)=30
      NAME_FSIZES(26)='PCT'; F_SIZES(26)=30
      NAME_FSIZES(27)='PIR'; F_SIZES(27)=700
      NAME_FSIZES(28)='PD'; F_SIZES(28)=50
      NAME_FSIZES(29)='PAL'; F_SIZES(29)=50
      NAME_FSIZES(30)='MAXFCN'; F_SIZES(30)=1000000
      NAME_FSIZES(31)='MAXIC'; F_SIZES(31)=90
      NAME_FSIZES(32)='PG'; F_SIZES(32)=80
      NAME_FSIZES(33)='NPOPMIXMAX'; F_SIZES(33)=0
      NAME_FSIZES(34)='MAXOMEG'; F_SIZES(34)=2
      NAME_FSIZES(35)='MAXPTHETA'; F_SIZES(35)=14
      NAME_FSIZES(36)='MAXITER'; F_SIZES(36)=20
      NAME_FSIZES(37)='ISAMPLEMAX'; F_SIZES(37)=0
      NAME_FSIZES(38)='DIMTMP'; F_SIZES(38)=0
      NAME_FSIZES(39)='DIMCNS'; F_SIZES(39)=0
      NAME_FSIZES(40)='DIMNEW'; F_SIZES(40)=0
      NAME_FSIZES(41)='PDT'; F_SIZES(41)=1
      NAME_FSIZES(42)='LADD_MAX'; F_SIZES(42)=0
      NAME_FSIZES(43)='MAXSIDL'; F_SIZES(43)=0
      NAME_FSIZES(44)='NTT'; F_SIZES(44)=13
      NAME_FSIZES(45)='NOMEG'; F_SIZES(45)=2
      NAME_FSIZES(46)='NSIGM'; F_SIZES(46)=1
      NAME_FSIZES(47)='PPDT'; F_SIZES(47)=1
      RETURN
      END SUBROUTINE FSIZESR
      SUBROUTINE MUMODEL2(THETA,MU_,ICALL,IDEF,NEWIND,&
      EVTREC,DATREC,IREV,NVNT,INDXS,F,G,H,IRGG,GG,NETAS)
      USE NMPRD4P
      USE SIZES,     ONLY: DPSIZE,ISIZE
      USE PRDIMS,    ONLY: GPRD,HPRD,GERD,HERD,GPKD
      USE NMPRD_REAL,ONLY: ETA,EPS
      USE NMPRD_INT, ONLY: MSEC=>ISECDER,MFIRST=>IFRSTDER,COMACT,COMSAV,IFIRSTEM
      USE NMPRD_INT, ONLY: MDVRES,ETASXI,NPDE_MODE
      USE NMPRD_REAL, ONLY: DV_LOQ
      USE NMPRD_INT, ONLY: IQUIT
      USE NMBAYES_REAL, ONLY: LDF
      IMPLICIT REAL(KIND=DPSIZE) (A-Z)
      REAL(KIND=DPSIZE)   :: MU_(*)
      INTEGER NEWIND
      REAL(KIND=DPSIZE) :: EVTREC
      SAVE
      INTEGER(KIND=ISIZE) :: FIRSTEM
      INTEGER(KIND=ISIZE) :: ICALL,IDEF,IREV,NVNT,INDXS,IRGG,NETAS
      DIMENSION :: IDEF(7,*),THETA(*),EVTREC(IREV,*),INDXS(*),GG(IRGG,GPKD+1,*)
      RETURN
      END