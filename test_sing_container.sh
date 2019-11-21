#!/bin/bash

singularity run \
--cleanenv \
--home `pwd`/INPUTS \
--bind INPUTS:/INPUTS \
--bind OUTPUTS:/OUTPUTS \
baxpr-naleg-roi-master-v1.0.0.simg \
/INPUTS/roi.nii.gz \
/INPUTS/na.nii.gz \
/OUTPUTS \
UNK_PROJ \
UNK_SUBJ \
UNK_SESS \
UNK_SCAN
