PROGRAM HMx_fitting

  USE HMx
  USE cosmology_functions
  USE cosmic_emu_stuff
  USE string_operations
  USE random_numbers
  USE special_functions

  IMPLICIT NONE
  INTEGER :: im
  INTEGER :: ncos, nf, nz, nk
  REAL, ALLOCATABLE :: k(:,:,:), z(:), pow_bm(:,:,:,:,:), pow_hm(:,:,:,:,:), weight(:,:,:,:,:)
  INTEGER, ALLOCATABLE :: fields(:)
  TYPE(halomod), ALLOCATABLE :: hmod(:)
  TYPE(cosmology), ALLOCATABLE :: cosm(:)
  REAL :: kmin, kmax
  CHARACTER(len=256) :: name, base, mode, zin, outbase, outfile, nchain
  REAL, ALLOCATABLE :: pow_sim(:), k_sim(:)
  INTEGER, ALLOCATABLE :: p_int(:)
  REAL, ALLOCATABLE :: p_min(:), p_max(:), p_bst(:), p_rge(:), p_new(:), p_old(:), p_ori(:)
  REAL, ALLOCATABLE :: q_min(:), q_max(:), q_ori(:), q_rge(:)
  CHARACTER(len=256), ALLOCATABLE :: p_nme(:), q_nme(:)
  LOGICAL, ALLOCATABLE :: p_log(:), q_log(:), p_set(:), q_set(:)
  REAL :: delta, fom, fom_bst, fom_new, fom_old, fom_ori
  LOGICAL :: accept
  INTEGER :: icosmo, ihm, i_bst, np, ip(2)
  INTEGER :: i, j, l, j1, j2, n
  INTEGER :: i_bet, i_wor, i_acc, i_fai
  LOGICAL :: verbose2
  INTEGER :: out

  ! Hydro fitting parameters  
  INTEGER, PARAMETER :: param_alpha=1
  INTEGER, PARAMETER :: param_eps=2
  INTEGER, PARAMETER :: param_gamma=3
  INTEGER, PARAMETER :: param_M0=4
  INTEGER, PARAMETER :: param_Astar=5
  INTEGER, PARAMETER :: param_Twhim=6
  INTEGER, PARAMETER :: param_cstar=7
  INTEGER, PARAMETER :: param_fcold=8
  INTEGER, PARAMETER :: param_mstar=9
  INTEGER, PARAMETER :: param_sstar=10
  INTEGER, PARAMETER :: param_alphap=11
  INTEGER, PARAMETER :: param_Gammap=12
  INTEGER, PARAMETER :: param_cstarp=13
  INTEGER, PARAMETER :: param_fhot=14
  INTEGER, PARAMETER :: param_alphaz=15
  INTEGER, PARAMETER :: param_Gammaz=16
  INTEGER, PARAMETER :: param_M0z=17
  INTEGER, PARAMETER :: param_Astarz=18
  INTEGER, PARAMETER :: param_Twhimz=19
  INTEGER, PARAMETER :: param_n=19

  REAL, PARAMETER :: mmin=1e7        ! Minimum halo mass for the calculation
  REAL, PARAMETER :: mmax=1e17       ! Maximum halo mass for the calculation

  INTEGER, PARAMETER :: m=HUGE(m)  ! Re-evaluate range every 'm' points
  INTEGER, PARAMETER :: seed=0 ! Random-number seed
  LOGICAL, PARAMETER :: random_start=.FALSE. ! Start from a random point within the prior range
  LOGICAL, PARAMETER :: mcmc=.TRUE. ! Accept worse figure of merit with some probability
  INTEGER, PARAMETER :: computer=1 ! Which computer are you on?

  ! Read in starting option
  CALL get_command_argument(1,mode)
  IF(mode=='') THEN
     !STOP 'HMx_FITTING: Error, please specify mode'
     im=-1
  ELSE
     READ(mode,*) im
  END IF

  ! Decide what to do
  IF(im==-1) THEN
     WRITE(*,*)
     WRITE(*,*) 'HMx_FITTING: Choose what to do'
     WRITE(*,*) '=============================='
     WRITE(*,*) ' 1 - Mira Titan nodes'
     WRITE(*,*) ' 2 - FrankenEmu nodes'
     WRITE(*,*) ' 3 - Random Mira Titan'
     WRITE(*,*) ' 4 - Random FrankenEmu'
     WRITE(*,*) '11 - Hydro: fixed z; everything'
     WRITE(*,*) '12 - Hydro: fixed z; gas'
     WRITE(*,*) '13 - Hydro: fixed z; stars'
     WRITE(*,*) '14 - Hydro: fixed z; gas and stars'
     WRITE(*,*) '15 - Hydro: fixed z; matter'
     WRITE(*,*) '16 - Hydro: fixed z; everything but pressure-pressure'
     WRITE(*,*) '17 - Hydro: all z; everything but pressure-pressure'     
     READ(*,*) im
     WRITE(*,*)
  END IF

  ! Read in chain length
  CALL get_command_argument(2,nchain)
  IF(nchain=='') THEN
     WRITE(*,*) 'HMx_FITTING: Specify points in fitting chain'
     READ(*,*) n
     WRITE(*,*)
  ELSE
     READ(nchain,*) n
  END IF

  ! Read in outfile
  CALL get_command_argument(3,outbase)
  IF(outbase=='') outbase='fitting/test'

  ! Read in BAHAMAS simulation name
  CALL get_command_argument(4,name)

  ! Read in BAHAMAS simulation redshift if doing fixed z
  CALL get_command_argument(5,zin)
  
  ! Set the random-number generator
  CALL RNG_set(seed)

  ! SET: number of cosmologies, fields and delta
  IF(im==1 .OR. im==2 .OR. im==3 .OR. im==4) THEN

     ! Required change in figure-of-merit
     delta=1e-4 
     
     IF(im==1 .OR. im==3) THEN
        ncos=9 ! Number of Mita Titan nodes - only 10 have Omega_nu = 0. (ignore 1 because it is weird)
        nf=1
     ELSE IF(im==2 .OR. im==4) THEN
        ncos=37 ! Number of FrankenEmu nodes
        nf=1
     ELSE
        STOP 'HMx_FITTING: Error, something went wrong with setting fields'
     END IF
     
  ELSE IF(im==11 .OR. im==12 .OR. im==13 .OR. im==14 .OR. im==15 .OR. im==16 .OR. im==17 .OR. im==18) THEN

     ! Required change in figure-of-merit
     delta=1e-3

     ! Set to the number of different cosmologies
     ncos=1 

     ! Set the number of different fields
     IF(im==11 .OR. im==16 .OR. im==17 .OR. im==18) THEN
        nf=5   
     ELSE IF(im==12 .OR. im==13) THEN
        nf=1
     ELSE IF(im==14) THEN
        nf=2
     ELSE IF(im==15) THEN
        nf=4
     ELSE
        STOP 'HMx_FITTING: Error, something went wrong with setting fields'
     END IF
     
  ELSE
     STOP 'HMx_FITTING: Error, something went wrong with setting fields'
  END IF

  ! Allocate arrays for cosmology and fields
  ALLOCATE(cosm(ncos),fields(nf))

  ! SET: redshifts and halo-profiles here     
  IF(im==1 .OR. im==2 .OR. im==3 .OR. im==4) THEN
     
     ! Mira Titan or FrankenEmu
     nz=4
     ALLOCATE(z(nz))
     z(1)=0.0
     z(2)=0.5
     z(3)=1.0
     z(4)=2.0
     fields(1)=field_dmonly
     
  ELSE IF(im==11 .OR. im==12 .OR. im==13 .OR. im==14 .OR. im==15 .OR. im==16 .OR. im==17 .OR. im==18) THEN
     
     ! Hydro simulations
     IF(name=='') name='AGN_TUNED_nu0'
     
     IF(im==11 .OR. im==12 .OR. im==13 .OR. im==14 .OR. im==15 .OR. im==16) THEN
        !kmin=0.15
        !kmax=10.
        nz=1
     ELSE IF(im==17) THEN
        !kmin=0.15
        !kmax=10.
        nz=4
     ELSE
        STOP 'HMx_FITTING: Error, im not specified correctly'
     END IF
     
     ALLOCATE(z(nz))

     ! Set the redshifts
     IF(im==11 .OR. im==12 .OR. im==13 .OR. im==14 .OR. im==15 .OR. im==16 .OR. im==18) THEN        
        IF((zin)=='') THEN
           z(1)=0.0 
        ELSE
           READ(zin,*) z(1)
        END IF        
     ELSE IF(im==17) THEN
        z(1)=0.0
        z(2)=0.5
        z(3)=1.0
        z(4)=2.0
     ELSE
        STOP 'HMx_FITTING: Error, im not specified correctly'
     END IF

     ! Set the fields
     IF(im==11 .OR. im==16 .OR. im==17 .OR. im==18) THEN
        fields(1)=field_matter
        fields(2)=field_cdm
        fields(3)=field_gas
        fields(4)=field_star
        fields(5)=field_electron_pressure
     ELSE IF(im==12) THEN
        fields(1)=field_gas
     ELSE IF(im==13) THEN
        fields(1)=field_star
     ELSE IF(im==14) THEN
        fields(1)=field_gas
        fields(2)=field_star
     ELSE IF(im==15) THEN
        fields(1)=field_matter
        fields(2)=field_cdm
        fields(3)=field_gas
        fields(4)=field_star
     END IF
     
  ELSE
     STOP 'HMx_FITTING: Error, something went wrong'
  END IF

  ! Assign the cosmological models
  DO i=1,ncos
     
     IF(im==1) THEN
        icosmo=101+i ! Set set Mira Titan node (note that we are skipping node 1)
     ELSE IF(im==2) THEN
        icosmo=200+i ! Set set FrankenEmu node
     ELSE IF(im==3) THEN
        icosmo=24    ! Random Mira Titan cosmology
     ELSE IF(im==4) THEN
        icosmo=25    ! Random FrankenEmu cosmology
     ELSE IF(im==11 .OR. im==12 .OR. im==13 .OR. im==14 .OR. im==15 .OR. im==16 .OR. im==17 .OR. im==18) THEN
        icosmo=4 ! WMAP9
     ELSE
        STOP 'HMx_FITTING: Error, im not specified correctly'
     END IF
     
     CALL assign_cosmology(icosmo,cosm(i),verbose=.TRUE.)
     CALL init_cosmology(cosm(i))
     CALL print_cosmology(cosm(i))
     
  END DO

  ! SET: halo model here
  ALLOCATE(hmod(ncos))
  IF(im==1 .OR. im==2 .OR. im==3 .OR. im==4) THEN
     ihm=15 ! HMcode 2018
  ELSE IF(im==11 .OR. im==12 .OR. im==13 .OR. im==14 .OR. im==15 .OR. im==16 .OR. im==17 .OR. im==18) THEN
     ihm=20 ! Standard halo-model response
  ELSE
     STOP 'HMx_FITTING: Error, im not specified correctly'
  END IF
     
  DO i=1,ncos
     CALL assign_halomod(ihm,hmod(i),verbose=.FALSE.)
  END DO

  ! Just print one halo model to screen to see
  CALL init_halomod(mmin,mmax,scale_factor_z(z(1)),hmod(1),cosm(1),verbose=.TRUE.)
  CALL print_halomod(hmod(1),cosm(1),verbose=.TRUE.)

  !! Read in the simulation power spectra for the models

  ! Loop over cosmologies and redshifts
  DO i=1,ncos
     DO j=1,nz

        ! Loop over fields
        DO j1=1,nf
           DO j2=j1,nf

              ! Read in power spectra
              IF(im==1 .OR. im==3) THEN
                 CALL read_Mira_Titan_power(k_sim,pow_sim,nk,z(j),cosm(i),rebin=.TRUE.)
              ELSE IF(im==2 .OR. im==4) THEN
                 CALL read_FrankenEmu_power(k_sim,pow_sim,nk,z(j),cosm(i),rebin=.TRUE.)
              ELSE IF(im==11 .OR. im==12 .OR. im==13 .OR. im==14 .OR. im==15 .OR. im==16 .OR. im==17 .OR. im==18) THEN
                 ip(1)=fields(j1)
                 ip(2)=fields(j2)
                 CALL read_BAHAMAS_power(k_sim,pow_sim,nk,z(j),name,ip,cosm(i))!,kmin,kmax)
              ELSE
                 STOP 'HMx_FITTING: Error, something went wrong'
              END IF

              ! Allocate big arrays for P(k,z,cosm)
