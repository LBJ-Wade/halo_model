MODULE special_functions

  USE constants

CONTAINS

  FUNCTION factorial(n)

    IMPLICIT NONE
    INTEGER :: factorial
    INTEGER, INTENT(IN) :: n 
    INTEGER*8 :: factorial8    
    INTEGER :: i

    factorial8=1

    IF(n .NE. 1 .AND. n .NE. 0) THEN
       DO i=2,n
          factorial8=factorial8*i
       END DO
    END IF

    factorial=INT(factorial8)

  END FUNCTION factorial

  FUNCTION sinc(x)

    !sinc function
    IMPLICIT NONE
    REAL :: sinc
    REAL, INTENT(IN) :: x
    REAL, PARAMETER :: dx=1e-3

    !This may actually be unnecessary

    IF(ABS(x)<dx) THEN
       sinc=1.-(x**2)/6.
    ELSE
       sinc=sin(x)/x
    END IF

  END FUNCTION sinc

  FUNCTION wk_tophat(x)

    !The normlaised Fourier Transform of a top-hat
    IMPLICIT NONE
    REAL :: wk_tophat
    REAL, INTENT(IN) :: x
    REAL, PARAMETER :: dx=1e-3

    !Taylor expansion used for low x to avoid cancellation problems
    IF(x<dx) THEN
       wk_tophat=1.-(x**2)/10.
    ELSE
       wk_tophat=3.*(sin(x)-x*cos(x))/(x**3)
    END IF

  END FUNCTION wk_tophat

  FUNCTION apodise(x,x1,x2,n)

    !Apodises a function between x1 and x2
    !Goes to one smoothly at x1
    !Goes to zero linearly at x2, so the gradient change is discontinous
    !n govenrns the severity of the transition
    IMPLICIT NONE
    REAL :: apodise
    REAL, INTENT(IN) :: x, x1, x2, n
    !REAL, PARAMETER :: pi=3.141592654

    IF(n<=0.) STOP 'APODISE: Error, n must be greater than zero'

    IF(x<x1) THEN
       apodise=1.
    ELSE IF(x>x2) THEN
       apodise=0.
    ELSE
       apodise=cos((pi/2.)*(x-x1)/(x2-x1))
       apodise=apodise**n
    END IF

  END FUNCTION apodise

  FUNCTION smoothapodise(x,x1,x2,n)

    !Apodises a function between x1 and x2
    !Goes to one smoothly at x1 and zero smoothly at x2
    !n govenrns the severity of the transition
    IMPLICIT NONE
    REAL :: smoothapodise
    REAL, INTENT(IN) :: x, x1, x2, n
    !REAL, PARAMETER :: pi=3.141592654

    IF(n<=0.) STOP 'APODISE: Error, n must be greater than zero'

    IF(x<x1) THEN
       smoothapodise=1.
    ELSE IF(x>x2) THEN
       smoothapodise=0.
    ELSE
       smoothapodise=0.5*(1.+cos(pi*(x-x1)/(x2-x1)))
       smoothapodise=smoothapodise**n
    END IF

  END FUNCTION smoothapodise

  FUNCTION blob(x,x1,x2,n)

    !Makes a blob between x1 and x2, with zero elsewhere
    !Blob goes to zero linearly at x1 and x2, so the gradient change is discontinous
    !n governs the severity (blobiness) of the blob
    IMPLICIT NONE
    REAL :: blob
    REAL, INTENT(IN) :: x, x1, x2, n
    !REAL, PARAMETER :: pi=3.141592654

    IF(n<=0.) STOP 'APODISE: Error, n must be greater than zero'

    IF(x<x1) THEN
       blob=0.
    ELSE IF(x>x2) THEN
       blob=0.
    ELSE
       blob=sin(pi*(x-x1)/(x2-x1))
       blob=blob**n
    END IF

  END FUNCTION blob

  FUNCTION smoothblob(x,x1,x2,n)

    !Makes a blob between x1 and x2, with zero elsewhere
    !Blob goes to zero smoothly at x1 and x2
    !n governs the severity (blobiness) of the blob
    IMPLICIT NONE
    REAL :: smoothblob
    REAL, INTENT(IN) :: x, x1, x2, n
    !REAL, PARAMETER :: pi=3.141592654

    IF(n<=0.) STOP 'APODISE: Error, n must be greater than zero'

    IF(x<x1) THEN
       smoothblob=0.
    ELSE IF(x>x2) THEN
       smoothblob=0.
    ELSE
       smoothblob=(1.+cos(2.*pi*(x-x1)/(x2-x1)))/2.
       smoothblob=(1.-smoothblob)**n
    END IF

  END FUNCTION smoothblob

  FUNCTION Si(x)

    !Calculates the 'sine integral' function Si(x)
    REAL :: Si
    REAL, INTENT(IN) :: x
    DOUBLE PRECISION :: x2, y, f, g, si8
    !DOUBLE PRECISION, PARAMETER :: pi=3.1415926535897932384626433d0

    REAL, PARAMETER :: x0=4.

    !Expansions for high and low x thieved from Wikipedia, two different expansions for above and below 4.
    IF(ABS(x)<=x0) THEN

        x2=x*x

        si8 = x*(1.d0+x2*(-4.54393409816329991d-2+x2*(1.15457225751016682d-3&
            +x2*(-1.41018536821330254d-5+x2*(9.43280809438713025d-8+x2*(-3.53201978997168357d-10&
            +x2*(7.08240282274875911d-13+x2*(-6.05338212010422477d-16))))))))/ &
            (1.+x2*(1.01162145739225565d-2 +x2*(4.99175116169755106d-5+&
            x2*(1.55654986308745614d-7+x2*(3.28067571055789734d-10+x2*(4.5049097575386581d-13&
            +x2*(3.21107051193712168d-16)))))))

        Si=REAL(si8)

    ELSE IF(ABS(x)>x0) THEN

        y=1.d0/(x*x)

        f = (1.d0 + y*(7.44437068161936700618d2 + y*(1.96396372895146869801d5 +&
            y*(2.37750310125431834034d7 +y*(1.43073403821274636888d9 + y*(4.33736238870432522765d10 &
            + y*(6.40533830574022022911d11 + y*(4.20968180571076940208d12 + &
            y*(1.00795182980368574617d13 + y*(4.94816688199951963482d12 +&
            y*(-4.94701168645415959931d11)))))))))))/ (x*(1. +y*(7.46437068161927678031d2 +&
            y*(1.97865247031583951450d5 +y*(2.41535670165126845144d7 + &
            y*(1.47478952192985464958d9 + y*(4.58595115847765779830d10 +&
            y*(7.08501308149515401563d11 + y*(5.06084464593475076774d12 + &
            y*(1.43468549171581016479d13 + y*(1.11535493509914254097d13)))))))))))


        g = y*(1.d0 + y*(8.1359520115168615d2 + y*(2.35239181626478200d5 + &
            y*(3.12557570795778731d7 + y*(2.06297595146763354d9 + y*(6.83052205423625007d10 +&
            y*(1.09049528450362786d12 + y*(7.57664583257834349d12 +y*(1.81004487464664575d13 +&
            y*(6.43291613143049485d12 +y*(-1.36517137670871689d12)))))))))))/&
            (1. + y*(8.19595201151451564d2 +y*(2.40036752835578777d5 + y*(3.26026661647090822d7 &
            + y*(2.23355543278099360d9 + y*(7.87465017341829930d10 + y*(1.39866710696414565d12 &
            + y*(1.17164723371736605d13 + y*(4.01839087307656620d13 +y*(3.99653257887490811d13))))))))))

        Si=REAL(pi/2.d0-f*cos(x)-g*sin(x))

     ELSE

        STOP 'SI: Something went very wrong'

    END IF

    END FUNCTION Si

    FUNCTION Ci(x)

    !Calculates the 'cosine integral' function Ci(x)
    REAL :: Ci
    REAL, INTENT(IN) :: x
    DOUBLE PRECISION :: x2, y, f, g, ci8
    !DOUBLE PRECISION, PARAMETER :: em_const=0.577215664901532861d0

    REAL, PARAMETER :: x0=4.

    !Expansions for high and low x thieved from Wikipedia, two different expansions for above and below 4.
    IF(ABS(x)<=x0) THEN

        x2=x*x

        ci8=em+log(x)+x2*(-0.25d0+x2*(7.51851524438898291d-3+x2*(-1.27528342240267686d-4&
            +x2*(1.05297363846239184d-6+x2*(-4.68889508144848019d-9+x2*(1.06480802891189243d-11&
            +x2*(-9.93728488857585407d-15)))))))/ (1.+x2*(1.1592605689110735d-2+&
            x2*(6.72126800814254432d-5+x2*(2.55533277086129636d-7+x2*(6.97071295760958946d-10+&
            x2*(1.38536352772778619d-12+x2*(1.89106054713059759d-15+x2*(1.39759616731376855d-18))))))))

        Ci=REAL(ci8)

    ELSE IF(ABS(x)>x0) THEN

        y=1./(x*x)

        f = (1.d0 + y*(7.44437068161936700618d2 + y*(1.96396372895146869801d5 + &
            y*(2.37750310125431834034d7 +y*(1.43073403821274636888d9 + y*(4.33736238870432522765d10&
            + y*(6.40533830574022022911d11 + y*(4.20968180571076940208d12 + y*(1.00795182980368574617d13&
            + y*(4.94816688199951963482d12 +y*(-4.94701168645415959931d11)))))))))))/&
            (x*(1. +y*(7.46437068161927678031d2 +y*(1.97865247031583951450d5 +&
            y*(2.41535670165126845144d7 + y*(1.47478952192985464958d9 + &
            y*(4.58595115847765779830d10 +y*(7.08501308149515401563d11 + y*(5.06084464593475076774d12 &
            + y*(1.43468549171581016479d13 + y*(1.11535493509914254097d13)))))))))))

        g = y*(1.d0 + y*(8.1359520115168615d2 + y*(2.35239181626478200d5 + y*(3.12557570795778731d7&
            + y*(2.06297595146763354d9 + y*(6.83052205423625007d10 +&
            y*(1.09049528450362786d12 + y*(7.57664583257834349d12 +&
            y*(1.81004487464664575d13 + y*(6.43291613143049485d12 +y*(-1.36517137670871689d12)))))))))))&
            / (1. + y*(8.19595201151451564d2 +y*(2.40036752835578777d5 +&
            y*(3.26026661647090822d7 + y*(2.23355543278099360d9 + y*(7.87465017341829930d10 &
            + y*(1.39866710696414565d12 + y*(1.17164723371736605d13 + y*(4.01839087307656620d13 +y*(3.99653257887490811d13))))))))))

        Ci=REAL(f*sin(x)-g*cos(x))

     ELSE

        STOP 'CI: Something went very wrong'

    END IF

  END FUNCTION Ci

  FUNCTION Bessel(n,x)

    IMPLICIT NONE
    REAL :: Bessel
    REAL :: x
    INTEGER :: n
    
    REAL, PARAMETER :: xlarge=1.e15

    IF(x>xlarge) THEN

       !To stop it going mental for very large values of x
       Bessel=0.d0

    ELSE

       IF(n<0) STOP 'Error: cannot call for negative n'

       IF(n==0) THEN
          Bessel=BESSEL_J0(REAL(x))
       ELSE IF(n==1) THEN
          Bessel=BESSEL_J1(REAL(x))
       ELSE
          Bessel=BESSEL_JN(n,REAL(x))      
       END IF

    END IF

  END FUNCTION Bessel

END MODULE special_functions