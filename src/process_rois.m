function process_rois( ...
	roi_full_filename, ...
	na_full_filename, ...
	out_dir, ...
	project, ...
	subject, ...
	session, ...
	scan ...
	)


%% We'll use a couple of java libraries to compute file hashes
import java.security.*
import java.math.*


%% SPM prep
spm('Defaults','fMRI');
spm_jobman('initcfg');
spm_figure('Create','Graphics','SPM12');


%% Hash the files and get base filenames

% ROI file
fid = fopen(roi_full_filename,'r');
f = fread(fid,inf,'uint8');
fclose(fid);
md = MessageDigest.getInstance('SHA1');
hash = md.digest(f);
bi = BigInteger(1, hash);
roi_file_sha1 = char(bi.toString(16));
[~,n,e] = fileparts(roi_full_filename);
namri_roi_filename = [n e];

% Sodium image
fid = fopen(na_full_filename,'r');
f = fread(fid,inf,'uint8');
fclose(fid);
md = MessageDigest.getInstance('SHA1');
hash = md.digest(f);
bi = BigInteger(1, hash);
na_file_sha1 = char(bi.toString(16));
[~,n,e] = fileparts(na_full_filename);
namri_na_filename = [n e];



%% Unzip the files to out_dir

% ROI
copyfile(roi_full_filename,out_dir);
[~,roi_n,roi_e] = fileparts(roi_full_filename);
system(['gunzip -f ' out_dir filesep roi_n roi_e])
roi_full_filename = fullfile(out_dir,roi_n);

% Na
copyfile(na_full_filename,out_dir);
[~,na_n,na_e] = fileparts(na_full_filename);
system(['gunzip -f ' out_dir filesep na_n na_e])
na_full_filename = fullfile(out_dir,na_n);


%% Interpolate the sodium image to ROI image space

clear matlabbatch
matlabbatch{1}.spm.spatial.coreg.write.ref = {roi_full_filename};
matlabbatch{1}.spm.spatial.coreg.write.source = {na_full_filename};
matlabbatch{1}.spm.spatial.coreg.write.roptions.interp = 1;
matlabbatch{1}.spm.spatial.coreg.write.roptions.wrap = [0 0 0];
matlabbatch{1}.spm.spatial.coreg.write.roptions.mask = 0;
matlabbatch{1}.spm.spatial.coreg.write.roptions.prefix = 'r';
spm_jobman('run',matlabbatch);

na_interp_filename = fullfile(out_dir,['r' na_n]);



%% Load the two images

Vroi = spm_vol(roi_full_filename);
Vna = spm_vol(na_interp_filename);
spm_check_orientations([Vroi; Vna]);

Yroi = spm_read_vols(Vroi);
Yna = spm_read_vols(Vna);

if length(unique(Yroi(:))) ~= 12
	error(['Wrong number of ROI values in ' roi_full_filename])
end



%% Compute ROI statistics
% Is there a better way to do this than this stupid 'eval' trick? Who knows

% Fields for REDCap:
%    analysis_datetime
%    analyst (VUIIS Core is "2")
%    pipeline (3D Slicer is "1")
%    roi_filename
%    roi_file_sha1
%    na_filename
%    na_file_sha1
%    scan_id
%    cal_intercept
%    cal_slope
%    cal_rsq
%
% And for each ROI:
%    <roi>_mean_raw
%    <roi>_median_raw
%    <roi>_stddev_raw
%    <roi>_mean_mm
%    <roi>_median_mm
%    <roi>_stddev_mm


% List of ROIs. Note - the number each one has in the image is hardcoded by
% the order in teh roilist variable! Our ROI list on REDCap is:
%     1  ph10
%     2  ph20
%     3  ph30
%     4  ph40
%     5  antcomp
%     6  peroneus
%     7  soleus
%     8  medgastroc
%     9  latgastroc
%    10  allmuscle
%    11  skin
%    12  bkgndnoise
roilist = { ...
	'ph10' ...
	'ph20' ...
	'ph30' ...
	'ph40' ...
	'antcomp' ...
	'peroneus' ...
	'soleus' ...
	'medgastroc' ...
	'latgastroc' ...
	'allmuscle' ...
	'skin' ...
	'bkgndnoise' ...
	};

% First the raw values. Skip #10 (allmuscle) because it's special
for r = [1:9 11:12]
	eval(['namri_' roilist{r} '_mean_raw = mean( Yna( Yroi(:)==' num2str(r) ' ) );']);
	eval(['namri_' roilist{r} '_median_raw = median( Yna( Yroi(:)==' num2str(r) ' ) );']);
	eval(['namri_' roilist{r} '_stddev_raw = std( Yna( Yroi(:)==' num2str(r) ' ) );']);
end

% For the "All Muscle" ROI, we have to create it first
Yall = zeros(size(Yroi));
Yall( ...
	Yroi(:)==5 | ...
	Yroi(:)==6 | ...
	Yroi(:)==7 | ...
	Yroi(:)==8 | ...
	Yroi(:)==9 ) ...
	= 1;
namri_allmuscle_mean_raw = mean( Yna( Yall(:)==1 ) );
namri_allmuscle_median_raw = median( Yna( Yall(:)==1 ) );
namri_allmuscle_stddev_raw = std( Yna( Yall(:)==1 ) );



%% Compute modes (histogram peaks) for each ROI
for r = 1:12
    if r==10
        [f,xi] = ksdensity(Yna(Yall(:)==1),'npoints',10000,'kernel','normal');
    else
        [f,xi] = ksdensity(Yna(Yroi(:)==r),'npoints',10000,'kernel','normal');
    end    
    peak = xi(f==max(f));
    if length(peak) ~= 1
        peak = nan;
    end
    eval(['namri_' roilist{r} '_mode_raw = peak;']);
