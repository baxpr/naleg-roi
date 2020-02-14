function process_without_dixon(na_niigz,roi_niigz)
% Quick processing for manual allmuscle and skin ROIs if we don't have a
% Dixon image for the full pipeline. Inputs are nifti filenames

% Load files and check that geometry matches
Vna = spm_vol(na_niigz);
Yna = spm_read_vols(Vna);

Vroi = spm_vol(roi_niigz);
Yroi = spm_read_vols(Vroi);

spm_check_orientations([Vna;Vroi]);

% Check for needed ROI values
uroi = unique(Yroi(:));
uroi = uroi(uroi~=0);
if ~all(uroi==[1 2 3 4 10 11]')
	error('Issue with ROI values')
end

% Show the images
figure(1); clf
subplot(1,2,1)
imagesc(Yna(:,:,4)')
axis image off
subplot(1,2,2)
imagesc(Yroi(:,:,4)')
axis image off

% Extract ROI means
vals = table(uroi,'VariableNames',{'Label'});
vals.Name{vals.Label==1} = 'ph10';
vals.Name{vals.Label==2} = 'ph20';
vals.Name{vals.Label==3} = 'ph30';
vals.Name{vals.Label==4} = 'ph40';
vals.Name{vals.Label==10} = 'allmuscle';
vals.Name{vals.Label==11} = 'skin';

for h = 1:height(vals)
	vals.mean_raw(h,1) = mean(Yna(Yroi(:)==vals.Label(h)));
end

% Calibration vs phantoms
x = [10 20 30 40]';
y = [ ...
	vals.mean_raw(strcmp(vals.Name,'ph10')) ...
	vals.mean_raw(strcmp(vals.Name,'ph20')) ...
	vals.mean_raw(strcmp(vals.Name,'ph30')) ...
	vals.mean_raw(strcmp(vals.Name,'ph40')) ...
	]';
p = polyfit(x,y,1);
cal_slope = p(1);
cal_intercept = p(2);
cal_rsq = corr(x,y).^2;

vals.mean_mm = (vals.mean_raw - cal_intercept) / cal_slope;

% Report result
fprintf('\nNa file:  %s\nROI file: %s\n\n',na_niigz,roi_niigz)
fprintf('cal_slope:       %f\ncal_intercept:  %f\ncal_rsq:         %f\n\n', ...
cal_slope,cal_intercept,cal_rsq)
disp(vals)


