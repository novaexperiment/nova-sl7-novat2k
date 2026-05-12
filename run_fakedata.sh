#!/bin/bash
# Runs make_fakedata.C inside the Singularity image.
# Output .root file is written to the current directory.
# Requires CVMFS access for the MC prediction files.
#
# Usage:
#   ./run_fakedata.sh <image.sif>                                           # asimov5 (default)
#   ./run_fakedata.sh <image.sif> asimov1                                   # named Asimov point
#   ./run_fakedata.sh <image.sif> custom false 2.509e-3 0.528 1.49          # custom osc parameters
#
# Named Asimov points: asimov0 .. asimov5
# Custom args:         <dmsq32>  <sin2th23>  <dcp_pi>
#   dmsq32   : Δm²₃₂ in eV² (negative for IO, e.g. -2.45e-3)
#   sin2th23 : sin²θ₂₃ (e.g. 0.528)
#   dcp_pi   : δ_CP / π  (e.g. 1.49)

if [ -z "$1" ]; then
  echo "Usage: $0 <image.sif> [label] [fakeormock] [dmsq32] [sin2th23] [dcp_pi]"
  exit 1
fi

IMAGE="${1}"
LABEL="${2:-asimov5}"
FAKEORMOCK="${3:-false}"
DMSQ32="${4:-2.44e-3}"
SIN2TH23="${5:-0.55}"
DCP_PI="${6:-0.87}"

JF_MC=/cvmfs/nova.osgstorage.org/analysis/novat2k/jf_2/fit_inputs/v0/jf_mc/

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

LOCAL_SCRIPT="${SCRIPT_DIR}/jointfit_novat2k/CAFAna/make_fakedata.C"
BIND_SCRIPT=""
if [ -f "${LOCAL_SCRIPT}" ]; then
  BIND_SCRIPT="-B ${LOCAL_SCRIPT}:/nova/jointfit_novat2k/CAFAna/make_fakedata.C"
fi

singularity exec \
  -B "${JF_MC}:/jf_mc" \
  ${BIND_SCRIPT} \
  "${IMAGE}" bash -c \
    "export JOINTFIT_DIR=/nova/jointfit_novat2k && cd $(pwd) && root -l -b -q \
      \$JOINTFIT_DIR/CAFAna/load_libs.C \
      \"\$JOINTFIT_DIR/CAFAna/make_fakedata.C++(\\\"${LABEL}\\\", ${FAKEORMOCK}, ${DMSQ32}, ${SIN2TH23}, ${DCP_PI})\""
