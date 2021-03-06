! SUMMA - Structure for Unifying Multiple Modeling Alternatives
! Copyright (C) 2014-2015 NCAR/RAL
!
! This file is part of SUMMA
!
! For more information see: http://www.ral.ucar.edu/projects/summa
!
! This program is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation, either version 3 of the License, or
! (at your option) any later version.
!
! This program is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License
! along with this program.  If not, see <http://www.gnu.org/licenses/>.

MODULE globalData
 ! data types
 USE nrtype
 USE data_types,only:gru2hru_map     ! mapping between the GRUs and HRUs
 USE data_types,only:hru2gru_map     ! mapping between the GRUs and HRUs
 USE data_types,only:model_options   ! the model decision structure
 USE data_types,only:file_info       ! metadata for model forcing datafile
 USE data_types,only:par_info        ! default parameter values and parameter bounds
 USE data_types,only:var_info        ! metadata for variables in each model structure
 USE data_types,only:extended_info   ! extended metadata for variables in each model structure
 USE data_types,only:struct_info     ! summary information on all data structures 
 USE data_types,only:var_i           ! vector of integers 
 ! number of variables in each data structure
 USE var_lookup,only:maxvarTime      ! time:                     maximum number variables
 USE var_lookup,only:maxvarForc      ! forcing data:             maximum number variables
 USE var_lookup,only:maxvarAttr      ! attributes:               maximum number variables
 USE var_lookup,only:maxvarType      ! type index:               maximum number variables
 USE var_lookup,only:maxvarProg      ! prognostic variables:     maximum number variables
 USE var_lookup,only:maxvarDiag      ! diagnostic variables:     maximum number variables
 USE var_lookup,only:maxvarFlux      ! model fluxes:             maximum number variables
 USE var_lookup,only:maxvarDeriv     ! model derivatives:        maximum number variables
 USE var_lookup,only:maxvarIndx      ! model indices:            maximum number variables
 USE var_lookup,only:maxvarMpar      ! model parameters:         maximum number variables
 USE var_lookup,only:maxvarBvar      ! basin-average variables:  maximum number variables
 USE var_lookup,only:maxvarBpar      ! basin-average parameters: maximum number variables
 USE var_lookup,only:maxvarDecisions ! maximum number of decisions
 USE var_lookup,only:maxFreq         ! maximum number of output files
 implicit none
 private

 ! define missing values
 real(dp),parameter,public                   :: quadMissing=-9999._qp   ! missing quadruple precision number
 real(dp),parameter,public                   :: realMissing=-9999._dp   ! missing double precision number
 integer(i4b),parameter,public               :: integerMissing=-9999    ! missing integer 

 ! define limit checks
 real(dp),parameter,public                   :: verySmall=tiny(1.0_dp)  ! a very small number
 real(dp),parameter,public                   :: veryBig=1.e+20_dp       ! a very big number

 ! define algorithmix control parameters
 real(dp),parameter,public                   :: dx = 1.e-8_dp            ! finite difference increment

 ! Define the model decisions
 type(model_options),save,public             :: model_decisions(maxvarDecisions)  ! the model decision structure

 ! Define metadata for model forcing datafile
 type(file_info),save,public,allocatable     :: forcFileInfo(:)         ! file info for model forcing data

 ! define default parameter values and parameter bounds 
 type(par_info),save,public                  :: localParFallback(maxvarMpar) ! local column default parameters
 type(par_info),save,public                  :: basinParFallback(maxvarBpar) ! basin-average default parameters

 ! define vectors of metadata
 type(var_info),save,public                  :: time_meta(maxvarTime)   ! model time information
 type(var_info),save,public                  :: forc_meta(maxvarForc)   ! model forcing data
 type(var_info),save,public                  :: attr_meta(maxvarAttr)   ! local attributes
 type(var_info),save,public                  :: type_meta(maxvarType)   ! local classification of veg, soil, etc.
 type(var_info),save,public                  :: mpar_meta(maxvarMpar)   ! local model parameters for each HRU
 type(var_info),save,public                  :: indx_meta(maxvarIndx)   ! local model indices for each HRU
 type(var_info),save,public                  :: prog_meta(maxvarProg)   ! local state variables for each HRU
 type(var_info),save,public                  :: diag_meta(maxvarDiag)   ! local diagnostic variables for each HRU
 type(var_info),save,public                  :: flux_meta(maxvarFlux)   ! local model fluxes for each HRU
 type(var_info),save,public                  :: deriv_meta(maxvarDeriv) ! local model derivatives for each HRU
 type(var_info),save,public                  :: bpar_meta(maxvarBpar)   ! basin parameters for aggregated processes
 type(var_info),save,public                  :: bvar_meta(maxvarBvar)   ! basin variables for aggregated processes

 ! ancillary metadata structures
 type(extended_info),save,public,allocatable :: averageFlux_meta(:)     ! timestep-average model fluxes

 ! define summary information on all data structures
 integer(i4b),parameter                      :: nStruct=12              ! number of data structures
 type(struct_info),parameter,public,dimension(nStruct) :: structInfo=(/&
                   struct_info('time',  'TIME' , maxvarTime ), &        ! the time data structure
                   struct_info('forc',  'FORCE', maxvarForc ), &        ! the forcing data structure
                   struct_info('attr',  'ATTR' , maxvarAttr ), &        ! the attribute data structure
                   struct_info('type',  'TYPE' , maxvarType ), &        ! the type data structure
                   struct_info('mpar',  'PARAM', maxvarMpar ), &        ! the model parameter data structure
                   struct_info('bpar',  'BPAR' , maxvarBpar ), &        ! the basin parameter data structure
                   struct_info('bvar',  'BVAR' , maxvarBvar ), &        ! the basin variable data structure
                   struct_info('indx',  'INDEX', maxvarIndx ), &        ! the model index data structure
                   struct_info('prog',  'PROG',  maxvarProg ), &        ! the prognostic (state) variable data structure
                   struct_info('diag',  'DIAG' , maxvarDiag ), &        ! the diagnostic variable data structure
                   struct_info('flux',  'FLUX' , maxvarFlux ), &        ! the flux data structure
                   struct_info('deriv', 'DERIV', maxvarDeriv) /)        ! the model derivative data structure

 ! define named variables to describe the layer type
 integer(i4b),parameter,public               :: ix_soil=1001            ! named variable to denote a soil layer
 integer(i4b),parameter,public               :: ix_snow=1002            ! named variable to denote a snow layer

 ! define named variables to describe the state varible type            
 integer(i4b),parameter,public               :: ixNrgState=2001         ! named variable defining the energy state variable
 integer(i4b),parameter,public               :: ixWatState=2002         ! named variable defining the total water state variable
 integer(i4b),parameter,public               :: ixMatState=2003         ! named variable defining the matric head state variable
 integer(i4b),parameter,public               :: ixMassState=2004        ! named variable defining the mass of water (currently only used for the veg canopy)

 ! define named variables to describe the form and structure of the band-diagonal matrices used in the numerical solver
 ! NOTE: This indexing scheme provides the matrix structure expected by lapack. Specifically, lapack requires kl extra rows for additional storage.
 !       Consequently, all indices are offset by kl and the total number of bands for storage is 2*kl+ku+1 instead of kl+ku+1.
 integer(i4b),parameter,public               :: nRHS=1                  ! number of unknown variables on the RHS of the linear system A.X=B
 integer(i4b),parameter,public               :: ku=3                    ! number of super-diagonal bands
 integer(i4b),parameter,public               :: kl=4                    ! number of sub-diagonal bands
 integer(i4b),parameter,public               :: ixSup3=kl+1             ! index for the 3rd super-diagonal band
 integer(i4b),parameter,public               :: ixSup2=kl+2             ! index for the 2nd super-diagonal band
 integer(i4b),parameter,public               :: ixSup1=kl+3             ! index for the 1st super-diagonal band
 integer(i4b),parameter,public               :: ixDiag=kl+4             ! index for the diagonal band
 integer(i4b),parameter,public               :: ixSub1=kl+5             ! index for the 1st sub-diagonal band
 integer(i4b),parameter,public               :: ixSub2=kl+6             ! index for the 2nd sub-diagonal band
 integer(i4b),parameter,public               :: ixSub3=kl+7             ! index for the 3rd sub-diagonal band
 integer(i4b),parameter,public               :: ixSub4=kl+8             ! index for the 3rd sub-diagonal band
 integer(i4b),parameter,public               :: nBands=2*kl+ku+1        ! length of the leading dimension of the band diagonal matrix

 ! define named variables for the type of matrix used in the numerical solution.
 integer(i4b),parameter,public               :: ixFullMatrix=1001       ! named variable for the full Jacobian matrix
 integer(i4b),parameter,public               :: ixBandMatrix=1002       ! named variable for the band diagonal matrix

 ! define indices describing the first and last layers of the Jacobian to print (for debugging)
 integer(i4b),parameter,public               :: iJac1=1                 ! first layer of the Jacobian to print
 integer(i4b),parameter,public               :: iJac2=10                ! last layer of the Jacobian to print

 ! define mapping structures
 type(gru2hru_map),allocatable,save,public   :: gru_struc(:)            ! gru2hru map ! NOTE: change variable name to be more self describing
 type(hru2gru_map),allocatable,save,public   :: index_map(:)            ! hru2gru map ! NOTE: change variable name to be more self describing

 ! define common variables
 integer(i4b),save,public                    :: numtim                  ! number of time steps
 real(dp),save,public                        :: data_step               ! time step of the data
 real(dp),save,public                        :: refJulday               ! reference time in fractional julian days
 real(dp),save,public                        :: fracJulday              ! fractional julian days since the start of year
 real(dp),save,public                        :: dJulianStart            ! julian day of start time of simulation
 real(dp),save,public                        :: dJulianFinsh            ! julian day of end time of simulation
 integer(i4b),save,public                    :: yearLength              ! number of days in the current year
 integer(i4b),save,public                    :: urbanVegCategory        ! vegetation category for urban areas
 logical(lgt),save,public                    :: doJacobian=.false.      ! flag to compute the Jacobian
 logical(lgt),save,public                    :: globalPrintFlag=.false. ! flag to compute the Jacobian

 ! define ancillary data structures
 type(var_i),save,public                     :: refTime                 ! reference time for the model simulation
 type(var_i),save,public                     :: startTime               ! start time for the model simulation
 type(var_i),save,public                     :: finshTime               ! end time for the model simulation

 ! output file information
 integer(i4b),dimension(maxFreq),save,public :: ncid                    ! netcdf output file id
 integer(i4b),save,public                    :: nFreq                   ! actual number of output files
 integer(i4b),dimension(maxFreq),save,public :: outFreq                 ! frequency of all output files



END MODULE globalData
