! . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
! .                                                                       .
! .                            S T A P 9 0                                .
! .                                                                       .
! .     AN IN-CORE SOLUTION STATIC ANALYSIS PROGRAM IN FORTRAN 90         .
! .     Adapted from STAP (KJ Bath, FORTRAN IV) for teaching purpose      .
! .                                                                       .
! .     Xiong Zhang, (2013)                                               .
! .     Computational Dynamics Group, School of Aerospace                 .
! .     Tsinghua Univerity                                                .
! .                                                                       .
! . . . . . . . . . . . . . .  . . .  . . . . . . . . . . . . . . . . . . .

SUBROUTINE QuadrElem
! . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
! .                                                                   .
! .   To set up storage and call the truss element subroutine         .
! .                                                                   .
! . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

  USE GLOBALS
  USE MEMALLOCATE

  IMPLICIT NONE
  INTEGER :: NUME, NUMMAT, MM, N101, N102, N103, N104, N105, N106,N107

  NUME = NPAR(2)
  NUMMAT = NPAR(3)

! Allocate storage for element group data
  IF (IND == 1) THEN
      MM = 3*NUMMAT*ITWO +9*NUME + 8*NUME*ITWO
      CALL MEMALLOC(11,"ELEGP",MM,1)
  
  END IF

  NFIRST=NP(11)   ! Pointer to the first entry in the element group data array
                  ! in the unit of single precision (corresponding to A)

! Calculate the pointer to the arrays in the element group data
! N101: E(NUMMAT)
! N102: PR(NUMMAT)
! N103: LM(8,NUME)
! N104: XYZ(8,NUME)
! N105: MTAP(NUME)
  N101=NFIRST
  N102=N101+NUMMAT*ITWO
  N103=N102+NUMMAT*ITWO
  N104=N103+8*NUME
  N105=N104+8*NUME*ITWO
  N106=N105+NUME
  N107=N106+NUMMAT*ITWO
  NLAST=N107

  MIDEST=NLAST - NFIRST

  CALL QUAD_1 (IA(NP(1)),DA(NP(2)),DA(NP(3)),DA(NP(4)),DA(NP(4)),IA(NP(5)),   &
       A(N101),A(N102),A(N106),A(N103),A(N104),A(N105))

  IF(IND == 3)THEN
      CALL SPR_4Q(IA(NP(10)),DA(NP(9)),A(N104))
  ENDIF

  RETURN

END SUBROUTINE QuadrElem


SUBROUTINE QUAD_1 (ID,X,Y,Z,U,MHT,E,PR,THICK,LM,XYZ,MATP)
! . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
! .                                                                   .
! .   TRUSS element subroutine                                        .
! .                                                                   .
! . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

  USE GLOBALS
  USE MEMALLOCATE

  IMPLICIT NONE
  INTEGER :: ID(3,NUMNP),LM(8,NPAR(2)),MATP(NPAR(2)),MHT(NEQ)
  REAL(8) :: X(NUMNP),Y(NUMNP),Z(NUMNP),E(NPAR(3)),PR(NPAR(3)),  &
            THICK(NPAR(3)), XYZ(8,NPAR(2)),U(NEQ),UE(8)                           ! 在材料属性中添加了密度参数
  REAL(8) :: S(8,8),M(8,8),D(4,4),Stemp(8,8),F,G,H,r
!  REAL(8) :: 
  
  INTEGER :: NPAR1, NUME, NUMMAT, ND,P(4), L, N, I,J,K
  INTEGER :: MTYPE, IPRINT, ITYPE                                        
  REAL(8) ::  XM, XX, YY, STR(4), PF(4),CIGMA(3,5)
  REAL(8) :: GP(2), WGT(2),B(4,8),detJ,NL(2,8)
  REAL(8),parameter:: pi=3.141592654
  !GP =[-0.9061798459, -0.5384693101 ,0.0 ,0.5384693101,0.9061798459]                          !五点GAUSS积分
  !WGT=[ 0.2369268851,  0.4786286705 ,0.5688888889, 0.4786286705,0.2369268851]
  GP=[-0.5773502692 , 0.5773502692]
  WGT=[ 1          ,          1]
  
  NPAR1  = NPAR(1)
  NUME   = NPAR(2)
  NUMMAT = NPAR(3) 
  ITYPE  = NPAR(4)
  ND=8

