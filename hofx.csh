#!/bin/csh -f

date

# Process arguments
# =================
## args
# ArgMember: int, ensemble member [>= 1]
set ArgMember = "$1"

# ArgDT: int, valid forecast length beyond CYLC_TASK_CYCLE_POINT in hours
set ArgDT = "$2"

# ArgStateType: str, FC if this is a forecasted state, activates ArgDT in directory naming
set ArgStateType = "$3"

## arg checks
set test = `echo $ArgMember | grep '^[0-9]*$'`
set isNotInt = ($status)
if ( $isNotInt ) then
  echo "ERROR in $0 : ArgMember ($ArgMember) must be an integer" > ./FAIL
  exit 1
endif
if ( $ArgMember < 1 ) then
  echo "ERROR in $0 : ArgMember ($ArgMember) must be > 0" > ./FAIL
  exit 1
endif

set test = `echo $ArgDT | grep '^[0-9]*$'`
set isNotInt = ($status)
if ( $isNotInt ) then
  echo "ERROR in $0 : ArgDT must be an integer, not $ArgDT"
  exit 1
endif

# Setup environment
# =================
source config/experiment.csh
source config/filestructure.csh
source config/tools.csh
source config/modeldata.csh
source config/mpas/variables.csh
source config/builds.csh
source config/environment.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = `$advanceCYMDH ${thisCycleDate} ${ArgDT}`
source ./getCycleVars.csh

# templated work directory
set self_WorkDir = $WorkDirsTEMPLATE[$ArgMember]
if ($ArgDT > 0 || "$ArgStateType" =~ *"FC") then
  set self_WorkDir = $self_WorkDir/${ArgDT}hr
endif
echo "WorkDir = ${self_WorkDir}"
cd ${self_WorkDir}

# other templated variables
set self_StateDir = $inStateDirsTEMPLATE[$ArgMember]
set self_StatePrefix = inStatePrefixTEMPLATE

# Remove old logs
rm jedi.log*

# ================================================================================================

## copy static fields
rm ${localStaticFieldsPrefix}*.nc
rm ${localStaticFieldsPrefix}*.nc-lock
set localStaticFieldsFile = ${localStaticFieldsFileOuter}
rm ${localStaticFieldsFile}
set StaticMemDir = `${memberDir} ensemble $ArgMember "${staticMemFmt}"`
set memberStaticFieldsFile = ${StaticFieldsDirOuter}${StaticMemDir}/${StaticFieldsFileOuter}
ln -sfv ${memberStaticFieldsFile} ${localStaticFieldsFile}${OrigFileSuffix}
cp -v ${memberStaticFieldsFile} ${localStaticFieldsFile}

# Link/copy bg from other directory + ensure that MPASJEDIDiagVariables are present
# =================================================================================
set bg = ./${bgDir}
set an = ./${anDir}
mkdir -p ${bg}
mkdir -p ${an}

set bgFileOther = ${self_StateDir}/${self_StatePrefix}.$fileDate.nc
set bgFile = ${bg}/${BGFilePrefix}.$fileDate.nc

rm ${bgFile}
ln -sfv ${bgFileOther} ${bgFile}

# keep a link in place for transparency
rm ${bgFile}${OrigFileSuffix}
ln -sfv ${bgFileOther} ${bgFile}${OrigFileSuffix}

# Remove existing analysis file, then link to bg file
# ===================================================
set anFile = ${an}/${ANFilePrefix}.$fileDate.nc
rm ${anFile}

set copyDiags = 0
foreach var ({$MPASJEDIDiagVariables})
  ncdump -h ${bgFileOther} | grep -q $var
  if ( $status != 0 ) then
    @ copyDiags++
    echo "Copying MPASJEDIDiagVariables to background state"
  endif 
end
if ( $copyDiags > 0 ) then
  echo "Copy diagnostic variables used in HofX to bg"
  # ===============================================
  set diagFile = ${self_StateDir}/${DIAGFilePrefix}.$fileDate.nc
  rm ${bgFile}
  cp -v ${bgFile}${OrigFileSuffix} ${bgFile}
  ncks -A -v ${MPASJEDIDiagVariables} ${diagFile} ${bgFile}
endif

# use the background as the TemplateFieldsFileOuter
ln -sfv ${bgFile} ${TemplateFieldsFileOuter}

# Run the executable
# ==================
ln -sfv ${HofXBuildDir}/${HofXEXE} ./
mpiexec ./${HofXEXE} $appyaml ./jedi.log >& jedi.log.all


# Check status
# ============
#grep "Finished running the atmosphere core" log.atmosphere.0000.out
grep 'Run: Finishing oops.* with status = 0' jedi.log
if ( $status != 0 ) then
  touch ./FAIL
  echo "ERROR in $0 : jedi application failed" >> ./FAIL
  exit 1
endif

## change static fields to a link, keeping for transparency
rm ${localStaticFieldsFile}
rm ${localStaticFieldsFile}${OrigFileSuffix}
ln -sfv ${memberStaticFieldsFile} ${localStaticFieldsFile}

date

exit 0
