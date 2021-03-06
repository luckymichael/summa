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

module eval8summa_module

! data types
USE nrtype

! access missing values
USE multiconst,only:integerMissing  ! missing integer
USE multiconst,only:realMissing     ! missing double precision number
USE multiconst,only:quadMissing     ! missing quadruple precision number

! access the global print flag
USE globalData,only:globalPrintFlag

! constants
USE multiconst,only:&
                    Tfreeze,      & ! temperature at freezing              (K)
                    LH_fus,       & ! latent heat of fusion                (J kg-1)
                    LH_vap,       & ! latent heat of vaporization          (J kg-1)
                    LH_sub,       & ! latent heat of sublimation           (J kg-1)
                    Cp_air,       & ! specific heat of air                 (J kg-1 K-1)
                    iden_air,     & ! intrinsic density of air             (kg m-3)
                    iden_ice,     & ! intrinsic density of ice             (kg m-3)
                    iden_water      ! intrinsic density of liquid water    (kg m-3)

! layer types
USE globalData,only:ix_soil,ix_snow ! named variables for snow and soil

! provide access to the derived types to define the data structures
USE data_types,only:&
                    var_i,        & ! data vector (i4b)
                    var_d,        & ! data vector (dp)
                    var_ilength,  & ! data vector with variable length dimension (i4b)
                    var_dlength,  & ! data vector with variable length dimension (dp)
                    model_options   ! defines the model decisions

! look-up values for the choice of groundwater representation (local-column, or single-basin)
USE mDecisions_module,only:  &
 localColumn,                & ! separate groundwater representation in each local soil column
 singleBasin                   ! single groundwater store over the entire basin

! look-up values for the choice of groundwater parameterization
USE mDecisions_module,only:  &
 qbaseTopmodel,              & ! TOPMODEL-ish baseflow parameterization
 bigBucket,                  & ! a big bucket (lumped aquifer model)
 noExplicit                    ! no explicit groundwater parameterization

! look-up values for the form of Richards' equation
USE mDecisions_module,only:  &
 moisture,                   & ! moisture-based form of Richards' equation
 mixdform                      ! mixed form of Richards' equation

implicit none
private
public::eval8summa

