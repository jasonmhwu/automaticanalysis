% AA module - coregister structural to mean EPI
% Coregistration of structural to mean EPI output by realignment
% Does not require skull stripping any more
% Modified for sparse imaging since prefix for mean is different
% i=subject num
% Rhodri Cusack MRC CBU 2004-6 based on original by Matthew Brett
% 
% Major changes Aug 2010: removed support for central store of structrual
% images. This code was very long in tooth, and unloved.
%
% Tibor Auer MRC CBU Cambridge 2012-2013

function [aap,resp] = aamod_coreg_noss(aap, task, subjInd)

resp='';

switch task
	case 'report' % [TA]
        if ~exist(fullfile(aas_getsubjpath(aap,subjInd),['diagnostic_' aap.tasklist.main.module(aap.tasklist.currenttask.modulenumber).name '_structural2meanepi.jpg']),'file')
            fsl_diag(aap,subjInd);
        end
        fdiag = dir(fullfile(aas_getsubjpath(aap,subjInd),'diagnostic_*.jpg'));
        for d = 1:numel(fdiag)
            aap = aas_report_add(aap,subjInd,'<table><tr><td>');
            aap=aas_report_addimage(aap,subjInd,fullfile(aas_getsubjpath(aap,subjInd),fdiag(d).name));
            aap = aas_report_add(aap,subjInd,'</td></tr></table>');
        end
    case 'doit'
        global defaults;
        flags = defaults.coreg;
        % check local structural directory exists
        subjpath=aas_getsubjpath(aap,subjInd);
        structdir=fullfile(subjpath,aap.directory_conventions.structdirname);
        if (~length(dir(structdir)))
            [s w]=aas_shell(['mkdir ' structdir]);
            if (s)
                aas_log(aap,1,sprintf('Problem making directory%s',structdir));
            end;
        end;
        
        % get mean EPI stream
        inStream = aap.tasklist.currenttask.inputstreams.stream{2};
        meanepiImg = aas_getfiles_bystream(aap, subjInd, inStream);                
        VG = spm_vol(meanepiImg);
       
        % Get path to structural for this subject
        inStream = aap.tasklist.currenttask.inputstreams.stream{1};
        outStream = aap.tasklist.currenttask.outputstreams.stream{1};
        structImg = aas_getfiles_bystream(aap, subjInd, inStream);                
        VF = spm_vol(structImg);

        % do coregistration
        x  = spm_coreg(VG, VF,flags.estimate);
        
        spm_get_space(structImg, spm_matrix(x)\spm_get_space(structImg));
       
        aap = aas_desc_outputs(aap, subjInd, outStream, structImg);

        % Save graphical output - this will now be done by report task
        try
            figure(spm_figure('FindWin', 'Graphics'));
        catch
            figure(1);
        end
        if strcmp(aap.options.wheretoprocess,'localsingle') % printing SPM Graphics does not work parallel
            print('-djpeg','-r75',fullfile(aas_getsubjpath(aap, subjInd),'diagnostic_aamod_coreg'));
        end

        % Reslice images
        try
            fsl_diag(aap,subjInd);
        catch
            aas_log(aap, 0, 'Error running diagnostics for aamod_coreg_noss, but coregistration completed ok.');
        end
            
	case 'checkrequirements'
        
end
end

function fsl_diag(aap,i)
fP = aas_getfiles_bystream(aap,i,'meanepi');
subj_dir=aas_getsubjpath(aap,i);

inStream = aap.tasklist.currenttask.inputstreams.stream{1};

sP = aas_getfiles_bystream(aap,i,inStream);
spm_reslice({fP,sP},aap.spm.defaults.coreg.write)
delete(fullfile(fileparts(fP),['mean' basename(fP) '.nii']));
% Create FSL-like overview
rfP = fullfile(fileparts(fP),[aap.spm.defaults.coreg.write.prefix basename(fP) '.nii']);
rsP = fullfile(fileparts(sP),[aap.spm.defaults.coreg.write.prefix basename(sP) '.nii']);
iP = fullfile(subj_dir,['diagnostic_' aap.tasklist.main.module(aap.tasklist.currenttask.modulenumber).name '_structural2meanepi']);
aas_runfslcommand(aap,sprintf('slices %s %s -s 3 -o %s.gif',rfP,rsP,iP));
[img,map] = imread([iP '.gif']); s3 = size(img,1)/3;
img = horzcat(img(1:s3,:,:),img(s3+1:2*s3,:,:),img(s3*2+1:end,:,:));
imwrite(img,map,[iP '.jpg']); delete([iP '.gif']);
iP = fullfile(subj_dir,['diagnostic_' aap.tasklist.main.module(aap.tasklist.currenttask.modulenumber).name '_meanepi2structural']);
aas_runfslcommand(aap,sprintf('slices %s %s -s 3 -o %s.gif',rsP,rfP,iP));
[img,map] = imread([iP '.gif']); s3 = size(img,1)/3;
img = horzcat(img(1:s3,:,:),img(s3+1:2*s3,:,:),img(s3*2+1:end,:,:));
imwrite(img,map,[iP '.jpg']); delete([iP '.gif']);
% Clean
delete(rsP); delete(rfP);
end

