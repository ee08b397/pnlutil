#!/usr/bin/env bash

set -eu
SCRIPT=$(readlink -m $(type -p $0))
SCRIPTDIR=$(dirname $SCRIPT)
source "$SCRIPTDIR/util.sh"

HELP="
Usage: 

   fs2bse.sh <dwi> <dwi_mask> <freesurfer_mri_dir> <output_dir>

where <dwi> and <dwi_mask> are nrrd/nhdr files
"

[ -n "${1-}" ] && [[ $1 == "-h" || $1 == "--help" ]] && usage 0
[ $# -lt 4 ] && usage 1

input_vars="dwi dwi_mask mri output_dir"
read -r $input_vars <<<"$@"
get_remotes ${input_vars% *}

check_set_vars ANTSPATH FREESURFER_HOME
export SUBJECTS_DIR=

log "Make and change to output directory"
run mkdir $output_dir || { log_fail "$output_dir already exists, delete it or choose another output folder name"; exit 1; }
run pushd $output_dir

log "Create brain.nii.gz and wmparc.nii.gz from their mgz versions"
#$fsbin/mri_convert -rt nearest --in_type mgz --out_type nii --out_orientation LPI $mri/wmparc.mgz $mri/wmparc.nii.gz
#$fsbin/mri_convert -rt nearest --in_type mgz --out_type nii --out_orientation LPI $mri/brain.mgz $mri/brain.nii.gz
run $FREESURFER_HOME/bin/mri_vol2vol --mov $mri/brain.mgz --targ $mri/brain.mgz --regheader --o brain.nii.gz
run $FREESURFER_HOME/bin//mri_label2vol --seg $mri/wmparc.mgz --temp $mri/brain.mgz --o wmparc.nii.gz --regheader $mri/wmparc.mgz

log "Create masked baseline"
bse=`basename ${dwi%%.*}-bse.nrrd`
maskedbse=`basename ${bse%%.*}-masked.nrrd`
unu slice -a 3 -p 0 -i $dwi | unu 3op ifelse $dwi_mask - 0 -o $maskedbse
log_success "Made masked baseline: '$maskedbse'"

log "Upsample masked baseline to 1x1x1: "
maskedbse1mm=`basename ${maskedbse%%.*}-1mm.nii.gz`
run $ANTSPATH/ResampleImageBySpacing 3 $maskedbse $maskedbse1mm 1 1 1 
log_success "Made masked baseline: '$maskedbse1mm'"

log "Compute warp from brain.nii.gz to upsampled baseline"
warp brain.nii.gz $maskedbse1mm "brain-to-bse-1mm-"
run mv brain-to-bse-1mm-deformed.nii.gz brain-in-bse-1mm.nii.gz 

log "Apply warp to wmparc.nii.gz to create wmparc-in-bse-1mm.nii.gz"
run $ANTSPATH/antsApplyTransforms -d 3 -i wmparc.nii.gz -o wmparc-in-bse-1mm.nrrd -r "$maskedbse1mm" -n NearestNeighbor -t brain-to-bse-1mm-Warp.nii.gz brain-to-bse-1mm-Affine.txt 
log_success "Created 'wmparc-in-bse-1mm.nii.gz'"

log "Downsample wmparc-in-bse-1mm.nii.gz to DWI's resolution"
new_size=$(unu head $maskedbse | grep "sizes:" | sed 's/sizes:\s*//')
run "unu resample -k cheap -s $new_size -i wmparc-in-bse-1mm.nrrd | unu save -e gzip -f nrrd -o wmparc-in-bse.nrrd"

popd
log_success "Made '$(readlink -f "$output_dir"/wmparc-in-bse.nrrd)'"