! Read and generate element information
  IF (IND .EQ. 1) THEN

     WRITE (IOUT,"(' E L E M E N T   D E F I N I T I O N',//,  &
                   ' ELEMENT TYPE ',13(' .'),'( NPAR(1) ) . . =',I5,/,   &
                   '     EQ.1, QUADR ELEMENTS',/,      &
                   '     EQ.2, ELEMENTS CURRENTLY',/,  &
                   '     EQ.3, NOT AVAILABLE',//,      &
                   ' SOLVE MODE ',13(' .'),'( NPAR(4) ) . . =',I5,/,   &
                   '     EQ.0, AXIS SYMMETRY',/,      &
                   '     EQ.1, PLAIN STRAIN',/,  &
                   '     EQ.2, PLAIN STRSS',//,   &    
                   ' NUMBER OF ELEMENTS.',10(' .'),'( NPAR(2) ) . . =',I5,/)") NPAR1,ITYPE,NUME

     IF (NUMMAT.EQ.0) NUMMAT=1

     WRITE (IOUT,"(' M A T E R I A L   D E F I N I T I O N',//,  &
                   ' NUMBER OF DIFFERENT SETS OF MATERIAL',/,  &
                   ' AND PROPETIES ',         &
                   4 (' .'),'( NPAR(3) ) . . =',I5,/)") NUMMAT

     WRITE (IOUT,"('  SET       YOUNG''S      POISSION     THICKNESS',/,  &
                   ' NUMBER     MODULUS',10X,'   RATIO         VALUE',/,  &
                   15 X,'E',14X,'A',14X,'ROU')")

     DO I=1,NUMMAT
        READ (IIN,'(I5,3F10.0)') N,E(N),PR(N),THICK(N)                      ! Read material information  
        WRITE (IOUT,"(I5,4X,E12.5,2X,E12.5,2X,E12.5)") N,E(N),PR(N),THICK(N)
     END DO
     
     CALL MEMALLOC(10,"NPELM",NUME*NIE,1)                                   !分配内存10 以储存节点的单元号
      
     WRITE (IOUT,"(//,' E L E M E N T   I N F O R M A T I O N',//,  &
                      ' ELEMENT     NODE     NODE      NODE      NODE      MATERIAL',/,   &
                      ' NUMBER-N      P1       P2       P3       P4       SET NUMBER')")
     
     
     K=NP(10)
     N=0
     DO WHILE (N .NE. NUME)
        READ (IIN,'(7I5)') N,P(1),P(2),P(3),P(4),MTYPE  ! Read in element information

!       Save element information
        XYZ(1,N)=X(P(1))     ! Coordinates of the element's first node
        XYZ(2,N)=Y(P(1))
        XYZ(3,N)=X(P(2))     ! Coordinates of the element's second node
        XYZ(4,N)=Y(P(2))      
        XYZ(5,N)=X(P(3))     ! Coordinates of the element's third node
        XYZ(6,N)=Y(P(3))
        XYZ(7,N)=X(P(4))     ! Coordinates of the element's fourth node
        XYZ(8,N)=Y(P(4))
        MATP(N)=MTYPE        ! Material type
        
        DO L=1,8
           LM(L,N)=0
        END DO
      
       
        DO L=1,NIE
           IA(K+NIE*(N-1)+L-1)=P(L)                      !标记节点周围的单元数的数 1表示边界结点，4表示内部节点        
        ENDDO
        
        DO L=1,2
           LM(L,N)=ID(L,P(1))     ! Connectivity matrix
           LM(L+2,N)=ID(L,P(2)) 
           LM(L+4,N)=ID(L,P(3)) 
           LM(L+6,N)=ID(L,P(4))
        END DO

!       Update column heights and bandwidth
        CALL COLHT (MHT,ND,LM(1,N))   

        WRITE (IOUT,"(I5,6X,I5,4X,I5,4X,I5,4X,I5,7X,I5)") N,P(1),P(2),P(3),P(4),MTYPE
         WRITE(10,"(I5,4X,I5,4X,I5,4X,I5)")P(1),P(2),P(3),P(4)
     END DO
     
!    print *, IA(NP(10))

     RETURN

! Assemble stucture stiffness matrix
  ELSE IF (IND .EQ. 2) THEN