!!$              IF(i==1 .AND. j==1 .AND. j1==1 .AND. j2==1) THEN
!!$                 ALLOCATE(k(ncos,nk,nz),pow_bm(ncos,nf,nf,nk,nz),weight(ncos,nf,nf,nk,nz))
!!$                 weight=1.
!!$              END IF
              IF(.NOT. ALLOCATED(k))      ALLOCATE(k(ncos,nk,nz))
              IF(.NOT. ALLOCATED(pow_bm)) ALLOCATE(pow_bm(ncos,nf,nf,nk,nz))
              k(i,:,j)=k_sim
              pow_bm(i,j1,j2,:,j)=pow_sim
              
           END DO
        END DO

     END DO
  END DO

  ALLOCATE(weight(ncos,nf,nf,nk,nz))
  weight=1.

  IF(im==16 .OR. im==17 .OR. im==18) THEN
     weight(:,5,5,:,:)=0. ! No weight to pressure-pressure
  END IF

  ! k range for fixed z
  IF(im==11 .OR. im==12 .OR. im==13 .OR. im==14 .OR. im==15 .OR. im==16 .OR. im==18) THEN
     kmin=0.15
     kmax=10.
     DO i=1,nk
        IF(k(1,i,1)<kmin .OR. k(1,i,1)>kmax) THEN
           weight(:,:,:,i,:)=0.
        END IF
     END DO
  END IF

  ! k range for multi-z
  IF(im==17) THEN    
     DO j=1,nz
        kmin=0.15
        IF(j==1) kmax=10. ! z = 0.0
        IF(j==2) kmax=4.  ! z = 0.5
        IF(j==3) kmax=2.  ! z = 1.0
        IF(j==4) kmax=1.  ! z = 2.0
        DO i=1,nk
           IF(k(1,i,j)<kmin .OR. k(1,i,j)>kmax) weight(:,:,:,i,j)=0.
        END DO
     END DO
  END IF

  !!

  ! Allocate arrays for halo-model power
  ALLOCATE(pow_hm(ncos,nf,nf,nk,nz))

  ! SET: varying parameters, number of them, and initial values here

  ! Set initial parameters
  IF(im==1 .OR. im==2 .OR. im==3 .OR. im==4) THEN
     ! Mira Titan or FrankenEmu fitting for HMcode
     np=12
  ELSE IF(im==11 .OR. im==16) THEN
     ! everything
     np=13
  ELSE IF(im==12) THEN
     ! gas
     np=6
  ELSE IF(im==13) THEN
     ! stars
     np=5
  ELSE IF(im==14 .OR. im==15) THEN
     ! 14 - gas and stars
     ! 15 - matter
     np=10
  ELSE IF(im==17) THEN
     ! everything with z dependence
     np=18
  ELSE IF(im==18) THEN
     ! everything with fhot
     np=14
  ELSE
     STOP 'HMx_FITTING: Something went wrong with np'
  END IF

  ALLOCATE(p_bst(np),p_new(np),p_old(np),p_rge(np),p_ori(np),p_log(np),p_min(np),p_max(np),p_nme(np))
  ALLOCATE(p_set(np))
  !p_log=.FALSE.

  IF(im==1 .OR. im==2 .OR. im==3 .OR. im==4) THEN

     ! None of these parameters are explored in log
     p_log=.FALSE.
     p_set=.TRUE.

     p_nme(1)='Dv0'
     p_ori(1)=418. 
     p_min(1)=50.
     p_max(1)=1000.

     p_nme(2)='Dvp'
     p_ori(2)=-0.352
     p_min(2)=-5.
     p_max(2)=5.

     p_nme(3)='dc0'
     p_ori(3)=1.59
     p_min(3)=1.
     p_max(3)=2.

     p_nme(4)='dcp'
     p_ori(4)=0.0314
     p_min(4)=-5.
     p_max(4)=5.

     p_nme(5)='eta0'
     p_ori(5)=0.603
     p_min(5)=-5.
     p_max(5)=5.

     p_nme(6)='eta1'
     p_ori(6)=0.300
     p_min(6)=-5.
     p_max(6)=5.

     p_nme(7)='f0'
     !p_ori(7)=0.0095 ! Mead (2016) 
     p_ori(7)=0.188 ! Mead (2015) damping
     p_min(7)=-5.
     p_max(7)=5.

     p_nme(8)='fp'
     !p_ori(8)=1.37 ! Mead (2016)
     p_ori(8)=4.29 ! Mead (2015)
     p_min(8)=-10.
     p_max(8)=10.

     p_nme(9)='kstar'
     p_ori(9)=0.584
     p_min(9)=-5.
     p_max(9)=5.

     p_nme(10)='As'
     p_ori(10)=3.13
     p_min(10)=1.
     p_max(10)=10.

     p_nme(11)='alpha0'
     p_ori(11)=3.24
     p_min(11)=-5.
     p_max(11)=5.

     p_nme(12)='alpha1'
     p_ori(12)=1.85
     p_min(12)=-5.
     p_max(12)=5.

  ELSE IF(im==11 .OR. im==12 .OR. im==13 .OR. im==14 .OR. im==15 .OR. im==16 .OR. im==17 .OR. im==18) THEN

     ! The general parameters are set here

     ALLOCATE(q_ori(param_n),q_log(param_n),q_min(param_n),q_max(param_n),q_nme(param_n))
     ALLOCATE(q_set(param_n),q_rge(param_n))
     ALLOCATE(p_int(np))

     q_log=.TRUE.
     q_set=.TRUE.

     q_nme(1)='alpha'
     q_ori(1)=1.60*(1.+z(1))
     q_min(1)=1e-2
     q_max(1)=1e1

     ! Can not be one because log(1)=0 and this messes things up in setting the ranges
     q_nme(2)='epsilon'
     q_ori(2)=1.1
     q_min(2)=1e-2
     q_max(2)=1e2

     q_nme(3)='Gamma-1'
     q_ori(3)=0.24
     q_min(3)=0.01
     q_max(3)=2.
     q_log(3)=.FALSE.

     ! This must depend on z to ensure parameter has an effect at the higher z when 10^14 haloes are rare
     q_nme(4)='M0'
     q_ori(4)=10**13.77/(10.**z(1)) ! Okay with z dependence as long as z(1)=0
     q_min(4)=1e8
     q_max(4)=1e16

     q_nme(5)='A_*'
     q_ori(5)=0.042
     q_min(5)=1e-3
     q_max(5)=1e-1

     ! For some reason when 1e6 is set a range is calculated that gives too large a change in figure-of-merit
     q_nme(6)='T_whim'
     q_ori(6)=10**6.11
     q_min(6)=1e2
     q_max(6)=1e8

     q_nme(7)='c_*'
     q_ori(7)=7.
     q_min(7)=1e0
     q_max(7)=1e3

     ! Needed to boost original here so that it has an effect
     q_nme(8)='f_cold'
     !q_ori(8)=0.01
     q_ori(8)=0.00126
     q_min(8)=1e-5
     q_max(8)=0.5
     q_set(8)=.FALSE.
     q_rge(8)=0.1

     q_nme(9)='M_*'
     q_ori(9)=10**12.4
     q_min(9)=1e8
     q_max(9)=1e16

     q_nme(10)='sigma_*'
     q_ori(10)=0.8
     q_min(10)=0.1
     q_max(10)=10.
     q_log(10)=.FALSE.

     q_nme(11)='alpha M index'
     q_ori(11)=-0.5
     q_min(11)=-1.
     q_max(11)=1.
     q_log(11)=.FALSE.
     !q_set(11)=.FALSE.
     !q_rge(11)=0.01

     q_nme(12)='Gamma M index'
     q_ori(12)=-0.02
     q_min(12)=-0.006
     q_max(12)=0.2
     q_log(12)=.FALSE.
     !q_set(12)=.FALSE.
     !q_rge(12)=0.001

     q_nme(13)='c_* M index'
     q_ori(13)=-0.2
     q_min(13)=-1.
     q_max(13)=1.
     q_log(13)=.FALSE.
     !q_set(13)=.FALSE.
     !q_rge(13)=0.01

     q_nme(14)='f_hot'
     q_ori(14)=0.01
     q_min(14)=1e-5
     q_max(14)=0.5

     q_nme(15)='alpha z index'
     q_ori(15)=0.43
     q_min(15)=-3.
     q_max(15)=3.
     q_log(15)=.FALSE.
     !q_set(15)=.FALSE.
     !q_rge(15)=0.01

     q_nme(16)='Gamma z index'
     q_ori(16)=0.3
     q_min(16)=-1.
     q_max(16)=1.
     q_log(16)=.FALSE.
     !q_set(16)=.FALSE.
     !q_rge(16)=0.01

     q_nme(17)='M0 z index'
     q_ori(17)=-0.08
     q_min(17)=-1.
     q_max(17)=1.
     q_log(17)=.FALSE.
     !q_set(17)=.FALSE.
     !q_rge(17)=0.01

     q_nme(18)='Astar z index'
     q_ori(18)=-0.45
     q_min(18)=-1.
     q_max(18)=1.
     q_log(18)=.FALSE.
     !q_set(18)=.FALSE.
     !q_rge(18)=0.01

     q_nme(19)='Twhim z index'
     q_ori(19)=-0.11
     q_min(19)=-1.
     q_max(19)=1.
     q_log(19)=.FALSE.
     !q_set(19)=.FALSE.
     !q_rge(19)=0.01
     
     IF(im==11 .OR. im==16 .OR. im==18) THEN

        ! 11 - everything
        ! 16 - everything minus pressure-pressure
        ! 18 - everything minus pressure-pressure but with hot gas
        p_int(1)=param_alpha
        p_int(2)=param_eps
        p_int(3)=param_Gamma
        p_int(4)=param_M0
        p_int(5)=param_Astar
        p_int(6)=param_Twhim
        p_int(7)=param_cstar
        p_int(8)=param_fcold
        p_int(9)=param_Mstar
        p_int(10)=param_sstar
        p_int(11)=param_alphap
        p_int(12)=param_Gammap
        p_int(13)=param_cstarp
        IF(im==18) p_int(14)=param_fhot

     ELSE IF(im==17) THEN

        ! redshift dependent everything minus pressure-pressure
        p_int(1)=param_alpha
        p_int(2)=param_eps
        p_int(3)=param_Gamma
        p_int(4)=param_M0
        p_int(5)=param_Astar
        p_int(6)=param_Twhim
        p_int(7)=param_cstar
        p_int(8)=param_fcold
        p_int(9)=param_Mstar
        p_int(10)=param_sstar
        p_int(11)=param_alphap
        p_int(12)=param_Gammap
        p_int(13)=param_cstarp
        !p_int(14)=param_fhot
        p_int(14)=param_alphaz
        p_int(15)=param_Gammaz
        p_int(16)=param_M0z
        p_int(17)=param_Astarz
        p_int(18)=param_Twhimz

     ELSE IF(im==12) THEN

        ! gas
        p_int(1)=param_eps
        p_int(2)=param_Gamma
        p_int(3)=param_M0
        p_int(4)=param_Astar
        p_int(5)=param_fcold
        p_int(6)=param_Gammap

     ELSE IF(im==13) THEN

        ! stars
        p_int(1)=param_Astar
        p_int(2)=param_cstar
        p_int(3)=param_cstarp
        p_int(4)=param_Mstar
        p_int(5)=param_sstar       

     ELSE IF(im==14 .OR. im==15) THEN

        ! 14 - gas and stars
        ! 15 - matter
        p_int(1)=param_eps
        p_int(2)=param_Gamma
        p_int(3)=param_M0
        p_int(4)=param_Astar
        p_int(5)=param_cstar
        p_int(6)=param_fcold
        p_int(7)=param_Gammap
        p_int(8)=param_cstarp
        p_int(9)=param_Mstar
        p_int(10)=param_sstar

     ELSE

        STOP 'HMx_FITTING: Something went wrong with setting parameters'
        
     END IF

     ! Actually fill the proper parameter arrays
     DO i=1,np
        j=p_int(i)
        p_nme(i)=q_nme(j)
        p_ori(i)=q_ori(j)
        p_min(i)=q_min(j)
        p_max(i)=q_max(j)
        p_log(i)=q_log(j)
        p_rge(i)=q_rge(j)
        p_set(i)=q_set(j)
     END DO

  ELSE

     STOP 'HMx_FITTING: Something went wrong with setting parameters'

  END IF

  ! Start from a random place within the prior
  IF(random_start) THEN     
     DO i=1,np
        p_ori(i)=random_uniform(p_min(i),p_max(i))
     END DO
  END IF

  ! Take the log of those parameters that are explored in log
  DO i=1,np
     IF(p_log(i)) THEN
        p_ori(i)=log10(p_ori(i))
        p_min(i)=log10(p_min(i))
        p_max(i)=log10(p_max(i))
     END IF
  END DO

  ! Set the new parameters
  p_old=p_ori
  p_new=p_ori

  ! Set the best figures-of-merit to some huge value
  fom_old=HUGE(fom)
  fom_new=HUGE(fom)
  fom_bst=HUGE(fom)

  ! Loop over number of runs
  WRITE(*,*) 'HMx_FITTING: Starting fitting'
  WRITE(*,*) 'HMx_FITTING: Number of points:', n
  WRITE(*,*)

  ! Set counting variables to zero
  i_bet=0
  i_wor=0
  i_acc=0
  i_fai=0

  ! Do the chain
  DO l=1,n+1

     IF(l==1 .OR. mod(l,m)==0) THEN
        IF(l==1) THEN
           verbose2=.TRUE.
        ELSE
           verbose2=.TRUE.
        END IF
        CALL set_parameter_ranges(im,delta,fields,nf,p_rge,p_set,p_old,p_log,p_nme,np,k,nk,z,nz,pow_bm,weight,hmod,cosm,ncos,verbose2)
        IF(l==1) THEN
           outfile=TRIM(outbase)//'_chain.dat'
           OPEN(10,file=outfile)
        END IF
        !STOP
     END IF

     IF(l==1) THEN
        ! Do nothing
     ELSE IF(l==n+1) THEN
        ! Set to best-fitting parameters on last go
        p_new=p_bst           
     ELSE
        ! Randomly jump parameters
        DO i=1,np
           p_new(i)=random_Gaussian(p_old(i),p_rge(i))
           IF(p_new(i)<p_min(i)) p_new(i)=p_min(i)
           IF(p_new(i)>p_max(i)) p_new(i)=p_max(i)
        END DO
     END IF

     ! Calculate the figure-of-merit
     CALL fom_multiple(im,fields,nf,fom_new,p_new,p_log,np,k,nk,z,nz,pow_hm,pow_bm,weight,hmod,cosm,ncos)

     ! Write original power spectra to disk
     IF(l==1) THEN

        ! Set the original figure-of-merit to the new figure-of-merit
        fom_old=fom_new
        fom_ori=fom_new
        fom_bst=fom_new

        ! Write out the original data
        base=TRIM(outbase)//'_orig_cos'
        CALL write_fitting_power(base,k,pow_hm,pow_bm,ncos,nf,nk,nz)

        accept=.TRUE.

        i_bet=i_bet+1

     ELSE IF(l==n+1) THEN

        WRITE(*,*)
        
        ! Output the best-fitting model
        base=TRIM(outbase)//'_best_cos'
        CALL write_fitting_power(base,k,pow_hm,pow_bm,ncos,nf,nk,nz)

        accept=.TRUE.
        EXIT

     ELSE

        IF(fom_new < fom_bst) THEN
           ! If fit is the best then always accept...
           p_bst=p_new
           i_bst=l
           fom_bst=fom_new
           accept=.TRUE.
           i_bet=i_bet+1
        ELSE IF(fom_new <= fom_old) THEN
           ! ...also accept if fom is better than previous...
           accept=.TRUE.
           i_bet=i_bet+1
        ELSE IF(mcmc .AND. (fom_old/fom_new)**(1./delta) > random_uniform(0.,1.)) THEN
           ! ...otherwise accept poorer fit with some probability...
           accept=.TRUE.
           i_wor=i_wor+1
        ELSE
           ! ...otherwise, do not accept.
           accept=.FALSE.
           i_fai=i_fai+1
        END IF

     END IF

     IF(l .NE. n+1) WRITE(*,fmt='(I10,3F14.7,L3)') l, fom_bst, fom_old, fom_new, accept

     IF(accept) THEN
        i_acc=i_acc+1
        p_old=p_new
        fom_old=fom_new
        WRITE(10,*) fom_old, (p_old(j), j=1,np)
     END IF

  END DO
  CLOSE(10)
  WRITE(*,*) 'HMx_FITTING: Done'
  WRITE(*,*)

  ! Write useful information to screen and file
  DO j=1,2

     IF(j==1) THEN
        out=6
     ELSE IF(j==2) THEN
        out=7
        outfile=TRIM(outbase)//'_params.dat'
        OPEN(out,file=outfile)
     ELSE
        STOP 'HMx_FITTING: Error, output fucked up badly'
     END IF

     WRITE(out,*) 'HMx_FITTING: Best location:', i_bst
     WRITE(out,*) 'HMx_FITTING: Total attempts:', n
     WRITE(out,*) 'HMx_FITTING: Accepted steps:', i_acc
     WRITE(out,*) 'HMx_FITTING: Fraction accepted steps:', REAL(i_acc)/REAL(n)
     WRITE(out,*) 'HMx_FITTING: Better steps:', i_bet
     WRITE(out,*) 'HMx_FITTING: Fraction better steps:', REAL(i_bet)/REAL(n)
     WRITE(out,*) 'HMx_FITTING: Accepted worse steps:', i_wor
     WRITE(out,*) 'HMx_FITTING: Fraction accepted worse steps:', REAL(i_wor)/REAL(n)
     WRITE(out,*) 'HMx_FITTING: Failed steps:', i_fai
     WRITE(out,*) 'HMx_FITTING: Fraction failed steps:', REAL(i_fai)/REAL(n)
     WRITE(out,*) 'HMx_FITTING: Original figure-of-merit:', fom_ori
     WRITE(out,*) 'HMx_FITTING: Final figure-of-merit:', fom_new
     WRITE(out,*)

     WRITE(out,*) 'HMx_FITTING: Best-fitting parameters'
     WRITE(out,*) '====================================================================================='
     WRITE(out,*) 'Parameter           Name           Original          Best       Minimum       Maximum'
     WRITE(out,*) '====================================================================================='
     DO i=1,np
        IF(p_log(i)) THEN
           WRITE(out,fmt='(I10,A15,A5,4F14.7)') i, TRIM(p_nme(i)), 'lin', 10**p_ori(i), 10**p_bst(i), 10**p_min(i), 10**p_max(i)
           WRITE(out,fmt='(I10,A15,A5,4F14.7)') i, TRIM(p_nme(i)), 'log', p_ori(i), p_bst(i), p_min(i), p_max(i)
        ELSE
           WRITE(out,fmt='(I10,A15,A5,4F14.7)') i, TRIM(p_nme(i)), 'lin', p_ori(i), p_bst(i), p_min(i), p_max(i)
        END IF
     END DO
     WRITE(out,*) '====================================================================================='
     WRITE(out,*)

     IF(j==2) THEN
        CLOSE(out)
     END IF

  END DO

