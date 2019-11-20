#!/bin/bash

bash run_spm12.sh /usr/local/MATLAB/MATLAB_Runtime/v92 function process_rois \
../INPUTS/roi.nii.gz \
../INPUTS/na.nii.gz \
../OUTPUTS \
UNK_PROJ \
UNK_SUBJ \
UNK_SESS \
UNK_SCAN

