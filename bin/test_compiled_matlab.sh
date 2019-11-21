#!/bin/bash

xvfb-run --server-num=$(($$ + 99)) \
--server-args='-screen 0 1600x1200x24 -ac +extension GLX' \
bash run_spm12.sh /usr/local/MATLAB/MATLAB_Runtime/v92 function process_rois \
../INPUTS/roi.nii.gz \
../INPUTS/na.nii.gz \
../OUTPUTS \
UNK_PROJ \
UNK_SUBJ \
UNK_SESS \
UNK_SCAN