CONTAINS

!!$  REAL FUNCTION figure_of_merit(a,b,n)
!!$
!!$    ! A figure-of-merit or cost function
!!$    IMPLICIT NONE
!!$    REAL, INTENT(IN) :: a(n), b(n)
!!$    INTEGER, INTENT(IN) :: n
!!$
!!$    !figure_of_merit=(SUM(a/b)-REAL(n))**2
!!$    figure_of_merit=sqrt(SUM((a/b-1.)**2)/REAL(n))
!!$    !figure_of_merit=SUM(log(a/b)**2)/REAL(n)
!!$
!!$  END FUNCTION figure_of_merit

!!$   REAL FUNCTION figure_of_merit(a,b)
!!$
!!$    ! A figure-of-merit or cost function
!!$    IMPLICIT NONE
!!$    REAL, INTENT(IN) :: a, b
!!$    
!!$    !figure_of_merit=sqrt(SUM((a/b-1.)**2)/REAL(n))
!!$    figure_of_merit=(-1.+a/b)**2
!!$
!!$  END FUNCTION figure_of_merit

  SUBROUTINE fom_multiple(im,fields,nf,fom,p,p_log,np,k,nk,z,nz,pow_hm,pow_sim,weight,hmod,cosm,n)

    USE special_functions

    IMPLICIT NONE
    INTEGER, INTENT(IN) :: im ! Mode for the driver
    INTEGER, INTENT(IN) :: fields(nf) ! Field types
    INTEGER, INTENT(IN) :: nf ! Number of fields
    REAL, INTENT(OUT) :: fom ! Output figure of merit
    REAL, INTENT(IN) :: p(np) ! Array of varying parameters
    LOGICAL, INTENT(IN) :: p_log(np) ! Array of which parameters are explored in log
    INTEGER, INTENT(IN) :: np ! Number of varying parameters
    REAL, INTENT(IN) :: k(n,nk,nz) ! Array of k values for comparison data
    INTEGER, INTENT(IN) :: nk ! Number of k values for comparison data
    REAL, INTENT(IN) :: z(nz) ! Array of z values for comparison data
    INTEGER, INTENT(IN) :: nz ! Number of z values
    REAL, INTENT(OUT) :: pow_hm(n,nf,nf,nk,nz) ! Output array for power as a function of k, z, cosmology
    REAL, INTENT(IN) :: pow_sim(n,nf,nf,nk,nz) ! Comparison power as a function of k, z, cosmology
    REAL, INTENT(IN) :: weight(n,nf,nf,nk,nz) ! Weight array
    TYPE(halomod), INTENT(INOUT) :: hmod(n) ! Array of halo models for each comparison
    TYPE(cosmology), INTENT(INOUT) :: cosm(n) ! Array of cosmological models for each comparison
    INTEGER, INTENT(IN) :: n ! Number of cosmological models being compared
    INTEGER :: i, j, ik
    REAL :: pow_li(n,nk,nz), pow_2h(n,nf,nf,nk,nz), pow_1h(n,nf,nf,nk,nz)
    REAL :: pexp(np), neff

    ! Set this counting output variable to zero
    fom=0.
    neff=0.

    ! Set this to zero too, for the banter
    pow_hm=0.

    ! Loop over cosmologies
    DO i=1,n

       ! SET: parameters here

       ! Exponentiate those parameters that need it
       DO j=1,np
          IF(p_log(j)) THEN
             pexp(j)=10**p(j)
          ELSE
             pexp(j)=p(j)
          END IF
       END DO

       If(im==1 .OR. im==2 .OR. im==3 .OR. im==4) THEN

          ! Set HMcode parameters to those being varied
          hmod(i)%Dv0=pexp(1)
          hmod(i)%Dv1=pexp(2)
          hmod(i)%dc0=pexp(3)
          hmod(i)%dc1=pexp(4)
          hmod(i)%eta0=pexp(5)
          hmod(i)%eta1=pexp(6)
          hmod(i)%f0=pexp(7)
          hmod(i)%f1=pexp(8)
          hmod(i)%ks=pexp(9)
          hmod(i)%As=pexp(10)
          hmod(i)%alp0=pexp(11)
          hmod(i)%alp1=pexp(12)

       ELSE IF(im==11) THEN

          ! Set hydro parameters to those being varied

          ! everything
          hmod(i)%alpha=pexp(1)
          hmod(i)%eps=pexp(2)
          hmod(i)%Gamma=1.+pexp(3)
          hmod(i)%M0=pexp(4)
          hmod(i)%Astar=pexp(5)
          hmod(i)%Twhim=pexp(6)
          hmod(i)%cstar=pexp(7)
          hmod(i)%fcold=pexp(8)
          hmod(i)%Mstar=pexp(9)
          hmod(i)%sstar=pexp(10)
          hmod(i)%alphap=pexp(11)
          hmod(i)%Gammap=pexp(12)
          hmod(i)%cstarp=pexp(13)
          hmod(i)%fhot=pexp(14)

       ELSE IF(im==12) THEN

          ! gas
          hmod(i)%eps=pexp(1)
          hmod(i)%Gamma=1.+pexp(2)
          hmod(i)%M0=pexp(3)
          hmod(i)%Astar=pexp(4)
          hmod(i)%fcold=pexp(5)
          hmod(i)%Gammap=pexp(6)

       ELSE IF(im==13) THEN

          ! stars
          hmod(i)%Astar=pexp(1)
          hmod(i)%cstar=pexp(2)
          hmod(i)%cstarp=pexp(3)
          hmod(i)%Mstar=pexp(4)
          hmod(i)%sstar=pexp(5)

       ELSE IF(im==14 .OR. im==15) THEN

          ! 14 - gas and stars
          ! 15 - matter
          hmod(i)%eps=pexp(1)
          hmod(i)%Gamma=1.+pexp(2)
          hmod(i)%M0=pexp(3)
          hmod(i)%Astar=pexp(4)
          hmod(i)%cstar=pexp(5)
          hmod(i)%fcold=pexp(6)
          hmod(i)%Gammap=pexp(7)
          hmod(i)%cstarp=pexp(8)
          hmod(i)%Mstar=pexp(9)
          hmod(i)%sstar=pexp(10)

       ELSE IF(im==16) THEN

          ! everything
          hmod(i)%alpha=pexp(1)
          hmod(i)%eps=pexp(2)
          hmod(i)%Gamma=1.+pexp(3)
          hmod(i)%M0=pexp(4)
          hmod(i)%Astar=pexp(5)
          hmod(i)%Twhim=pexp(6)
          hmod(i)%cstar=pexp(7)
          hmod(i)%fcold=pexp(8)
          hmod(i)%Mstar=pexp(9)
          hmod(i)%sstar=pexp(10)
          hmod(i)%alphap=pexp(11)
          hmod(i)%Gammap=pexp(12)
          hmod(i)%cstarp=pexp(13)

       ELSE IF(im==17) THEN

          ! everything; simultaneous z
          hmod(i)%alpha=pexp(1)
          hmod(i)%eps=pexp(2)
          hmod(i)%Gamma=1.+pexp(3)
          hmod(i)%M0=pexp(4)
          hmod(i)%Astar=pexp(5)
          hmod(i)%Twhim=pexp(6)
          hmod(i)%cstar=pexp(7)
          hmod(i)%fcold=pexp(8)
          hmod(i)%Mstar=pexp(9)
          hmod(i)%sstar=pexp(10)
          hmod(i)%alphap=pexp(11)
          hmod(i)%Gammap=pexp(12)
          hmod(i)%cstarp=pexp(13)
          hmod(i)%alphaz=pexp(14)
          hmod(i)%Gammaz=pexp(15)
          hmod(i)%M0z=pexp(16)
          hmod(i)%Astarz=pexp(17)
          hmod(i)%Twhimz=pexp(18)

       ELSE IF(im==18) THEN

          ! everything; separate z; fhot
          hmod(i)%alpha=pexp(1)
          hmod(i)%eps=pexp(2)
          hmod(i)%Gamma=1.+pexp(3)
          hmod(i)%M0=pexp(4)
          hmod(i)%Astar=pexp(5)
          hmod(i)%Twhim=pexp(6)
          hmod(i)%cstar=pexp(7)
          hmod(i)%fcold=pexp(8)
          hmod(i)%Mstar=pexp(9)
          hmod(i)%sstar=pexp(10)
          hmod(i)%alphap=pexp(11)
          hmod(i)%Gammap=pexp(12)
          hmod(i)%cstarp=pexp(13)
          hmod(i)%fhot=pexp(14)

       ELSE

          STOP 'FOM_MULTIPLE: Error, im not specified correctly'

       END IF

       ! Loop over redshifts
       DO j=1,nz

          ! Initialise the halo-model calculation
          CALL init_halomod(mmin,mmax,scale_factor_z(z(j)),hmod(i),cosm(i),verbose=.FALSE.)
          CALL print_halomod(hmod(i),cosm(i),verbose=.FALSE.)

          ! Calculate the halo-model power spectrum
          CALL calculate_HMx_a(fields,nf,k(i,:,j),nk,pow_li(i,:,j),pow_2h(i,:,:,:,j),pow_1h(i,:,:,:,j),pow_hm(i,:,:,:,j),hmod(i),cosm(i),verbose=.FALSE.,response=.FALSE.)

          ! Calculate figure of merit and add to total
          DO j1=1,nf
             DO j2=j1,nf
                !fom=fom+(figure_of_merit(pow_hm(i,j1,j2,:,j),pow_sim(i,j1,j2,:,j),nk)*weight(i,j1,j2,j))**2
                DO ik=1,nk
                   !fom=fom+figure_of_merit(pow_hm(i,j1,j2,ik,j),pow_sim(i,j1,j2,ik,j))*weight(i,j1,j2,j)
                   fom=fom+weight(i,j1,j2,ik,j)*(pow_hm(i,j1,j2,ik,j)/pow_sim(i,j1,j2,ik,j)-1.)**2
                   neff=neff+weight(i,j1,j2,ik,j)
                END DO
             END DO
          END DO

       END DO

    END DO

    ! Divide the figure-of-merit by the number of independent field combinations, redshifts and cosmologies
    ! This is then the rms error per log-k, per z, per cosmology per field
    !weight_sum=SUM(weight)/REAL(n*nz*triangle_number(nf))
    !fom=sqrt(fom/REAL(n*nz*triangle_number(nf)))/weight_sum
    
    !weight_sum=SUM(weight)/REAL(n*nz*nk*triangle_number(nf))
    !fom=sqrt(fom/REAL(n*nz*nk*triangle_number(nf)))/weight_sum

    ! Calculate the final figure-of-merit by dividing by the effective number of data points and sqrt
    fom=sqrt(fom/neff)

  END SUBROUTINE fom_multiple

  SUBROUTINE set_parameter_ranges(im,delta,fields,nf,sigma,p_set,p,p_log,p_nme,np,k,nk,z,nz,pow_sim,weight,hmod,cosm,n,verbose)

    IMPLICIT NONE
    INTEGER, INTENT(IN) :: im
    REAL, INTENT(IN) :: delta
    INTEGER, INTENT(IN) :: fields(nf)
    INTEGER, INTENT(IN) :: nf
    REAL, INTENT(INOUT) :: sigma(np)
    LOGICAL, INTENT(IN) :: p_set(np)
    REAL, INTENT(IN) :: p(np)
    LOGICAL, INTENT(IN) :: p_log(np)
    CHARACTER(len=*), INTENT(IN) :: p_nme(np)
    INTEGER, INTENT(IN) :: np
    REAL, INTENT(IN) :: k(nk,nz,n)
    INTEGER, INTENT(IN) :: nk
    REAL, INTENT(IN) :: z(nz)
    INTEGER, INTENT(IN) :: nz
    REAL, INTENT(IN) :: pow_sim(n,nf,nf,nk,nz)
    REAL, INTENT(IN) :: weight(n,nf,nf,nz)
    TYPE(halomod), INTENT(INOUT) :: hmod(n)
    TYPE(cosmology), INTENT(INOUT) :: cosm(n)
    INTEGER, INTENT(IN) :: n
    LOGICAL, INTENT(IN) :: verbose
    INTEGER :: i
    REAL :: fom_base, fom_diff, fom, df, p2(np), pow(n,nf,nf,nk,nz), dp
    
    REAL, PARAMETER :: eps=2.0    ! Tolerated error in fom difference when setting range
    REAL, PARAMETER :: deriv=1e-3 ! How much smaller is the derivative than delta
    !INTEGER, PARAMETER :: nout=25 ! For output debugging

    ! Get the figure of merit for the base set of parameters
    CALL fom_multiple(im,fields,nf,fom_base,p,p_log,np,k,nk,z,nz,pow,pow_sim,weight,hmod,cosm,n)

    dp=deriv*delta

    ! Initial parameter perturbation
    DO i=1,np
       IF(p_set(i)) THEN
          IF(p(i) .NE. 0.) THEN
             sigma(i)=p(i)*dp
          ELSE
             sigma(i)=dp
          END IF
       END IF
    END DO

    ! Write to screen
    IF(verbose) THEN
       WRITE(*,*) 'SET_PARAMETER_RANGES: Setting parameter step sizes'
       WRITE(*,*) 'SET_PARAMETER_RANGES: Number of parameters:', np
       WRITE(*,*) 'SET_PARAMETER_RANGES: Number of cosmologies:', n
       WRITE(*,*) 'SET_PARAMETER_RANGES: Number of fields:', nf
       WRITE(*,*) 'SET_PARAMETER_RANGES: Number of wavenumbers:', nk
       WRITE(*,*) 'SET_PARAMETER_RANGES: Number of redshifts:', nz
       WRITE(*,*) 'SET_PARAMETER_RANGES: Derivatives being calculated with:', dp
       WRITE(*,*) 'SET_PARAMETER_RANGES: Fixing sigma to give change in fom:', delta
       WRITE(*,*) 'SET_PARAMETER_RANGES: Baseline fom:', fom_base
       WRITE(*,*) '====================================================================================='
       WRITE(*,*) 'Parameter           Name         Base value     New Value         Sigma         Ratio'
       WRITE(*,*) '====================================================================================='
    END IF

    ! Loop over parameters
    DO i=1,np 

       ! Set the range of p to take the derivative over
       p2=p ! Reset all
       p2(i)=p(i)+sigma(i) ! Perturb parameter i

       ! Get the figure of merit for the updated parameter
       CALL fom_multiple(im,fields,nf,fom,p2,p_log,np,k,nk,z,nz,pow,pow_sim,weight,hmod,cosm,n)

       ! Calculate the change in the figure of merit for this parameter
       df=fom-fom_base

       ! Check that perturbing the parameter actually changes the figure of merit
       IF(df==0.) THEN
          WRITE(*,*) 'SET_PARAMETER_RANGES: Parameter:', i
          WRITE(*,*) 'SET_PARAMETER_RANGES: sigma:', sigma(i)
          IF(p_log(i)) THEN
             WRITE(*,*) 'SET_PARAMETER_RANGES: Original value:', 10**p(i)
             WRITE(*,*) 'SET_PARAMETER_RANGES: Perturbed value:', 10**p2(i)
          ELSE
             WRITE(*,*) 'SET_PARAMETER_RANGES: Original value:', p(i)
             WRITE(*,*) 'SET_PARAMETER_RANGES: Perturbed value:', p2(i)
          END IF
          WRITE(*,*) 'SET_PARAMETER_RANGES: Original figure-of-merit:', fom_base
          WRITE(*,*) 'SET_PARAMETER_RANGES: Perturbed figure-of-merit:', fom
          WRITE(*,*) 'SET_PARAMETER_RANGES: Change in figure-of-merit:', df
          STOP 'SET_PARAMETER_RANGES: Error, changing parameter does not change power spectra'
       END IF

       IF(p_set(i)) THEN

          ! Set sigma so that it gives a change of 'delta' in fom
          sigma(i)=ABS(sigma(i)/df)*delta
          p2(i)=p(i)+sigma(i)

       END IF

       ! Write parameters to screen
       IF(verbose) THEN
          IF(p_log(i)) WRITE(*,fmt='(I10,A15,A5,4F14.7)') i, TRIM(p_nme(i)), 'lin', 10**p(i), 10**p2(i), sigma(i), sigma(i)/ABS(p(i))
          WRITE(*,fmt='(I10,A15,A5,4F14.7)') i, TRIM(p_nme(i)), 'log', p(i), p2(i), sigma(i), sigma(i)/ABS(p(i))
       END IF

    END DO

    ! Write to screen
    IF(verbose) THEN
       WRITE(*,*) '====================================================================================='
       WRITE(*,*) 'SET_PARAMETER_RANGES: Done initial setting'
       WRITE(*,*)
    END IF

    ! Write to screen
    IF(verbose) THEN
       WRITE(*,*) '======================================================================'
       WRITE(*,*) '    Parameter           Name      fom_base           fom         ratio'
       WRITE(*,*) '======================================================================'
    END IF

    DO i=1,np

       DO

          p2=p
          p2(i)=p(i)+sigma(i)
          CALL fom_multiple(im,fields,nf,fom,p2,p_log,np,k,nk,z,nz,pow,pow_sim,weight,hmod,cosm,n)
          fom_diff=fom-fom_base
          WRITE(*,fmt='(I14,A15,3F14.7)') i, TRIM(p_nme(i)), fom_base, fom, fom_diff/delta

          IF(p_set(i)) THEN
          
             IF(ABS(fom_diff) > delta*eps) THEN
                sigma(i)=sigma(i)/(fom_diff/delta)
             ELSE IF(ABS(fom_diff) < delta/eps) THEN
                sigma(i)=sigma(i)/(fom_diff/delta)
             ELSE
                EXIT
             END IF

          ELSE

             EXIT

          END IF

       END DO

