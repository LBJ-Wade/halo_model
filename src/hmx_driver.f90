PROGRAM HMx_driver

  USE HMx
  USE cosdef
  IMPLICIT NONE

  CALL init_HMx()

  CALL get_command_argument(1,mode)
  IF(mode=='') THEN
     imode=-1
  ELSE
     READ(mode,*) imode
  END IF

  !HMx developed by Alexander Mead
  WRITE(*,*)
  WRITE(*,*) 'HMx: Welcome to HMx'
  IF(imead==-1) THEN
     WRITE(*,*) 'HMx: Doing basic halo-model calculation (Two-halo term is linear)'
  ELSE IF(imead==0) THEN
     WRITE(*,*) 'HMx: Doing standard halo-model calculation (Seljak 2000)'
  ELSE IF(imead==1) THEN
     WRITE(*,*) 'HMx: Doing accurate halo-model calculation (Mead et al. 2015)'
  ELSE
     STOP 'HMx: imead specified incorrectly'
  END IF
  WRITE(*,*)

  IF(imode==-1) THEN
     WRITE(*,*) 'HMx: Choose what to do'
     WRITE(*,*) '======================'
     WRITE(*,*) ' 0 - Matter power spectrum at z = 0'
     WRITE(*,*) ' 1 - Matter power spectrum over multiple z'
     WRITE(*,*) ' 2 - Comparison with cosmo-OWLS'
     WRITE(*,*) ' 3 - Run diagnostics'
     WRITE(*,*) ' 4 - Do random cosmologies for bug testing'
     WRITE(*,*) ' 5 - Pressure field comparison'
     WRITE(*,*) ' 6 - n(z) check'
     WRITE(*,*) ' 7 - Do cross correlation'
     WRITE(*,*) ' 8 - Cross correlation as a function of cosmology'
     WRITE(*,*) ' 9 - Breakdown correlations in halo mass'
     WRITE(*,*) '10 - Breakdown correlations in redshift'
     WRITE(*,*) '11 - Breakdown correlations in halo radius'
     WRITE(*,*) '12 - Project triad'
     WRITE(*,*) '13 - Cross-correlation coefficient'
     WRITE(*,*) '14 - 3D spectra as HMx parameters vary'
     WRITE(*,*) '15 - Do all cosmo-OWLS models'
     READ(*,*) imode
     WRITE(*,*) '======================'
     WRITE(*,*)
  END IF

  IF(imode==0) THEN

     !Set number of k points and k range (log spaced)
     nk=200
     kmin=1e-3
     kmax=1e2
     CALL fill_array(log(kmin),log(kmax),k,nk)
     k=exp(k)
     ALLOCATE(pow_lin(nk),pow_2h(nk),pow_1h(nk),pow_full(nk))

     !Assigns the cosmological model
     icosmo=0
     CALL assign_cosmology(icosmo,cosm)

     !Normalises power spectrum (via sigma_8) and fills sigma(R) look-up tables
     CALL initialise_cosmology(cosm)
     CALL print_cosmology(cosm)

     !Sets the redshift
     z=0.

     !Initiliasation for the halomodel calcualtion
     CALL halomod_init(mmin,mmax,z,lut,cosm)

     !Do the halo-model calculation
     CALL calculate_halomod(-1,-1,k,nk,z,pow_lin,pow_2h,pow_1h,pow_full,lut,cosm)

     !na=1
     !ALLOCATE(a(na))
     !a=scale_factor_z(z)
     !a=1.

     !ip=-1
     !CALL calculate_halomod(ip,k,nk,a,na,powa_lin,powa_2h,powa_1h,powa_full,cosm)

     !Write out the answer
     outfile='data/power.dat'
     !CALL write_power(k,powa_lin(:,1),powa_2h(:,1),powa_1h(:,1),powa_full(:,1),nk,outfile)
     CALL write_power(k,pow_lin,pow_2h,pow_1h,pow_full,nk,outfile)

     !Write the one-void term if necessary
     IF(void) THEN
        OPEN(8,file='data/power_1void.dat')
        DO i=1,nk     
           WRITE(8,*) k(i), p_1v(k(i),lut)!,cosm)
        END DO
        CLOSE(8)
     END IF

  ELSE IF(imode==1) THEN

     !Assigns the cosmological model
     icosmo=0
     CALL assign_cosmology(icosmo,cosm)

     !Normalises power spectrum (via sigma_8) and fills sigma(R) look-up tables
     CALL initialise_cosmology(cosm)
     CALL print_cosmology(cosm)

     !Set number of k points and k range (log spaced)
     nk=200
     kmin=1e-3
     kmax=1e2
     CALL fill_array(log(kmin),log(kmax),k,nk)
     k=exp(k)

     !Set the number of redshifts and range (linearly spaced) and convert z -> a
     nz=16
     zmin=0.
     zmax=4.
     CALL fill_array(zmin,zmax,a,nz)
     a=1./(1.+a)
     na=nz

     !Instead could set an a-range
     !amin=scale_factor(cosm%z_cmb)
     !amax=1.
     !na=16
     !CALL fill_array(amin,amax,a,na)

     !Allocate power arrays
     !ALLOCATE(powa_lin(nk,na),powa_2h(nk,na),powa_1h(nk,na),powa_full(nk,na))

     !Do the halo-model calculation
     !WRITE(*,*) 'HMx: Doing calculation'
     !DO j=na,1,-1
     !   z=redshift_a(a(j))
     !   CALL halomod_init(mmin,mmax,z,lut,cosm)
     !   WRITE(*,fmt='(A5,I5,F10.2)') 'HMx:', j, REAL(z)
     !   CALL calculate_halomod(-1,-1,k,nk,z,powa_lin(:,j),powa_2h(:,j),powa_1h(:,j),powa_full(:,j),lut,cosm)
     !END DO
     !WRITE(*,*)

     ip=-1
     CALL calculate_HMx(ip,k,nk,a,na,powa_lin,powa_2h,powa_1h,powa_full,cosm)

     base='data/power'
     CALL write_power_a_multiple(k,a,powa_lin,powa_2h,powa_1h,powa_full,nk,na,base,.TRUE.)

  ELSE IF(imode==2 .OR. imode==15) THEN

     !Compare to cosmo-OWLS models
     
     !Set number of k points and k range (log spaced)
     nk=200
     kmin=1e-3
     kmax=1e2
     CALL fill_array(log(kmin),log(kmax),k,nk)
     k=exp(k)
     ALLOCATE(pow_lin(nk),pow_2h(nk),pow_1h(nk),pow_full(nk))

     !Set the redshift
     z=0.

     !Assigns the cosmological model
     icosmo=1
     CALL assign_cosmology(icosmo,cosm)
        
     IF(imode==2) nowl=1
     IF(imode==15) nowl=6

     DO iowl=1,nowl

        IF(iowl==1) THEN
           name='DMONLY'
           fname=name
        ELSE IF(iowl==2) THEN
           name='REF'
           fname=name
           cosm%param(1)=2.
           cosm%param(2)=1.4
           cosm%param(3)=1.24
           cosm%param(4)=1e13
           cosm%param(5)=0.055
        ELSE IF(iowl==3) THEN
           name='NOCOOL'
           fname=name
           cosm%param(1)=2.
           cosm%param(2)=0.8
           cosm%param(3)=1.1
           cosm%param(4)=0.
           cosm%param(5)=0.
        ELSE IF(iowl==4) THEN
           name='AGN'
           fname=name
           cosm%param(1)=2.
           cosm%param(2)=0.5
           cosm%param(3)=1.18
           cosm%param(4)=8e13
           cosm%param(5)=0.0225
        ELSE IF(iowl==5) THEN
           name='AGN 8.5'
           fname='AGN8p5'
           cosm%param(1)=2.
           cosm%param(2)=-0.5
           cosm%param(3)=1.26
           cosm%param(4)=2d14
           cosm%param(5)=0.0175
        ELSE IF(iowl==6) THEN
           name='AGN 8.7'
           fname='AGN8p7'
           cosm%param(1)=2.
           cosm%param(2)=-2.
           cosm%param(3)=1.3
           cosm%param(4)=1e15
           cosm%param(5)=0.015
        END IF

        IF(iowl .NE. 0) WRITE(*,*) 'Comparing to OWLS model: ', TRIM(name)
        CALL print_baryon_parameters(cosm)

        !Normalises power spectrum (via sigma_8) and fills sigma(R) look-up tables
        CALL initialise_cosmology(cosm)
        CALL print_cosmology(cosm)

        !Initiliasation for the halomodel calcualtion
        CALL halomod_init(mmin,mmax,z,lut,cosm)

        !Runs the diagnostics
        dir='diagnostics'
        CALL halo_diagnostics(z,lut,cosm,dir)
        CALL halo_definitions(lut,dir)

        IF(imode==2) THEN
           !File base and extension
           base='cosmo-OWLS/data/power_'
           mid=''
           ext='.dat'
        ELSE IF(imode==15) THEN
           base='cosmo-OWLS/data/power_'//TRIM(fname)//'_'
           mid=''
           ext='.dat'
        END IF

        !Dark-matter only
        outfile='cosmo-OWLS/data/DMONLY.dat'
        WRITE(*,*) -1, -1, TRIM(outfile)
        CALL calculate_halomod(-1,-1,k,nk,z,pow_lin,pow_2h,pow_1h,pow_full,lut,cosm)
        CALL write_power(k,pow_lin,pow_2h,pow_1h,pow_full,nk,outfile)

        !ip=-1
        !CALL calculate_halomod(ip,k,nk,a,na,powa_lin,powa_2h,powa_1h,powa_full,cosm)
        !outfile='cosmo-OWLS/data/DMONLY.dat'
        !CALL write_power(k,powa_lin(:,1),powa_2h(:,1),powa_1h(:,1),powa_full(:,1),nk,outfile)

        !Loop over matter types and do auto and cross-spectra
        DO j1=0,6
           DO j2=j1,6

              !Fix output file and write to screen
              outfile=number_file2(base,j1,mid,j2,ext)
              WRITE(*,*) j1, j2, TRIM(outfile)

              CALL calculate_halomod(j1,j2,k,nk,z,pow_lin,pow_2h,pow_1h,pow_full,lut,cosm)
              CALL write_power(k,pow_lin,pow_2h,pow_1h,pow_full,nk,outfile)

           END DO
        END DO

     END DO

  ELSE IF(imode==3) THEN

     !Assigns the cosmological model
     icosmo=0
     CALL assign_cosmology(icosmo,cosm)

     !Normalises power spectrum (via sigma_8) and fills sigma(R) look-up tables
     CALL initialise_cosmology(cosm)
     CALL print_cosmology(cosm)

     !WRITE(*,*) 'Redshift:'
     !READ(*,*) z
     !WRITE(*,*)
     z=0.

     !Initiliasation for the halomodel calcualtion
     CALL halomod_init(mmin,mmax,z,lut,cosm)

     !Runs the diagnostics
     dir='diagnostics'
     CALL halo_diagnostics(z,lut,cosm,dir)
     CALL halo_definitions(lut,dir)

     !output='winint/integrand.dat'
     !irho=14
     !rv=1.
     !rs=0.25
     !rmax=rv
     !CALL winint_diagnostics(rmax,rv,rs,irho,output)

  ELSE IF(imode==4) THEN

     STOP 'Error, random mode not implemented yet'

     !Ignore this, only useful for bug tests
     CALL RNG_set(0)

     !Only not uncommented to suppress compile-time warnings
     DO
        CALL random_cosmology(cosm)   
     END DO
     !Ignore this, only useful for bug tests

  ELSE IF(imode==5) THEN

     !Compare to cosmo-OWLS models for pressure

     !Set number of k points and k range (log spaced)
     nk=200
     kmin=1.e-3
     kmax=1.e2
     CALL fill_array(log(kmin),log(kmax),k,nk)
     k=exp(k)
     ALLOCATE(pow_lin(nk),pow_2h(nk),pow_1h(nk),pow_full(nk))

     !Set the redshift
     z=0.

     !Assigns the cosmological model
     icosmo=1
     CALL assign_cosmology(icosmo,cosm)

     !Normalises power spectrum (via sigma_8) and fills sigma(R) look-up tables
     CALL initialise_cosmology(cosm)
     CALL print_cosmology(cosm)

     !Initiliasation for the halomodel calcualtion
     CALL halomod_init(mmin,mmax,z,lut,cosm)

     !Runs the diagnostics
     dir='diagnostics'
     CALL halo_diagnostics(z,lut,cosm,dir)
     CALL halo_definitions(lut,dir)

     !File base and extension
     base='pressure/power_'
     ext='.dat'

     !Number of different spectra
     n=3

     !Do the calculation
     DO j=0,n

        IF(j==0) THEN
           !DMONLY
           j1=-1
           j2=-1
           outfile='pressure/DMONLY.dat'
        ELSE IF(j==1) THEN
           !Matter x matter
           j1=0
           j2=0
           outfile='dd'
        ELSE IF(j==2) THEN
           !Matter x pressure
           j1=0
           j2=6
           outfile='dp'
        ELSE IF(j==3) THEN
           !Pressure x pressure
           j1=6
           j2=6
           outfile='pp'
        END IF

        IF(j .NE. 0) outfile=TRIM(base)//TRIM(outfile)//TRIM(ext)

        WRITE(*,fmt='(3I5,A30)') j, j1, j2, TRIM(outfile)

        CALL calculate_halomod(j1,j2,k,nk,z,pow_lin,pow_2h,pow_1h,pow_full,lut,cosm)
        CALL write_power(k,pow_lin,pow_2h,pow_1h,pow_full,nk,outfile)

     END DO

  ELSE IF(imode==6) THEN

     !n(z) normalisation check

     WRITE(*,*) 'HMx: Checking n(z) functions'

     !inz(1)=-1
     !inz(2)=0

     nnz=7
     DO i=1,nnz
        IF(i==1) nz=1
        IF(i==2) nz=4
        IF(i==3) nz=5
        IF(i==4) nz=6
        IF(i==5) nz=7
        IF(i==6) nz=8
        IF(i==7) nz=9
        WRITE(*,*) 'HMx: n(z) number:', nz
        CALL get_nz(nz,lens)
        WRITE(*,*) 'HMx: n(z) integral (linear):', integrate_table(lens%z_nz,lens%nz,lens%nnz,1,lens%nnz,1)
        WRITE(*,*) 'HMx: n(z) integral (quadratic):', integrate_table(lens%z_nz,lens%nz,lens%nnz,1,lens%nnz,2)
        WRITE(*,*) 'HMx: n(z) integral (cubic):', integrate_table(lens%z_nz,lens%nz,lens%nnz,2,lens%nnz,3)
        WRITE(*,*)
     END DO

  ELSE IF(imode==7 .OR. imode==8 .OR. imode==9 .OR. imode==10 .OR. imode==11) THEN

     !General stuff for all cross correlations

     !Set the fields
     ix=-1
     CALL set_ix(ix,ip)

     !Assign the cosmological model
     icosmo=-1
     CALL assign_cosmology(icosmo,cosm)

     !Set the k range
     kmin=1e-3
     kmax=1e2
     nk=200

     !Set the z range
     !amin=scale_factor_z(cosm%z_cmb) !Problems with one-halo term if amin is less than 0.1
     amin=0.1
     amax=1.
     na=16

     !Set number of k points and k range (log spaced)
     !Also z points and z range (linear)
     !Also P(k,z)
     CALL fill_array(log(kmin),log(kmax),k,nk)
     k=exp(k)
     CALL fill_array(amin,amax,a,na)
     ALLOCATE(powa_lin(nk,na),powa_1h(nk,na),powa_2h(nk,na),powa_full(nk,na),powa(nk,na))

     !Set the ell range
     lmin=1
     lmax=1e5
     nl=128

     !Allocate arrays for l and C(l)
     CALL fill_array(log(lmin),log(lmax),ell,nl)
     ell=exp(ell)
     ALLOCATE(Cell(nl))

     !Set the angular arrays in degrees
     thmin=0.01
     thmax=10.
     nth=128

     !Allocate arrays for theta and xi(theta)
     CALL fill_array(log(thmin),log(thmax),theta,nth)
     theta=exp(theta)
     ALLOCATE(xi(3,nth))

     WRITE(*,*) 'HMx: Cross-correlation information'
     WRITE(*,*) 'HMx: output directiory: ', TRIM(dir)
     WRITE(*,*) 'HMx: Profile type 1: ', TRIM(halo_type(ip(1)))
     WRITE(*,*) 'HMx: Profile type 2: ', TRIM(halo_type(ip(2)))
     WRITE(*,*) 'HMx: cross-correkation type 1: ', TRIM(xcorr_type(ix(1)))
     WRITE(*,*) 'HMx: cross-correlation type 2: ', TRIM(xcorr_type(ix(2)))
     WRITE(*,*) 'HMx: P(k) minimum k [h/Mpc]:', REAL(kmin)
     WRITE(*,*) 'HMx: P(k) maximum k [h/Mpc]:', REAL(kmax)
     WRITE(*,*) 'HMx: minimum a:', REAL(amin)
     WRITE(*,*) 'HMx: maximum a:', REAL(amax)
     WRITE(*,*) 'HMx: minimum ell:', REAL(lmin)
     WRITE(*,*) 'HMx: maximum ell:', REAL(lmax)
     WRITE(*,*)     

     IF(imode==7) THEN

        !Normalises power spectrum (via sigma_8) and fills sigma(R) look-up tables
        CALL initialise_cosmology(cosm)
        CALL print_cosmology(cosm)

        !Initialise the lensing part of the calculation
        CALL initialise_distances(cosm)
        CALL write_distances(cosm)

        !Write out diagnostics
        CALL halomod_init(mmin,mmax,z,lut,cosm)
        dir='diagnostics'
        CALL halo_diagnostics(z,lut,cosm,dir)
        CALL halo_definitions(lut,dir)

        CALL calculate_HMx(ip,k,nk,a,na,powa_lin,powa_2h,powa_1h,powa_full,cosm)

        !Loop over scale factors
        !DO j=na,1,-1
        !
        !   z=-1+1./a(j)
        !   
        !   !Initiliasation for the halomodel calcualtion
        !   CALL halomod_init(mmin,mmax,z,lut,cosm)
        !   CALL calculate_halomod(ip(1),ip(2),k,nk,z,powa_lin(:,j),powa_2h(:,j),powa_1h(:,j),powa_full(:,j),lut,cosm)
        !
        !   IF(z==0.) THEN
        !      dir='diagnostics'
        !      CALL halo_diagnostics(z,lut,cosm,dir)
        !      CALL halo_definitions(lut,dir)
        !   END IF

        !  !Write progress to screen
        !  IF(j==na) THEN
        !     WRITE(*,fmt='(A5,A7)') 'i', 'a'
        !     WRITE(*,fmt='(A13)') '   ============'
        !  END IF
        !  WRITE(*,fmt='(I5,F8.3)') j, a(j)

        !END DO
        !WRITE(*,fmt='(A13)') '   ============'
        !WRITE(*,*)