contains

 ! **********************************************************************************************************
 ! public subroutine eval8summa: compute the residual vector and the Jacobian matrix
 ! **********************************************************************************************************
 subroutine eval8summa(&
                       ! input: model control
                       dt,                      & ! intent(in):    length of the time step (seconds)
                       nSnow,                   & ! intent(in):    number of snow layers
                       nSoil,                   & ! intent(in):    number of soil layers
                       nLayers,                 & ! intent(in):    total number of layers
                       nState,                  & ! intent(in):    total number of state variables
                       firstSubStep,            & ! intent(in):    flag to indicate if we are processing the first sub-step
                       firstFluxCall,           & ! intent(inout): flag to indicate if we are processing the first flux call
                       computeVegFlux,          & ! intent(in):    flag to indicate if we need to compute fluxes over vegetation
                       canopyDepth,             & ! intent(in):    depth of the vegetation canopy (m)
                       ! input: state vectors
                       stateVecTrial,           & ! intent(in):    model state vector
                       fScale,                  & ! intent(in):    function scaling vector
                       sMul,                    & ! intent(in):    state vector multiplier (used in the residual calculations)
                       ! input: data structures
                       model_decisions,         & ! intent(in):    model decisions
                       type_data,               & ! intent(in):    type of vegetation and soil
                       attr_data,               & ! intent(in):    spatial attributes
                       mpar_data,               & ! intent(in):    model parameters
                       forc_data,               & ! intent(in):    model forcing data
                       bvar_data,               & ! intent(in):    average model variables for the entire basin
                       prog_data,               & ! intent(in):    model prognostic variables for a local HRU
                       indx_data,               & ! intent(in):    index data
                       ! input-output: data structures
                       diag_data,               & ! intent(inout): model diagnostic variables for a local HRU
                       flux_data,               & ! intent(inout): model fluxes for a local HRU
                       deriv_data,              & ! intent(inout): derivatives in model fluxes w.r.t. relevant state variables
                       ! input-output: baseflow
                       ixSaturation,            & ! intent(inout): index of the lowest saturated layer (NOTE: only computed on the first iteration)
                       dBaseflow_dMatric,       & ! intent(out):   derivative in baseflow w.r.t. matric head (s-1)
                       ! output: flux and residual vectors
                       feasible,                & ! intent(out):   flag to denote the feasibility of the solution
                       fluxVec,                 & ! intent(out):   flux vector
                       resSink,                 & ! intent(out):   additional (sink) terms on the RHS of the state equation
                       resVec,                  & ! intent(out):   residual vector
                       fEval,                   & ! intent(out):   function evaluation
                       err,message)               ! intent(out):   error control
 ! --------------------------------------------------------------------------------------------------------------------------------
 ! provide access to subroutines
 USE getVectorz_module, only:varExtract           ! extract variables from the state vector
 USE computFlux_module, only:soilCmpres           ! compute soil compression 
 USE computFlux_module, only:computFlux           ! compute fluxes given a state vector
 USE computResid_module,only:computResid          ! compute residuals given a state vector 
 ! provide access to indices that define elements of the data structures
 USE var_lookup,only:iLookDECISIONS               ! named variables for elements of the decision structure
 USE var_lookup,only:iLookTYPE                    ! named variables for structure elements
 USE var_lookup,only:iLookATTR                    ! named variables for structure elements
 USE var_lookup,only:iLookPARAM                   ! named variables for structure elements
 USE var_lookup,only:iLookFORCE                   ! named variables for structure elements
 USE var_lookup,only:iLookBVAR                    ! named variables for structure elements
 USE var_lookup,only:iLookPROG                    ! named variables for structure elements
 USE var_lookup,only:iLookINDEX                   ! named variables for structure elements
 USE var_lookup,only:iLookDIAG                    ! named variables for structure elements
 USE var_lookup,only:iLookFLUX                    ! named variables for structure elements
 USE var_lookup,only:iLookDERIV                   ! named variables for structure elements
 implicit none
 ! --------------------------------------------------------------------------------------------------------------------------------
 ! --------------------------------------------------------------------------------------------------------------------------------
 ! input: model control
 real(dp),intent(in)             :: dt                     ! length of the time step (seconds)
 integer(i4b),intent(in)         :: nSnow                  ! number of snow layers
 integer(i4b),intent(in)         :: nSoil                  ! number of soil layers
 integer(i4b),intent(in)         :: nLayers                ! total number of layers
 integer(i4b),intent(in)         :: nState                 ! total number of state variables
 logical(lgt),intent(in)         :: firstSubStep           ! flag to indicate if we are processing the first sub-step
 logical(lgt),intent(inout)      :: firstFluxCall          ! flag to indicate if we are processing the first flux call
 logical(lgt),intent(in)         :: computeVegFlux         ! flag to indicate if computing fluxes over vegetation
 real(dp),intent(in)             :: canopyDepth            ! depth of the vegetation canopy (m)
 ! input: state vectors
 real(dp),intent(in)             :: stateVecTrial(:)       ! model state vector 
 real(dp),intent(in)             :: fScale(:)              ! function scaling vector
 real(qp),intent(in)             :: sMul(:)   ! NOTE: qp   ! state vector multiplier (used in the residual calculations)
 ! input: data structures
 type(model_options),intent(in)  :: model_decisions(:)     ! model decisions
 type(var_i),        intent(in)  :: type_data              ! type of vegetation and soil
 type(var_d),        intent(in)  :: attr_data              ! spatial attributes
 type(var_d),        intent(in)  :: mpar_data              ! model parameters
 type(var_d),        intent(in)  :: forc_data              ! model forcing data
 type(var_dlength),  intent(in)  :: bvar_data              ! model variables for the local basin
 type(var_dlength),  intent(in)  :: prog_data              ! prognostic variables for a local HRU
 type(var_ilength),  intent(in)  :: indx_data              ! indices defining model states and layers
 ! output: data structures
 type(var_dlength),intent(inout) :: diag_data              ! diagnostic variables for a local HRU
 type(var_dlength),intent(inout) :: flux_data              ! model fluxes for a local HRU
 type(var_dlength),intent(inout) :: deriv_data             ! derivatives in model fluxes w.r.t. relevant state variables
 ! input-output: baseflow
 integer(i4b),intent(inout)      :: ixSaturation           ! index of the lowest saturated layer (NOTE: only computed on the first iteration)
 real(dp),intent(out)            :: dBaseflow_dMatric(:,:) ! derivative in baseflow w.r.t. matric head (s-1)
 ! output: flux and residual vectors
 logical(lgt),intent(out)        :: feasible               ! flag to denote the feasibility of the solution
 real(dp),intent(out)            :: fluxVec(:)             ! flux vector
 real(dp),intent(out)            :: resSink(:)             ! sink terms on the RHS of the flux equation
 real(qp),intent(out)            :: resVec(:) ! NOTE: qp   ! residual vector
 real(dp),intent(out)            :: fEval                  ! function evaluation
 ! output: error control
 integer(i4b),intent(out)        :: err                    ! error code
 character(*),intent(out)        :: message                ! error message
 ! --------------------------------------------------------------------------------------------------------------------------------
 ! local variables
 ! --------------------------------------------------------------------------------------------------------------------------------
 ! state variables
 real(dp)                        :: scalarCanairTempTrial  ! trial value for temperature of the canopy air space (K)
 real(dp)                        :: scalarCanopyTempTrial  ! trial value for temperature of the vegetation canopy (K)
 real(dp)                        :: scalarCanopyWatTrial   ! trial value for liquid water storage in the canopy (kg m-2)
 real(dp),dimension(nLayers)     :: mLayerTempTrial        ! trial value for temperature of layers in the snow and soil domains (K)
 real(dp),dimension(nLayers)     :: mLayerVolFracWatTrial  ! trial value for volumetric fraction of total water (-)
 real(dp),dimension(nSoil)       :: mLayerMatricHeadTrial  ! trial value for matric head (m)
 ! diagnostic variables
 real(dp)                        :: scalarCanopyLiqTrial   ! trial value for mass of liquid water on the vegetation canopy (kg m-2)
 real(dp)                        :: scalarCanopyIceTrial   ! trial value for mass of ice on the vegetation canopy (kg m-2)
 real(dp),dimension(nLayers)     :: mLayerVolFracLiqTrial  ! trial value for volumetric fraction of liquid water (-)
 real(dp),dimension(nLayers)     :: mLayerVolFracIceTrial  ! trial value for volumetric fraction of ice (-)
 ! other local variables
 real(dp),dimension(nState)      :: rVecScaled             ! scaled residual vector
 character(LEN=256)              :: cmessage               ! error message of downwind routine
 ! --------------------------------------------------------------------------------------------------------------------------------
 ! association to variables in the data structures
 ! --------------------------------------------------------------------------------------------------------------------------------
 associate(&
 ! model decisions
 ixRichards              => model_decisions(iLookDECISIONS%f_Richards)%iDecision   ,&  ! intent(in): [i4b] index of the form of Richards' equation
 ! snow parameters
 snowfrz_scale           => mpar_data%var(iLookPARAM%snowfrz_scale)                ,&  ! intent(in): [dp] scaling parameter for the snow freezing curve (K-1)
 ! soil parameters
 vGn_m                   => diag_data%var(iLookDIAG%scalarVGn_m)%dat(1)            ,&  ! intent(in): [dp] van Genutchen "m" parameter (-)
 vGn_n                   => mpar_data%var(iLookPARAM%vGn_n)                        ,&  ! intent(in): [dp] van Genutchen "n" parameter (-)
 vGn_alpha               => mpar_data%var(iLookPARAM%vGn_alpha)                    ,&  ! intent(in): [dp] van Genutchen "alpha" parameter (m-1)
 theta_sat               => mpar_data%var(iLookPARAM%theta_sat)                    ,&  ! intent(in): [dp] soil porosity (-)
 theta_res               => mpar_data%var(iLookPARAM%theta_res)                    ,&  ! intent(in): [dp] soil residual volumetric water content (-)
 specificStorage         => mpar_data%var(iLookPARAM%specificStorage)              ,&  ! intent(in): [dp] specific storage coefficient (m-1)
 ! model state variables (ponded water)
 scalarSfcMeltPond       => prog_data%var(iLookPROG%scalarSfcMeltPond)%dat(1)      ,&  ! intent(in): [dp]     ponded water caused by melt of the "snow without a layer" (kg m-2)
 mLayerMatricHead        => prog_data%var(iLookPROG%mLayerMatricHead)%dat          ,&  ! intent(in): [dp(:)]  matric head (m)
 mLayerDepth             => prog_data%var(iLookPROG%mLayerDepth)%dat               ,&  ! intent(in): [dp(:)]  depth of each layer (m)
 ! model diagnostic variables (fraction of liquid water)
 scalarFracLiqVeg        => diag_data%var(iLookDIAG%scalarFracLiqVeg)%dat(1)       ,&  ! intent(out): [dp]    fraction of liquid water on vegetation (-)
 mLayerFracLiqSnow       => diag_data%var(iLookDIAG%mLayerFracLiqSnow)%dat         ,&  ! intent(out): [dp(:)] fraction of liquid water in each snow layer (-)
 ! soil compression
 scalarSoilCompress      => diag_data%var(iLookDIAG%scalarSoilCompress)%dat(1)     ,&  ! intent(out): [dp]    total change in storage associated with compression of the soil matrix (kg m-2)
 mLayerCompress          => diag_data%var(iLookDIAG%mLayerCompress)%dat            ,&  ! intent(out): [dp(:)] change in storage associated with compression of the soil matrix (-)
 ! derivatives
 dVolTot_dPsi0           => deriv_data%var(iLookDERIV%dVolTot_dPsi0)%dat           ,&  ! intent(out): [dp(:)] derivative in total water content w.r.t. total water matric potential
 dCompress_dPsi          => deriv_data%var(iLookDERIV%dCompress_dPsi)%dat          ,&  ! intent(out): [dp(:)] derivative in compressibility w.r.t. matric head (m-1)
 ! indices
 ixVegWat                => indx_data%var(iLookINDEX%ixVegWat)%dat(1)              ,&  ! intent(in): [i4b] index of canopy hydrology state variable (mass)
 ixSnowOnlyNrg           => indx_data%var(iLookINDEX%ixSnowOnlyNrg)%dat            ,&  ! intent(in): [i4b(:)] indices for energy states in the snow subdomain
 ixSnowOnlyWat           => indx_data%var(iLookINDEX%ixSnowOnlyWat)%dat             &  ! intent(in): [i4b(:)] indices for total water states in the snow subdomain

 ) ! association to variables in the data structures
 ! --------------------------------------------------------------------------------------------------------------------------------
 ! initialize error control
 err=0; message="eval8summa/"

 ! check the feasibility of the solution
 feasible=.true.

 ! check canopy liquid water is not negative
 if(computeVegFlux)then
  if(stateVecTrial(ixVegWat) < 0._dp) feasible=.false.
 end if

 ! check snow temperature is below freezing and snow liquid water is not negative
 if(nSnow>0)then
  if(any(stateVecTrial(ixSnowOnlyNrg) > Tfreeze)) feasible=.false.
  if(any(stateVecTrial(ixSnowOnlyWat) < 0._dp)  ) feasible=.false.
 end if

 ! early return for non-feasible solutions
 if(.not.feasible)then
  fluxVec(:) = realMissing 
  resVec(:)  = quadMissing 
  fEval      = realMissing
  return
 end if

 ! extract variables from the model state vector
 call varExtract(&
                 ! input
                 stateVecTrial,                             & ! intent(in):    model state vector (mixed units)
                 indx_data,                                 & ! intent(in):    indices defining model states and layers
                 snowfrz_scale,                             & ! intent(in):    scaling parameter for the snow freezing curve (K-1)
                 vGn_alpha,vGn_n,theta_sat,theta_res,vGn_m, & ! intent(in):    van Genutchen soil parameters
                 ! output: variables for the vegetation canopy
                 scalarFracLiqVeg,                          & ! intent(out):   fraction of liquid water on the vegetation canopy (-)
                 scalarCanairTempTrial,                     & ! intent(out):   trial value of canopy air temperature (K)
                 scalarCanopyTempTrial,                     & ! intent(out):   trial value of canopy temperature (K)
                 scalarCanopyWatTrial,                      & ! intent(out):   trial value of canopy total water (kg m-2)
                 scalarCanopyLiqTrial,                      & ! intent(out):   trial value of canopy liquid water (kg m-2)
                 scalarCanopyIceTrial,                      & ! intent(out):   trial value of canopy ice content (kg m-2)
                 ! output: variables for the snow-soil domain
                 mLayerFracLiqSnow,                         & ! intent(out):   volumetric fraction of water in each snow layer (-)
                 mLayerTempTrial,                           & ! intent(out):   trial vector of layer temperature (K)
                 mLayerVolFracWatTrial,                     & ! intent(out):   trial vector of volumetric total water content (-)
                 mLayerVolFracLiqTrial,                     & ! intent(out):   trial vector of volumetric liquid water content (-)
                 mLayerVolFracIceTrial,                     & ! intent(out):   trial vector of volumetric ice water content (-)
                 mLayerMatricHeadTrial,                     & ! intent(out):   trial vector of matric head (m)
                 ! output: error control
                 err,cmessage)                                ! intent(out):   error control
 if(err/=0)then; message=trim(message)//trim(cmessage); return; end if  ! (check for errors)


 ! compute the fluxes for a given state vector
 call computFlux(&
                 ! input-output: model control
                 nSnow,                   & ! intent(in):    number of snow layers
                 nSoil,                   & ! intent(in):    number of soil layers
                 nLayers,                 & ! intent(in):    total number of layers
                 firstSubStep,            & ! intent(in):    flag to indicate if we are processing the first sub-step
                 firstFluxCall,           & ! intent(inout): flag to denote the first flux call
                 computeVegFlux,          & ! intent(in):    flag to indicate if we need to compute fluxes over vegetation
                 canopyDepth,             & ! intent(in):    depth of the vegetation canopy (m)
                 scalarSfcMeltPond/dt,    & ! intent(in):    drainage from the surface melt pond (kg m-2 s-1)
                 ! input: state variables
                 scalarCanairTempTrial,   & ! intent(in):    trial value for the temperature of the canopy air space (K)
                 scalarCanopyTempTrial,   & ! intent(in):    trial value for the temperature of the vegetation canopy (K)
                 mLayerTempTrial,         & ! intent(in):    trial value for the temperature of each snow and soil layer (K)
                 mLayerMatricHeadTrial,   & ! intent(in):    trial value for the matric head in each soil layer (m)
                 ! input: diagnostic variables defining the liquid water and ice content
                 scalarCanopyLiqTrial,    & ! intent(in):    trial value for the liquid water on the vegetation canopy (kg m-2)
                 scalarCanopyIceTrial,    & ! intent(in):    trial value for the ice on the vegetation canopy (kg m-2)
                 mLayerVolFracLiqTrial,   & ! intent(in):    trial value for the volumetric liquid water content in each snow and soil layer (-)
                 mLayerVolFracIceTrial,   & ! intent(in):    trial value for the volumetric ice in each snow and soil layer (-)
                 ! input: data structures
                 model_decisions,         & ! intent(in):    model decisions
                 type_data,               & ! intent(in):    type of vegetation and soil
                 attr_data,               & ! intent(in):    spatial attributes
                 mpar_data,               & ! intent(in):    model parameters
                 forc_data,               & ! intent(in):    model forcing data
                 bvar_data,               & ! intent(in):    average model variables for the entire basin
                 prog_data,               & ! intent(in):    model prognostic variables for a local HRU
                 indx_data,               & ! intent(in):    index data
                 ! input-output: data structures
                 diag_data,               & ! intent(inout): model diagnostic variables for a local HRU
                 flux_data,               & ! intent(inout): model fluxes for a local HRU
                 deriv_data,              & ! intent(out):   derivatives in model fluxes w.r.t. relevant state variables
                 ! input-output: flux vector and baseflow derivatives
                 ixSaturation,            & ! intent(inout): index of the lowest saturated layer (NOTE: only computed on the first iteration)
                 dBaseflow_dMatric,       & ! intent(out):   derivative in baseflow w.r.t. matric head (s-1)
                 fluxVec,                 & ! intent(out):   flux vector (mixed units)
                 ! output: error control
                 err,cmessage)              ! intent(out):   error code and error message
 if(err/=0)then; message=trim(message)//trim(cmessage); return; end if  ! (check for errors)


 ! compute soil compressibility (-) and its derivative w.r.t. matric head (m)
 ! NOTE: we already extracted trial matrix head and volumetric liquid water as part of the flux calculations
 call soilCmpres(&
                 ! input:
                 ixRichards,                             & ! intent(in): choice of option for Richards' equation
                 mLayerMatricHead(1:nSoil),              & ! intent(in): matric head at the start of the time step (m)
                 mLayerMatricHeadTrial(1:nSoil),         & ! intent(in): trial value of matric head (m)
                 mLayerVolFracLiqTrial(nSnow+1:nLayers), & ! intent(in): trial value for the volumetric liquid water content in each soil layer (-)
                 mLayerVolFracIceTrial(nSnow+1:nLayers), & ! intent(in): trial value for the volumetric ice content in each soil layer (-)
                 dVolTot_dPsi0,                          & ! intent(in): derivative in the soil water characteristic (m-1)
                 specificStorage,                        & ! intent(in): specific storage coefficient (m-1)
                 theta_sat,                              & ! intent(in): soil porosity (-)
                 ! output:
                 mLayerCompress,                         & ! intent(out): compressibility of the soil matrix (-)
                 dCompress_dPsi,                         & ! intent(out): derivative in compressibility w.r.t. matric head (m-1)
                 err,cmessage)                             ! intent(out): error code and error message
 if(err/=0)then; message=trim(message)//trim(cmessage); return; end if  ! (check for errors)

 ! compute the total change in storage associated with compression of the soil matrix (kg m-2)
 scalarSoilCompress = sum(mLayerCompress(1:nSoil)*mLayerDepth(nSnow+1:nLayers))*iden_water


 ! compute the residual vector
 call computResid(&
                  ! input: model control
                  dt,                      & ! intent(in):    length of the time step (seconds)
                  nSnow,                   & ! intent(in):    number of snow layers
                  nSoil,                   & ! intent(in):    number of soil layers
                  nLayers,                 & ! intent(in):    total number of layers
                  canopyDepth,             & ! intent(in):    depth of the vegetation canopy (m)
                  computeVegFlux,          & ! intent(in):    flag to indicate if we need to compute fluxes over vegetation
                  ! input: flux vectors
                  sMul,                    & ! intent(in):    state vector multiplier (used in the residual calculations)
                  fluxVec,                 & ! intent(in):    flux vector
                  ! input: state variables (already disaggregated into scalars and vectors)
                  scalarCanairTempTrial,   & ! intent(in):    trial value for the temperature of the canopy air space (K)
                  scalarCanopyTempTrial,   & ! intent(in):    trial value for the temperature of the vegetation canopy (K)
                  scalarCanopyWatTrial,    & ! intent(in):    trial value of canopy total water (kg m-2)
                  mLayerTempTrial,         & ! intent(in):    trial value for the temperature of each snow and soil layer (K)
                  mLayerVolFracWatTrial,   & ! intent(in):    trial vector of volumetric total water content (-)
                  ! input: diagnostic variables defining the liquid water and ice content (function of state variables)
                  scalarCanopyIceTrial,    & ! intent(in):    trial value for the ice on the vegetation canopy (kg m-2)
                  mLayerVolFracIceTrial,   & ! intent(in):    trial value for the volumetric ice in each snow and soil layer (-)
                  ! input: data structures
                  prog_data,               & ! intent(in):    model prognostic variables for a local HRU
                  diag_data,               & ! intent(in):    model diagnostic variables for a local HRU
                  flux_data,               & ! intent(in):    model fluxes for a local HRU
                  indx_data,               & ! intent(in):    index data
                  ! output
                  resSink,                 & ! intent(out):   additional (sink) terms on the RHS of the state equation
                  resVec,                  & ! intent(out):   residual vector
                  err,cmessage)              ! intent(out):   error control
 if(err/=0)then; message=trim(message)//trim(cmessage); return; end if  ! (check for errors)


 ! compute the function evaluation
 rVecScaled = fScale(:)*real(resVec(:), dp)   ! scale the residual vector (NOTE: residual vector is in quadruple precision)
 fEval      = 0.5_dp*dot_product(rVecScaled,rVecScaled)

 ! end association with the information in the data structures
 end associate

 end subroutine eval8summa
end module eval8summa_module