!对平面应力问题而言

     DO N=1,NUME
        MTYPE=MATP(N)
        F=E(MTYPE)/(1.+PR(MTYPE))                                                      
        G=F*PR(MTYPE)/(1.-2.*PR(MTYPE))                                                 
        H=F + G 
        D(1,1)=H                                                          
        D(1,2)=G                                                          
        D(1,3)=0.                                                         
        D(2,1)=G                                                          
        D(2,2)=H                                                          
        D(2,3)=0.                                                         
        D(3,1)=0.                                                         
        D(3,2)=0.                                                         
        D(3,3)=F/2. 
        IF (ITYPE.EQ.0) THEN             !轴对称的情况
            D(1,4)=G                                                          
            D(2,4)=G                                                          
            D(3,4)=0.                                                         
            D(4,1)=G                                                          
            D(4,2)=G                                                          
            D(4,3)=0.                                                         
            D(4,4)=H
        ELSE IF(ITYPE.eq.1) THEN          !平面应变
            THICK(MTYPE)=1.
        ELSE IF(ITYPE.eq.2) THEN          !平面应力
            F=E(MTYPE)/(1-PR(MTYPE)**2)
            D(1,1)=F           
            D(1,2)=F*PR(MTYPE)                                                          
            D(1,3)=0.                                                         
            D(2,1)=F*PR(MTYPE)                                                             
            D(2,2)=F                                                          
            D(2,3)=0.                                                         
            D(3,1)=0.                                                         
            D(3,2)=0.                                                         
            D(3,3)=F*(1-PR(MTYPE))/2         
        ENDIF  
  
        ! print *,D  
        S = 0
   
        if(ITYPE.eq.1.or.ITYPE.eq.2)then
            do i=1,2                                                      
                do j=1,2
                    CAll Bmat(gp(i),gp(j),XYZ(1,N),B,detJ)
                    CALL Nmat(gp(i),gp(j),NL)
                    S=S+WGT(i)*WGT(j)*matmul(matmul(transpose(B),D),B)*detJ*THICK(MTYPE)
                    
!                   The mass matrix (NOTE: NOT HAVE THE DENSITY)
                    M=M+WGT(i)*WGT(j)*matmul(transpose(NL),NL)*detJ*THICK(MTYPE)
                end do
            end do
        else if(ITYPE.eq.0)then                                                  !轴对称问题
            do i=1,2                                                      
                do j=1,2
                    CALL Nmat(gp(i),gp(j),NL)
                    CAll Bmat(gp(i),gp(j),XYZ(1,N),B,detJ)
                    r=2*pi*(NL(1,1)*XYZ(1,N)+NL(1,3)*XYZ(3,N)+NL(1,5)*XYZ(5,N)+NL(1,7)*XYZ(7,N))
                    S=S+r*WGT(i)*WGT(j)*matmul(matmul(transpose(B),D),B)*detJ
                    
!                   The mass matrix (NOTE: NOT HAVE THE DENSITY)
                    M=M+r*WGT(i)*WGT(j)*matmul(transpose(NL),NL)*detJ
                end do
            end do
        end if       

        CALL ADDBAN (DA(NP(3)),IA(NP(2)),S,LM(1,N),ND)
        CALL ADDBAN (DA(NP(13)),IA(NP(2)),M,LM(1,N),ND)
     END DO

     RETURN

! Stress calculations
  ELSE IF (IND .EQ. 3) THEN

     CALL MEMALLOC(9,"NPFORCE",(NUME+NUMNP)*NDF,ITWO)                                   !分配内存9 以储存节点及用于重构的单元超收敛点的位移

     IPRINT=0
     DO N=1,NUME
        IPRINT=IPRINT + 1
        IF (IPRINT.GT.50) IPRINT=1
        IF (IPRINT.EQ.1) WRITE (IOUT,"(//,' S T R E S S  C A L C U L A T I O N S  F O R  ',  &
                                            'E L E M E N T  G R O U P',I4,//,   &
                                            '  ELEMENT',5X,'GAUSS POINT',5X,'StressXX',5X,'StressYY',5X,'StressXY',/,&
                                            '  NUMBER')") NG
        MTYPE=MATP(N)
        DO L=1,4    
            I=LM(2*L-1,N)
            if (I.GT.0)then
                UE(2*L-1)=U(I)
            else
                UE(2*L-1)=0
            endif       
            J=LM(2*L,N)
            IF (J.GT.0)then
                UE(2*L)=U(J)
            else
                UE(2*L)=0
            endif
        END DO
        
        do i=1,2                                                      
            do j=1,2  
                CAll Bmat(gp(i),gp(j),XYZ(1,N),B,detJ)
                STR = matmul(B,UE)
                PF  = matmul(D,STR)
                Do k=1,3
                    CIGMA(k,2*i+j-2)=PF(k)
                end do
                WRITE (IOUT,"(I5,5X,f6.3,2X,f6.3,4X,E13.6,4X,E13.6,4X,E13.6)")N,gp(i),gp(j),PF(1),PF(2),PF(3)
            end do
        end do
 
        CAll Bmat(0,0,XYZ(1,N),B,detJ)
        STR = matmul(B,UE)
        PF   = matmul(D,STR)
        do k=1,3
            CIGMA(k,5)=PF(k)
        end do
  
        CALL ADDSPR (N,IA(NP(10)+NIE*(N-1)),DA(NP(9)),CIGMA)             ! 直接操作内存！！！  危险。。  NP(10)+NIE*(N-1) 第N个单元的位置
     END DO

  ELSE 
     STOP "*** ERROR *** Invalid IND value."
  END IF