!!$        !Fix the one-halo term P(k) to be a constant
!!$        DO j=1,na
!!$           DO i=1,nk
!!$              !IF(j==1) WRITE(*,*) i, k(i), powz(3,i,j)
!!$              powa(3,i,j)=powa(3,1,j)*(k(i)/k(1))**3
!!$              !powz(3,i,j)=(k(i)/k(1))**3
!!$              !IF(j==1) WRITE(*,*) i, k(i), powz(3,i,j)
!!$           END DO
!!$        END DO

        !Output directory
        dir='data/'
        base=TRIM(dir)//'power'
        CALL write_power_a_multiple(k,a,powa_lin,powa_2h,powa_1h,powa_full,nk,na,base,.TRUE.)

        !Fill out the projection kernels
        CALL fill_projection_kernels(ix,proj,cosm)
        CALL write_projection_kernels(proj,cosm)
        !output='projection/kernel1.dat'
        !CALL write_projection_kernel(proj(1),cosm,output)
        !output='projection/kernel2.dat'
        !CALL write_projection_kernel(proj(2),cosm,output)

        !Set the distance range for the Limber integral
        r1=0. !100.
        r2=maxdist(proj)!proj%rs

        !Write to screen
        WRITE(*,*) 'HMx: Computing C(l)'
        WRITE(*,*) 'HMx: ell min:', REAL(ell(1))
        WRITE(*,*) 'HMx: ell max:', REAL(ell(nl))
        WRITE(*,*) 'HMx: number of ell:', nl
        WRITE(*,*) 'HMx: lower limit of Limber integral [Mpc/h]:', REAL(r1)
        WRITE(*,*) 'HMx: upper limit of Limber integral [Mpc/h]:', REAL(r2)
        WRITE(*,*)

        !Loop over all types of C(l) to create
        DO j=1,4

           IF(ifull .AND. (j .NE. 4)) CYCLE
           !IF(j==3) CYCLE !Skip the fucking one-halo term

           !Write information to screen
           IF(j==1) THEN
              WRITE(*,*) 'HMx: Doing linear'
              outfile=TRIM(dir)//'cl_linear.dat'
              powa=powa_lin
           ELSE IF(j==2) THEN
              WRITE(*,*) 'HMx: Doing 2-halo'
              outfile=TRIM(dir)//'cl_2halo.dat'
              powa=powa_2h
           ELSE IF(j==3) THEN
              WRITE(*,*) 'HMx: Doing 1-halo'
              outfile=TRIM(dir)//'cl_1halo.dat'
              powa=powa_1h
           ELSE IF(j==4) THEN
              WRITE(*,*) 'HMx: Doing full'
              outfile=TRIM(dir)//'cl_full.dat'
              powa=powa_full
           END IF

           WRITE(*,*) 'HMx: Output: ', TRIM(outfile)

           !Actually calculate the C(ell)
           CALL calculate_Cell(r1,r2,ell,Cell,nl,k,a,powa,nk,na,proj,cosm)
           CALL write_Cell(ell,Cell,nl,outfile)

           IF(j==4) CALL Cell_contribution(r1,r2,k,a,powa,nk,na,proj,cosm)

           IF(ixi) THEN

              !Set xi output files
              IF(j==1) outfile=TRIM(dir)//'xi_linear.dat'
              IF(j==2) outfile=TRIM(dir)//'xi_2halo.dat'
              IF(j==3) outfile=TRIM(dir)//'xi_1halo.dat'
              IF(j==4) outfile=TRIM(dir)//'xi_full.dat'
              WRITE(*,*) 'HMx: Output: ', TRIM(outfile)

              !Actually calculate the xi(theta)
              CALL calculate_xi(theta,xi,nth,ell,Cell,nl,NINT(lmax))
              CALL write_xi(theta,xi,nth,outfile)

           END IF

        END DO
        WRITE(*,*) 'HMx: Done'
        WRITE(*,*)

     ELSE IF(imode==8) THEN

        !Assess cross-correlation as a function of cosmology

        !Loop over cosmology
        sig8min=0.7
        sig8max=0.9
        ncos=5
        DO i=1,ncos

           !cosm%sig8=sig8min+(sig8max-sig8min)*float(i-1)/float(ncos-1)
           cosm%sig8=progression(sig8min,sig8max,i,ncos)

           !Normalises power spectrum (via sigma_8) and fills sigma(R) look-up tables
           CALL initialise_cosmology(cosm)
           CALL print_cosmology(cosm)
           CALL initialise_distances(cosm)
           !CALL write_distances(cosm)

           !Loop over redshifts
           !DO j=1,na
           !
           !   z=redshift_a(a(j))
           !   
           !   !Initiliasation for the halomodel calcualtion
           !   CALL halomod_init(mmin,mmax,z,lut,cosm)
           !   CALL calculate_halomod(ip(1),ip(2),k,nk,z,powa_lin(:,j),powa_2h(:,j),powa_1h(:,j),powa_full(:,j),lut,cosm)
           !   !Write progress to screen
           !   IF(j==1) THEN
           !      WRITE(*,fmt='(A5,A7)') 'i', 'a'
           !      WRITE(*,fmt='(A13)') '   ============'
           !   END IF
           !   WRITE(*,fmt='(I5,F8.3)') j, a(j)
           !
           !END DO
           !WRITE(*,fmt='(A13)') '   ============'
           !WRITE(*,*)

           CALL calculate_HMx(ip,k,nk,a,na,powa_lin,powa_2h,powa_1h,powa_full,cosm)

           !Fill out the projection kernels
           CALL fill_projection_kernels(ix,proj,cosm)
           CALL write_projection_kernels(proj,cosm)

           !Now do the C(l) calculations
           !Set l range, note that using Limber and flat-sky for sensible results lmin to ~10
           CALL fill_array(log(lmin),log(lmax),ell,nl)
           ell=exp(ell)
           IF(ALLOCATED(Cell)) DEALLOCATE(Cell)
           ALLOCATE(Cell(nl))

           !Write to screen
           WRITE(*,*) 'HMx: Computing C(l)'
           WRITE(*,*) 'HMx: ell min:', REAL(ell(1))
           WRITE(*,*) 'HMx: ell max:', REAL(ell(nl))
           WRITE(*,*) 'HMx: number of ell:', nl
           WRITE(*,*)

           !Loop over all types of C(l) to create  
           base=TRIM(dir)//'cosmology_'
           DO j=1,4
              IF(j==1) THEN
                 WRITE(*,*) 'HMx: Doing C(l) linear'
                 ext='_cl_linear.dat'
                 powa=powa_lin
              ELSE IF(j==2) THEN
                 WRITE(*,*) 'HMx: Doing C(l) 2-halo'
                 ext='_cl_2halo.dat'
                 powa=powa_2h
              ELSE IF(j==3) THEN
                 WRITE(*,*) 'HMx: Doing C(l) 1-halo'
                 ext='_cl_1halo.dat'
                 powa=powa_1h
              ELSE IF(j==4) THEN
                 WRITE(*,*) 'HMx: Doing C(l) full'
                 ext='_cl_full.dat'
                 powa=powa_full
              END IF
              outfile=number_file(base,i,ext)
              !Actually calculate the C(ell)
              CALL calculate_Cell(0.,maxdist(proj),ell,Cell,nl,k,a,powa,nk,na,proj,cosm)
              CALL write_Cell(ell,Cell,nl,outfile)
           END DO
           WRITE(*,*) 'HMx: Done'
           WRITE(*,*)

        END DO

     ELSE IF(imode==9) THEN

        !Break down cross-correlation in terms of mass

        !Normalises power spectrum (via sigma_8) and fills sigma(R) look-up tables
        CALL initialise_cosmology(cosm)
        CALL print_cosmology(cosm)

        !Initialise the lensing part of the calculation
        CALL initialise_distances(cosm)
        CALL write_distances(cosm)

        !Fill out the projection kernels
        CALL fill_projection_kernels(ix,proj,cosm)
        CALL write_projection_kernels(proj,cosm)

        DO i=0,6
           IF(icumulative==0) THEN
              !Set the mass intervals
              IF(i==0) THEN
                 m1=mmin
                 m2=mmax
              ELSE IF(i==1) THEN
                 m1=mmin
                 m2=1e11
              ELSE IF(i==2) THEN
                 m1=1e11
                 m2=1e12
              ELSE IF(i==3) THEN
                 m1=1e12
                 m2=1e13
              ELSE IF(i==4) THEN
                 m1=1e13
                 m2=1e14
              ELSE IF(i==5) THEN
                 m1=1e14
                 m2=1e15
              ELSE IF(i==6) THEN
                 m1=1e15
                 m2=1e16
              END IF
           ELSE IF(icumulative==1) THEN
              !Set the mass intervals
              IF(i==0) THEN
                 m1=mmin
                 m2=mmax
              ELSE IF(i==1) THEN
                 m1=mmin
                 m2=1e11
              ELSE IF(i==2) THEN
                 m1=mmin
                 m2=1e12
              ELSE IF(i==3) THEN
                 m1=mmin
                 m2=1e13
              ELSE IF(i==4) THEN
                 m1=mmin
                 m2=1e14
              ELSE IF(i==5) THEN
                 m1=mmin
                 m2=1e15
              ELSE IF(i==6) THEN
                 m1=mmin
                 m2=1e16
              END IF
           ELSE
              STOP 'HMx: Error, icumulative not set correctly.'
           END IF

           !Set the code to not 'correct' the two-halo power for missing
           !mass when doing the calcultion binned in halo mass
           IF(icumulative==0 .AND. i>1) ip2h=0
           !IF(icumulative==1 .AND. i>0) ip2h=0

           WRITE(*,fmt='(A16)') 'HMx: Mass range'
           WRITE(*,fmt='(A16,I5)') 'HMx: Iteration:', i
           WRITE(*,fmt='(A21,2ES15.7)') 'HMx: M_min [Msun/h]:', m1
           WRITE(*,fmt='(A21,2ES15.7)') 'HMx: M_max [Msun/h]:', m2
           WRITE(*,*)

           !Loop over redshifts
           DO j=1,na

              z=redshift_a(a(j))

              !Initiliasation for the halomodel calcualtion
              CALL halomod_init(m1,m2,z,lut,cosm)
              CALL calculate_halomod(ip(1),ip(2),k,nk,z,powa_lin(:,j),powa_2h(:,j),powa_1h(:,j),powa_full(:,j),lut,cosm)

              !Write progress to screen
              IF(j==1) THEN
                 WRITE(*,fmt='(A5,A7)') 'i', 'a'
                 WRITE(*,fmt='(A13)') '   ============'
              END IF
              WRITE(*,fmt='(I5,F8.3)') j, a(j)

           END DO
           WRITE(*,fmt='(A13)') '   ============'
           WRITE(*,*)

           IF(i==0) THEN
              outfile=TRIM(dir)//'power'
           ELSE
              base=TRIM(dir)//'mass_'
              mid='_'
              ext='_power'
              outfile=number_file2(base,NINT(log10(m1)),mid,NINT(log10(m2)),ext)
           END IF
           WRITE(*,*) 'HMx: File: ', TRIM(outfile)
           !CALL write_power_a(k,a,powa,nk,na,output)

           !Loop over all types of C(l) to create
           base=TRIM(dir)//'mass_'
           mid='_' 
           DO j=1,4

              !Skip the 1-halo C(l) because it takes ages (2017/02/06)
              IF(j==3) CYCLE

              !Set output files
              IF(j==1) THEN
                 powa=powa_lin
                 outfile=TRIM(dir)//'cl_linear.dat'
                 ext='_cl_linear.dat'
              ELSE IF(j==2) THEN
                 powa=powa_2h
                 outfile=TRIM(dir)//'cl_2halo.dat'
                 ext='_cl_2halo.dat'
              ELSE IF(j==3) THEN
                 powa=powa_1h
                 outfile=TRIM(dir)//'cl_1halo.dat'
                 ext='_cl_1halo.dat'
              ELSE IF(j==4) THEN
                 powa=powa_full
                 outfile=TRIM(dir)//'cl_full.dat'
                 ext='_cl_full.dat'
              END IF

              IF(i>0) outfile=number_file2(base,NINT(log10(m1)),mid,NINT(log10(m2)),ext)

              WRITE(*,*) 'HMx: File: ', TRIM(outfile)

              CALL calculate_Cell(0.,maxdist(proj),ell,Cell,nl,k,a,powa,nk,na,proj,cosm)
              CALL write_Cell(ell,Cell,nl,outfile)

           END DO
           WRITE(*,*) 'HMx: Done'
           WRITE(*,*)

        END DO

     ELSE IF(imode==10) THEN

        !Break down cross-correlation in terms of redshift

        !Normalises power spectrum (via sigma_8) and fills sigma(R) look-up tables
        CALL initialise_cosmology(cosm)
        CALL print_cosmology(cosm)

        !Loop over redshifts
        !DO j=1,na
        !
        !   !z=-1.+1./a(j)
        !   z=redshift_a(a(j))
        !
        !   !Initiliasation for the halomodel calcualtion
        !   CALL halomod_init(mmin,mmax,z,lut,cosm)
        !   CALL calculate_halomod(ip(1),ip(2),k,nk,z,powa_lin(:,j),powa_2h(:,j),powa_1h(:,j),powa_full(:,j),lut,cosm)
        !
        !   !Write progress to screen
        !   IF(j==1) THEN
        !      WRITE(*,fmt='(A5,A7)') 'i', 'a'
        !      WRITE(*,fmt='(A13)') '   ============'
        !   END IF
        !   WRITE(*,fmt='(I5,F8.3)') j, a(j)
        !
        !END DO
        !WRITE(*,fmt='(A13)') '   ============'
        !WRITE(*,*)

        CALL calculate_HMx(ip,k,nk,a,na,powa_lin,powa_2h,powa_1h,powa_full,cosm)

        !output=TRIM(base)//'power'
        !CALL write_power_a(k,a,powa,nk,na,output)

        !Initialise the lensing part of the calculation
        CALL initialise_distances(cosm)
        CALL write_distances(cosm)

        !Fill out the projection kernels
        CALL fill_projection_kernels(ix,proj,cosm)
        CALL write_projection_kernels(proj,cosm)

        !Write to screen
        WRITE(*,*) 'HMx: Computing C(l)'
        WRITE(*,*) 'HMx: ell min:', REAL(ell(1))
        WRITE(*,*) 'HMx: ell max:', REAL(ell(nl))
        WRITE(*,*) 'HMx: number of ell:', nl
        WRITE(*,*)

        zmin=0.
        zmax=1.
        nz=8

        DO i=0,nz

           IF(i==0) THEN
              !z1=0.
              !z2=3.99 !Just less than z=4 to avoid rounding error
              r1=0.
              r2=maxdist(proj)
           ELSE
              IF(icumulative==0) THEN
                 !z1=zmin+(zmax-zmin)*float(i-1)/float(nz)
                 z1=progression(zmin,zmax,i,nz)
              ELSE IF(icumulative==1) THEN
                 z1=zmin
              END IF
              z2=zmin+(zmax-zmin)*float(i)/float(nz)
              r1=cosmic_distance(z1,cosm)
              r2=cosmic_distance(z2,cosm)
           END IF

           WRITE(*,*) 'HMx:', i
           IF(i>0) THEN
              WRITE(*,*) 'HMx: z1', REAL(z1)
              WRITE(*,*) 'HMx: z2', REAL(z2)
           END IF
           WRITE(*,*) 'HMx: r1 [Mpc/h]', REAL(r1)
           WRITE(*,*) 'HMx: r2 [Mpc/h]', REAL(r2)

           !Loop over all types of C(l) to create
           base=TRIM(dir)//'redshift_'
           mid='_'
           DO j=1,4

              !Set output files
              IF(j==1) THEN
                 ext='_cl_linear.dat'
                 outfile=TRIM(dir)//'cl_linear.dat'
                 powa=powa_lin
              ELSE IF(j==2) THEN
                 ext='_cl_2halo.dat'
                 outfile=TRIM(dir)//'cl_2halo.dat'
                 powa=powa_2h
              ELSE IF(j==3) THEN
                 ext='_cl_1halo.dat'
                 outfile=TRIM(dir)//'cl_1halo.dat'
                 powa=powa_1h
              ELSE IF(j==4) THEN
                 ext='_cl_full.dat'
                 outfile=TRIM(dir)//'cl_full.dat'
                 powa=powa_full
              END IF

              IF(i>0 .AND. icumulative==0) THEN
                 outfile=number_file2(base,i-1,mid,i,ext)
              ELSE IF(i>0 .AND. icumulative==1) THEN
                 outfile=number_file2(base,0,mid,i,ext)
              END IF
              WRITE(*,*) 'HMx: Output: ', TRIM(outfile)

              !This crashes for the low r2 values for some reason
              CALL calculate_Cell(r1,r2,ell,Cell,nl,k,a,powa,nk,na,proj,cosm)
              CALL write_Cell(ell,Cell,nl,outfile)

           END DO
           WRITE(*,*)

        END DO

        WRITE(*,*) 'HMx: Done'
        WRITE(*,*)

     ELSE IF(imode==11) THEN

        STOP 'HMx: Error, breakdown in radius is not supported yet'

     ELSE

        STOP 'HMx: Error, you have specified the mode incorrectly'

     END IF

  ELSE IF(imode==12) THEN

     !Project triad

     dir='data'

     !Assigns the cosmological model
     icosmo=0
     CALL assign_cosmology(icosmo,cosm)

     !Normalises power spectrum (via sigma_8) and fills sigma(R) look-up tables
     CALL initialise_cosmology(cosm)
     CALL print_cosmology(cosm)

     !Initialise the lensing part of the calculation
     CALL initialise_distances(cosm)
     CALL write_distances(cosm)

     !Set the ell range
     lmin=100.
     lmax=3000.
     nl=64

     !Allocate arrays for l and C(l)
     CALL fill_array(log(lmin),log(lmax),ell,nl)
     ell=exp(ell)
     ALLOCATE(Cell(nl))

     WRITE(*,*) 'HMx: Cross-correlation information'
     WRITE(*,*) 'HMx: output directiory: ', TRIM(dir)
     WRITE(*,*) 'HMx: minimum ell:', REAL(lmin)
     WRITE(*,*) 'HMx: maximum ell:', REAL(lmax)
     WRITE(*,*) 'HMx: number of ell:', nl
     WRITE(*,*)

     !Loop over the triad
     DO i=1,3

        IF(i==1) THEN
           !ix(1)=4 !CFHTLenS
           ix(1)=5 !KiDS
           ix(2)=3 !CMB
           outfile=TRIM(dir)//'/triad_Cl_gal-CMB.dat'
        ELSE IF(i==2) THEN
           ix(1)=3 !CMB
           ix(2)=2 !y
           outfile=TRIM(dir)//'/triad_Cl_CMB-y.dat'
        ELSE IF(i==3) THEN
           ix(1)=2 !y
           !ix(2)=4 !CFHTLenS
           ix(2)=5 !KiDS
           outfile=TRIM(dir)//'/triad_Cl_y-gal.dat'
        END IF

        CALL xcorr(ix,ell,Cell,nl,cosm,.TRUE.)
        CALL write_Cell(ell,Cell,nl,outfile)

        WRITE(*,*) 'HMx: Done'
        WRITE(*,*)

     END DO

  ELSE IF(imode==13) THEN

     !Calculate the cross-correlation coefficient

     !Assign the cosmology
     icosmo=-1
     CALL assign_cosmology(icosmo,cosm)

     !Normalises power spectrum (via sigma_8) and fills sigma(R) look-up tables
     CALL initialise_cosmology(cosm)
     CALL print_cosmology(cosm)

     !Initialise the lensing part of the calculation
     CALL initialise_distances(cosm)
     CALL write_distances(cosm)

     !Set the ell range and allocate arrays for l and C(l)
     lmin=1e0
     lmax=1e5
     nl=64 
     CALL fill_array(log(lmin),log(lmax),ell,nl)
     ell=exp(ell)
     ALLOCATE(Cell(nl))

     dir='data'

     ixx=-1
     CALL set_ix(ixx,ip)

     DO i=1,3
        IF(i==1) THEN
           ix(1)=ixx(1)
           ix(2)=ixx(1)
           outfile=TRIM(dir)//'/cl_first.dat'
        ELSE IF(i==2) THEN
           ix(1)=ixx(2)
           ix(2)=ixx(2)
           outfile=TRIM(dir)//'/cl_second.dat'
        ELSE IF(i==3) THEN
           ix(1)=ixx(1)
           ix(2)=ixx(2)
           outfile=TRIM(dir)//'/cl_full.dat'
        END IF
        CALL xcorr(ix,ell,Cell,nl,cosm,.TRUE.)
        CALL write_Cell(ell,Cell,nl,outfile)
     END DO

  ELSE IF(imode==14) THEN

     !Make power spectra as a function of parameter variations

     !Number of values to try for each parameter
     m=9

     !Set number of k points and k range (log spaced)
     nk=128
     kmin=1.e-3
     kmax=1.e1
     CALL fill_array(log(kmin),log(kmax),k,nk)
     k=exp(k)
     ALLOCATE(pow_lin(nk),pow_2h(nk),pow_1h(nk),pow_full(nk))

     !Set the redshift
     z=0.

     !Assigns the cosmological model
     icosmo=1
     CALL assign_cosmology(icosmo,cosm)

     !Normalises power spectrum (via sigma_8) and fills sigma(R) look-up tables
     CALL initialise_cosmology(cosm)
     CALL print_cosmology(cosm)

     !Initiliasation for the halomodel calcualtion
     CALL halomod_init(mmin,mmax,z,lut,cosm)  

     !DMONLY
     j1=-1
     j2=-1
     outfile='variations/DMONLY.dat'
     CALL calculate_halomod(j1,j2,k,nk,z,pow_lin,pow_2h,pow_1h,pow_full,lut,cosm)
     CALL write_power(k,pow_lin,pow_2h,pow_1h,pow_full,nk,outfile)

     !Loop over parameters
     DO ipa=1,cosm%np
        !DO ipa=2,2

        cosm%param=cosm%param_defaults

        !Loop over parameter values
        DO i=1,m

           !Set the parameter value that is being varied
           IF(cosm%param_log(ipa)) THEN
              cosm%param(ipa)=progression(log(cosm%param_min(ipa)),log(cosm%param_max(ipa)),i,m)
              cosm%param(ipa)=exp(cosm%param(ipa))
           ELSE
              cosm%param(ipa)=progression(cosm%param_min(ipa),cosm%param_max(ipa),i,m)
           END IF

           !Write out halo matter and pressure profile information
           !All the string crap is in the loop for a reason
           DO j=10,16
              base='variations/profile_mass_'
              ext='_param_'
              base=number_file(base,j,ext)
              mid='_value_'
              ext='.dat'
              outfile=number_file2(base,ipa,mid,i,ext)
              mass=10.**j
              CALL write_halo_profiles(mass,z,lut,cosm,outfile)
           END DO

           !Write out halo mass fraction information
           base='variations/mass_fractions_param_'
           outfile=number_file2(base,ipa,mid,i,ext)
           CALL write_mass_fractions(cosm,outfile)

           !File base and extension
           base='variations/power_param_'
           mid='_value_'

           !Do the calculation
           DO j=1,9

              IF(j==1) THEN
                 !matter-matter
                 j1=0
                 j2=0
                 ext='_dd.dat'
              ELSE IF(j==2) THEN
                 !matter-pressure
                 j1=0
                 j2=6
                 ext='_dp.dat'
              ELSE IF(j==3) THEN
                 !pressure-pressure
                 j1=6
                 j2=6
                 ext='_pp.dat'
              ELSE IF(j==4) THEN
                 !matter-CDM
                 j1=0
                 j2=1
                 ext='_dc.dat'
              ELSE IF(j==5) THEN
                 !CDM-CDM
                 j1=1
                 j2=1
                 ext='_cc.dat'
              ELSE IF(j==6) THEN
                 !matter-gas
                 j1=0
                 j2=2
                 ext='_dg.dat'
              ELSE IF(j==7) THEN
                 !gas-gas
                 j1=2
                 j2=2
                 ext='_gg.dat'
              ELSE IF(j==8) THEN
                 !Matter-star
                 j1=0
                 j2=3
                 ext='_ds.dat'
              ELSE IF(j==9) THEN
                 !Star-star
                 j1=3
                 j2=3
                 ext='_ss.dat'
              END IF

              !Set output file
              outfile=number_file2(base,ipa,mid,i,ext)

              !Write progress to screen
              WRITE(*,fmt='(4I5,A50)') ipa, i, j1, j2, TRIM(outfile)

              !Do the halo-model calculation and write to file
              CALL calculate_halomod(j1,j2,k,nk,z,pow_lin,pow_2h,pow_1h,pow_full,lut,cosm)
              CALL write_power(k,pow_lin,pow_2h,pow_1h,pow_full,nk,outfile)

           END DO

        END DO

     END DO

  ELSE

     STOP 'HMx: Error, you have specified the mode incorrectly'

  END IF

END PROGRAM HMx_driver