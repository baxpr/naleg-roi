%% ROI data extraction for sodium leg images
%
% Dependencies:
%     SPM12
%     gunzip, gzip (via system call)


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Info needed from XNAT

% ROI file, which was manually created and is the ROI_IMAGE resource of the
% 1H_FFE_mDixon scan
roi_full_filename = '../INPUTS/labels.nii.gz';

% Sodium image file, the NIFTI resource of the 23Na_3D_TR130 scan
na_full_filename = '../INPUTS/na.nii.gz';

% Pass in project etc also
project = 'TESTPROJ';
subject = 'TESTSUBJ';
session = 'TESTSESS';
scan = 'TESTSCAN';
out_dir = '../OUTPUTS';


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Outputs
%
% r<na_filestem>.nii.gz :         na_resamp_file, resampled sodium image.
%                                 Save to the NA_RESAMP resource of the
%                                 23Na_3D_TR130 scan.
%
% process_rois_redcap_data.txt :  redcap_file, the REDCap data. Save to a
%                                 resource (ROI_VALUES?) of the
%                                 23Na_3D_TR130 scan. Also sync to the
%                                 REDCap project "Leg Sodium Results"



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Processing
process_rois( ...
	roi_full_filename, ...
	na_full_filename, ...
	out_dir, ...
	project, ...
	subject, ...
	session, ...
	scan ...
	);