END SUBROUTINE Quad_1


subroutine Nmat(eta,psi,N)
    implicit none
    real(8) ::psi,eta,N(2,8)
    N(1,1)=0.25*(1-psi)*(1-eta)
    N(2,2)=0.25*(1-psi)*(1-eta)
    N(1,3)=0.25*(1+psi)*(1-eta)
    N(2,4)=0.25*(1+psi)*(1-eta)
    N(1,5)=0.25*(1+psi)*(1+eta)
    N(2,6)=0.25*(1+psi)*(1+eta)
    N(1,7)=0.25*(1-psi)*(1+eta)
    N(2,8)=0.25*(1-psi)*(1+eta)
end subroutine Nmat
    
subroutine Bmat(eta,psi,XY,B,detJ)
    implicit none
    real(8) :: eta,psi,XY(8),B(4,8),detJ,GN(2,4),J(2,2),JINV(2,2),DUM,N(4)
    integer::K2,K,I

    GN(1,1)=0.25*(eta-1.0)
    GN(1,2)=-GN(1,1)
    GN(1,3)=0.25*(1.0+eta)
    GN(1,4)=-GN(1,3)
    GN(2,1)=0.25*(psi-1)
    GN(2,2)=-0.25*(psi+1)
    GN(2,3)=-GN(2,2)
    GN(2,4)=-GN(2,1)
    N(1)=0.25*(1-psi)*(1-eta)
    N(2)=0.25*(1+psi)*(1-eta)
    N(3)=0.25*(1+psi)*(1+eta)
    N(4)=0.25*(1-psi)*(1+eta)

    J(1,1)=GN(1,1)*xy(1)+GN(1,2)*xy(3)+GN(1,3)*xy(5)+GN(1,4)*xy(7)
    J(1,2)=GN(1,1)*xy(2)+GN(1,2)*xy(4)+GN(1,3)*xy(6)+GN(1,4)*xy(8)
    J(2,1)=GN(2,1)*xy(1)+GN(2,2)*xy(3)+GN(2,3)*xy(5)+GN(2,4)*xy(7)
    J(2,2)=GN(2,1)*xy(2)+GN(2,2)*xy(4)+GN(2,3)*xy(6)+GN(2,4)*xy(8)

    detJ=J(1,1)*J(2,2)-J(2,1)*J(1,2)
    DUM=1./detJ
    JINV(1,1)=J(2,2)*DUM
    JINV(1,2)=-J(1,2)*DUM
    JINV(2,1)=-J(2,1)*DUM
    JINV(2,2)=J(1,1)*DUM

    K2=0
    do K=1,4
        K2=K2+2
        B(1,K2-1) = 0.                                                    
        B(1,K2  ) = 0.                                                    
        B(2,K2-1) = 0.                                                    
        B(2,K2  ) = 0. 
        do I=1,2
            B(1,K2-1)=B(1,K2-1)+JINV(1,I)*GN(I,K)
            B(2,K2)  =B(2,K2)  +JINV(2,I)*GN(I,K)
        end do
        B(3,K2)    =B(1,K2-1)
        B(3,K2-1)  =B(2,K2)
        B(4,K2)    =0
        B(4,K2-1)  =N(K)/(N(1)*xy(1)+N(2)*xy(3)+N(3)*xy(5)+N(4)*xy(7))
    end do

end subroutine Bmat