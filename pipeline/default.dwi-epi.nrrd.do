#!/bin/bash -eu

source scripts-pipeline/util.sh
inputvars="\
    dwiepi_dwi \
    dwiepi_dwimask \
    dwiepi_t2 \
    dwiepi_t2mask \
    "
setupdo $@
scripts-pipeline/epi.sh $(varvalues $inputvars) $3
log_success "Made '$1'"