!!$       IF(ABS(fom_diff) > delta*eps .OR. ABS(fom_diff) < delta/eps) THEN
!!$          OPEN(7,file='fitting/debug.dat')
!!$          DO j=1,nout
!!$             p2(i)=p(i)+sigma(i)*(j-1)/(nout-1)
!!$             CALL fom_multiple(im,fields,nf,fom,p2,p_log,np,k,nk,z,nz,pow,pow_sim,weight,hmod,cosm,n)
!!$             WRITE(*,*) p2(i), fom
!!$             WRITE(7,*) p2(i), fom
!!$          END DO
!!$          CLOSE(7)
!!$          STOP 'SET_PARAMETER_RANGES: Error, change in parameter causes too small or too large a FOM change'
!!$       END IF

    END DO

    ! Write to screen
    IF(verbose) THEN
       WRITE(*,*) '======================================================================'
       WRITE(*,*) 'Done check'
       WRITE(*,*)
    END IF

  END SUBROUTINE set_parameter_ranges

  SUBROUTINE read_simulation_power_spectrum(k,Pk,n,infile,kmin,kmax,cut_nyquist,subtract_shot,verbose)

    IMPLICIT NONE
    REAL, ALLOCATABLE, INTENT(OUT) :: k(:), Pk(:) ! Output simulation k and power
    INTEGER, INTENT(OUT) :: n ! Number of output k values
    CHARACTER(len=*), INTENT(IN) :: infile ! Input file location
    REAL, OPTIONAL, INTENT(IN) :: kmin, kmax ! Minimum and maximum k values to cut at
    LOGICAL, OPTIONAL, INTENT(IN) :: cut_nyquist ! Logical to cut Nyquist or not
    LOGICAL, OPTIONAL, INTENT(IN) :: subtract_shot ! Logical to subtract shot noise or not
    LOGICAL, OPTIONAL, INTENT(IN) :: verbose ! Logical verbose
    INTEGER :: i, i1, i2, m
    REAL :: shot, kbig
    LOGICAL :: lexist

    ! Deallocate arrays if they are already allocated
    IF(ALLOCATED(k))  DEALLOCATE(k)
    IF(ALLOCATED(Pk)) DEALLOCATE(Pk)

    ! Check file exists
    INQUIRE(file=infile,exist=lexist)
    IF(.NOT. lexist) THEN
       WRITE(*,*) 'READ_SIMULATION_POWER_SPECTRUM: File: ', TRIM(infile)
       STOP 'READ_SIMULATION_POWER_SPECTRUM: File does not exist'
    END IF

    ! Get file length and allocate arrays for output
    n=file_length(infile,verbose=.FALSE.)
    ALLOCATE(k(n),Pk(n))

    ! Write to screen
    IF(PRESENT(verbose)) THEN
       IF(verbose) THEN
          WRITE(*,*) 'READ_SIMULATION_POWER_SPECTRUM: Reading in data'
          WRITE(*,*) 'READ_SIMULATION_POWER_SPECTRUM: File: ', TRIM(infile)
          WRITE(*,*) 'READ_SIMULATION_POWER_SPECTRUM: nk:', nk
       END IF
    END IF

    ! Read in data from file
    OPEN(7,file=infile,status='old')
    DO i=1,n
       READ(7,*) k(i), Pk(i), shot
       IF(PRESENT(subtract_shot)) THEN
          IF(subtract_shot) Pk(i)=Pk(i)-shot
       END IF
    END DO
    CLOSE(7)

    IF(PRESENT(cut_nyquist)) THEN
       IF(cut_nyquist) THEN

          ! Find position in array of half-Nyquist
          kbig=k(n)
          DO i=1,n
             IF(k(i)>kbig/2.) EXIT
          END DO

          ! Cut arrays down to half-Nyquist
          CALL amputate(k,n,i)
          CALL amputate(Pk,n,i)
          n=i

          ! Write to screen
          IF(PRESENT(verbose)) THEN
             IF(verbose) THEN
                WRITE(*,*) 'READ_SIMULATION_POWER_SPECTRUM: Trimmed to Nyquist frequency'
             END IF
          END IF

       END IF
    END IF

    IF(PRESENT(kmin) .AND. PRESENT(kmax)) THEN

       i1=0
       i2=0
       DO i=1,n-1
          IF(k(i)<kmin .AND. k(i+1)>kmin) THEN
             i1=i
          END IF
          IF(k(i)<kmax .AND. k(i+1)>kmax) THEN
             i2=i+1
          END IF
       END DO

       IF(i1==0 .OR. i2==0) THEN
          STOP 'READ_SIMULATION_POWER_SPECTRUM: Error, something went wrong with kmin, kmax'
       END IF

       CALL amputate_general(k,n,m,i1,i2)
       CALL amputate_general(Pk,n,m,i1,i2)
       n=m

    END IF

    ! Write to screen
    IF(PRESENT(verbose)) THEN
       IF(verbose) THEN
          WRITE(*,*) 'READ_SIMULATION_POWER_SPECTRUM: Done'
          WRITE(*,*)
       END IF
    END IF

  END SUBROUTINE read_simulation_power_spectrum

  CHARACTER(len=256) FUNCTION BAHAMAS_power_file_name(model,z,ip)

    IMPLICIT NONE
    CHARACTER(len=*), INTENT(IN) :: model
    REAL, INTENT(IN) :: z
    INTEGER, INTENT(IN) :: ip(2)
    CHARACTER(len=64) :: dir
    CHARACTER(len=32) :: snap, field(2), f1, f2
    LOGICAL :: lexist
    INTEGER :: j

    ! Directory containing everything
    IF(computer==1) dir='/Users/Mead/Physics/BAHAMAS/power/M1536'
    IF(computer==2) dir='/home/amead/BAHAMAS/power/M1536'

    ! Set the redshift
    IF(z==0.0) THEN
       snap='snap32'
    ELSE IF(z==0.5) THEN
       snap='snap28'
    ELSE IF(z==1.0) THEN
       snap='snap26'
    ELSE IF(z==2.0) THEN
       snap='snap22'
    ELSE
       STOP 'BAHAMAS_POWER_FILE_NAME: Error, redshift specified incorrectly'
    END IF

    ! Set the fields
    DO j=1,2
       IF(ip(j)==field_matter) THEN
          field(j)='all'
       ELSE IF(ip(j)==field_cdm) THEN
          field(j)='dm'
       ELSE IF(ip(j)==field_gas) THEN
          field(j)='gas'
       ELSE IF(ip(j)==field_star) THEN
          field(j)='stars'
       ELSE IF(ip(j)==field_electron_pressure) THEN
          field(j)='epressure'
       ELSE
          WRITE(*,*) 'BAHAMAS_POWER_FILE_NAME: Field number', j
          WRITE(*,*) 'BAHAMAS_POWER_FILE_NAME: Halo type', ip(j)
          STOP 'BAHAMAS_POWER_FILE_NAME: Error, ip specified incorrectly'
       END IF
    END DO

    DO j=1,2

       IF(j==1) THEN
          f1=field(1)
          f2=field(2)
       ELSE IF(j==2) THEN
          f1=field(2)
          f2=field(1)
       ELSE
          STOP 'BAHAMAS_POWER_FILE_NAME: Error, something fucked up'
       END IF

       ! File name
       BAHAMAS_power_file_name=TRIM(dir)//'/'//TRIM(model)//'_L400N1024_WMAP9_'//TRIM(snap)//'_'//TRIM(f1)//'_'//TRIM(f2)//'_power.dat'

       ! Check it exists
       INQUIRE(file=BAHAMAS_power_file_name,exist=lexist)

       IF(lexist) THEN
          EXIT
       ELSE IF(j==2) THEN
          WRITE(*,*) 'BAHAMAS_POWER_FILE_NAME: ', TRIM(BAHAMAS_power_file_name)
          STOP 'BAHAMAS_POWER_FILE_NAME: Error, file does not exist'
       END IF

    END DO

  END FUNCTION BAHAMAS_power_file_name

  SUBROUTINE read_BAHAMAS_power(k,Pk,nk,z,name,field,cosm,kmin,kmax)

    IMPLICIT NONE
    REAL, ALLOCATABLE, INTENT(OUT) :: k(:)
    REAL, ALLOCATABLE, INTENT(OUT) :: Pk(:)
    INTEGER, INTENT(OUT) :: nk
    REAL, INTENT(IN) :: z
    CHARACTER(len=*), INTENT(IN) :: name
    INTEGER, INTENT(IN) :: field(2)
    TYPE(cosmology), INTENT(INOUT) :: cosm
    REAL, OPTIONAL, INTENT(IN) :: kmin, kmax
    REAL, ALLOCATABLE :: Pk_DM(:), Pk_HMcode(:)
    CHARACTER(len=256) :: infile, dmonly

    INTEGER, PARAMETER :: field_all_matter(2)=field_matter
    REAL, PARAMETER :: mmin=1e7
    REAL, PARAMETER :: mmax=1e17
    LOGICAL, PARAMETER :: cut_nyquist=.FALSE.
    LOGICAL, PARAMETER :: subtract_shot=.TRUE.
    LOGICAL, PARAMETER :: verbose=.TRUE.

    dmonly=BAHAMAS_power_file_name('DMONLY_2fluid_nu0',z,field_all_matter)
    infile=BAHAMAS_power_file_name(name,z,field)

    CALL read_simulation_power_spectrum(k,Pk_DM,nk,dmonly,kmin,kmax,cut_nyquist,subtract_shot,verbose)
    CALL read_simulation_power_spectrum(k,Pk,   nk,infile,kmin,kmax,cut_nyquist,subtract_shot,verbose)
    Pk=Pk/Pk_DM

    ALLOCATE(Pk_HMcode(nk))
    CALL calculate_HMcode_a(k,scale_factor_z(z),Pk_HMcode,nk,cosm)
    Pk=Pk*Pk_HMcode

  END SUBROUTINE read_BAHAMAS_power

  SUBROUTINE write_fitting_power(base,k,pow_hm,pow_si,ncos,nf,nk,na)

    ! Write fitting data to disk
    IMPLICIT NONE
    CHARACTER(len=*), INTENT(IN) :: base
    REAL, INTENT(IN) :: k(ncos,nk,na)
    REAL, INTENT(IN) :: pow_hm(ncos,nf,nf,nk,na)
    REAL, INTENT(IN) :: pow_si(ncos,nf,nf,nk,na)
    INTEGER, INTENT(IN) :: ncos
    INTEGER, INTENT(IN) :: nf
    INTEGER, INTENT(IN) :: nk
    INTEGER, INTENT(IN) :: na
    CHARACTER(len=256) :: outfile, outbit
    CHARACTER(len=10) :: uscore, nothing, mid, ext
    INTEGER :: icos, ia, i1, i2, ik

    ! Bits for file name
    uscore='_'
    nothing=''
    mid='_z'
    ext='.dat'

    ! Loop over everything
    DO icos=1,ncos
       DO ia=1,na
          DO i1=1,nf
             DO i2=i1,nf
                outbit=number_file(base,icos,uscore)
                outbit=number_file2(outbit,i1,nothing,i2,mid)
                outfile=number_file(outbit,ia,ext)
                WRITE(*,*) 'WRITE_FITTING_POWER: Outfile: ', TRIM(outfile)
                OPEN(7,file=outfile)
                DO ik=1,nk
                   WRITE(7,*) k(icos,ik,ia), pow_hm(icos,i1,i2,ik,ia), pow_si(icos,i1,i2,ik,ia)
                END DO
                CLOSE(7)
                WRITE(*,*) 'WRITE_FITTING_POWER: Done'
                WRITE(*,*)
             END DO
          END DO
       END DO
    END DO

  END SUBROUTINE write_fitting_power

END PROGRAM HMx_fitting