end


% Now do the calibration fit
x = [10 20 30 40]';
y = [namri_ph10_mean_raw namri_ph20_mean_raw namri_ph30_mean_raw namri_ph40_mean_raw]';
P = polyfit(x,y,1);
namri_cal_slope = P(1);
namri_cal_intercept = P(2);
namri_cal_rsq = corr(x,y).^2;

% Now the mM values
for r = 1:length(roilist)
	eval(['namri_' roilist{r} '_mean_mm = (namri_' roilist{r} '_mean_raw - namri_cal_intercept) / namri_cal_slope;']);
	eval(['namri_' roilist{r} '_median_mm = (namri_' roilist{r} '_median_raw - namri_cal_intercept) / namri_cal_slope;']);
	eval(['namri_' roilist{r} '_mode_mm = (namri_' roilist{r} '_mode_raw - namri_cal_intercept) / namri_cal_slope;']);
	eval(['namri_' roilist{r} '_stddev_mm = (namri_' roilist{r} '_stddev_raw - namri_cal_intercept) / namri_cal_slope;']);
end


%% Couple of remaining fields to set
namri_analyst = '2';
namri_pipeline = '1';
namri_analysis_datetime = datestr(now,'yyyy-mm-dd HH:MM:SS');


%% Organize results as a table for the new style REDCap csv
outcsv = table( ...
	namri_analysis_datetime, ...
	namri_analyst, ...
	namri_pipeline, ...
	namri_roi_filename, ...
	roi_file_sha1, ...
	namri_na_filename, ...
	na_file_sha1, ...
	namri_cal_intercept, ...
	namri_cal_slope, ...
	namri_cal_rsq);
for r = 1:length(roilist)
	outcsv.(['namri_' roilist{r} '_mean_raw']) = eval(['namri_' roilist{r} '_mean_raw']);
	outcsv.(['namri_' roilist{r} '_median_raw']) = eval(['namri_' roilist{r} '_median_raw']);
	outcsv.(['namri_' roilist{r} '_mode_raw']) = eval(['namri_' roilist{r} '_mode_raw']);
	outcsv.(['namri_' roilist{r} '_stddev_mm']) = eval(['namri_' roilist{r} '_stddev_raw']);
	outcsv.(['namri_' roilist{r} '_mean_mm']) = eval(['namri_' roilist{r} '_mean_mm']);
	outcsv.(['namri_' roilist{r} '_median_mm']) = eval(['namri_' roilist{r} '_median_mm']);
	outcsv.(['namri_' roilist{r} '_mode_mm']) = eval(['namri_' roilist{r} '_mode_mm']);
	outcsv.(['namri_' roilist{r} '_stddev_mm']) = eval(['namri_' roilist{r} '_stddev_mm']);
end

csv_file = fullfile(out_dir,'stats.csv');
writetable(outcsv,csv_file);



%% PDF report

infostring2 = [ ...
	sprintf('Report for %s, %s, %s, %s\n',project,subject,session,scan) ...
	sprintf('namri_analysis_datetime="%s"\n',namri_analysis_datetime) ...
	sprintf('namri_analyst=%s\n',namri_analyst) ...
	sprintf('namri_pipeline=%s\n',namri_pipeline) ...
	sprintf('namri_roi_filename=%s\n',namri_roi_filename) ...
	sprintf('namri_roi_file_sha1=%s\n',roi_file_sha1) ...
	sprintf('namri_na_filename=%s\n',namri_na_filename) ...
	sprintf('namri_na_file_sha1=%s\n',na_file_sha1) ...
	sprintf('namri_cal_intercept=%0.8f\n',namri_cal_intercept) ...
	sprintf('namri_cal_slope=%0.8f\n',namri_cal_slope) ...
	sprintf('namri_cal_rsq=%0.4f\n',namri_cal_rsq) ...
	];
for r = 1:length(roilist)
	eval(['infostring2 = [infostring2 ' ...
		'sprintf(''namri_' roilist{r} '_mean_mm=%0.2f\n'',namri_' roilist{r} '_mean_mm)];'])
end


pdf_figure = openfig('sodium_leg_pdf.fig','new');
set(pdf_figure,'Tag','sodium_leg_pdf');
figH = guihandles(pdf_figure);

% Summary
set(figH.results_text, 'String', infostring2)

% Scan info
set(figH.scan_info, 'String', sprintf( ...
	'Project %s ;  Subject %s ;  Session %s ;  Scan %s', ...
	project, subject, session, scan));
set(figH.date,'String',['Report date: ' date]);
set(figH.version,'String',['Matlab version: ' version]);

% Image slice
slice = 3;

mapgray = colormap('gray');
naimg = ind2rgb( gray2ind( mat2gray(Yna(:,:,slice)), size(mapgray,1) ), mapgray );

mapcolor = colormap('jet');
roiimg = ind2rgb( gray2ind( mat2gray(Yroi(:,:,slice)), size(mapcolor,1) ), mapcolor );
roialpha = zeros(size(Yroi(:,:,slice)));
roialpha(Yroi(:,:,slice)>0) = 0.5;

axes(figH.image)
imshow(naimg,'InitialMagnification','fit')
hold on
Iroi = imshow(roiimg);
set(Iroi,'AlphaData',roialpha)

% Print
pdf_file = fullfile(out_dir,'manual_seg_report.pdf');
print(pdf_figure,'-dpdf',pdf_file)




%% Zip the nii file back up
%system(['gzip -f ' roi_full_filename]);
%system(['gzip -f ' na_full_filename]);
system(['gzip -f ' na_interp_filename]);



