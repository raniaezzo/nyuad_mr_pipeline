%% Follow instructions in README.MD PRIOR TO RUNNING SCRIPT.

%%
clear all; close all; clc
warning('off', 'MATLAB:MKDIR:DirectoryExists');
flywheel_group = 'rokerslab';
flywheel_project = 'vri_hfs';
bids_dir = '/Users/rje257/Desktop/BIDS_testing';
configfilePath = '/Users/rje257/Downloads/config_20230901.json';

fw_sdk_path = '/Applications/flywheel-sdk/';
addpath(genpath(fw_sdk_path));
javaaddpath(fullfile(fw_sdk_path,'api','rest-client.jar'));

% set up flywheel API; put key in specific location ($whoami)
% Download https://storage.googleapis.com/flywheel-dist/sdk/15.8.0/flywheel-matlab-sdk-15.8.0.zip
    % on cluster: conda create environment with latest dcm2bids, dcm2niix,
    % pydeface

[~, key] =system('echo $FLYWHEELAPI_KEY');

% download data from flywheel (via cluster?)
fw = flywheel.Client('flywheel.abudhabi.nyu.edu:9TUAoQWfoUuXDR3XzV');

% Return Project object
project = fw.lookup(fullfile(flywheel_group,flywheel_project));

% Return Subjects object with Project
subjects = project.subjects.find();

% return index of specific subject
SubjectName = 'Subject_0239';
subIdx = find(cell2mat(arrayfun(@(x) contains(subjects{x,1}.code,SubjectName), ...
    1 : numel(subjects), 'UniformOutput', false)));

subject_fwid = fw.get(subjects{subIdx,1}.id);
subject_id = subjects{subIdx,1}.code;
subject_id = strrep(subject_id, ' ', '_');

%% Set up BIDS directory

% check if BIDS dir exists, if not, create (with scaffold
if ~isfolder(bids_dir)
    mkdir(bids_dir)
    % run BIDS scaffolding here
end

sourcedatadir = fullfile(bids_dir,'sourcedata',subject_id);
mkdir(sourcedatadir)

% gather subject id (format ##) for BIDS purposes
subject_num = regexp(subject_id, '\d*', 'match');

if length(subject_num)>1
    error('Cannot identify unique alphanumeric subject nlabel')
else
    subject_num = subject_num{1};
end

%% Download the Subject (all files) to source directory:
tardir = fullfile(sourcedatadir,[subject_id,'.tar']);
fw.downloadTar([subject_fwid], tardir)

% untar files
disp('Untarring subject data. This may take several minutes . . .')
filenames = untar(tardir, fullfile(sourcedatadir,'tmpdir'));

% check for multiple sessions (inside Subject folder)
sessions = dir(fullfile(sourcedatadir,'tmpdir', '**',subject_id));
sessions = sessions(~ismember({sessions.name},{'.','..','.DS_Store'}));

%% UNZIPPING + MOVING

% move to parent folder since dcm2bids only checks 5 layers deep
% parallel paths are treated as separate sessions 
for si=1:numel(sessions)

    ses_num = num2str(si);
    if length(ses_num) < 2; ses_num = strcat('0',ses_num); end
    movefile(fullfile(sessions(si).folder, sessions(si).name, '*'), ...
        fullfile(sourcedatadir, sprintf('ses%s',ses_num)));

    % unzip files that are still compressed
    disp('Unzipping any compressed dicoms. Please wait . . .')
    zippedFiles = dir(fullfile(sourcedatadir, sprintf('ses%s',ses_num), '**/*.zip'));
    D = arrayfun(@(x) unzip(fullfile(zippedFiles(x).folder, zippedFiles(x).name), ...
        fullfile(zippedFiles(x).folder)), 1 : numel(zippedFiles), 'UniformOutput', false);
end

    
%% DCM2BIDS
for si=1:numel(sessions)
    
    ses_num = num2str(si);
    if length(ses_num) < 2; ses_num = strcat('0',ses_num); end
    sessionsource = fullfile(sourcedatadir, sprintf('ses%s',ses_num));

    % run dcm2bids (use master config file - latest version)
    % this will also run pydeface
    cmd = sprintf("dcm2bids -d %s -o %s -p %s -s %s -c %s --clobber", ...
        sessionsource, bids_dir, subject_num, ses_num, configfilePath);
    
    [status, cmdout] = system(cmd, '-echo');
end

%% SBREF COPY
for si=1:1 %1:numel(sessions)
    
    ses_num = num2str(si);
    if length(ses_num) < 2; ses_num = strcat('0',ses_num); end
    % copy SBREF to every run in session (keep in mind there is nii.gz and .json)
    % doing this to ensure fMRIprep account for the sbrefs for each run
    bids_func_dir = fullfile(bids_dir, ['sub-', subject_num], ['ses-',ses_num], 'func');
    
    filetypes = {'.json', '.nii.gz'};
    
    for fi=1:numel(filetypes)
        filetype = filetypes{fi};
        ap_sbref_list = dir(fullfile(bids_func_dir, sprintf('*dir-ap_*sbref*%s', filetype)));
        pa_sbref_list = dir(fullfile(bids_func_dir, sprintf('*dir-pa_*sbref*%s', filetype)));
    
        % for rare cases which multiple sbref (unneccesary)
        ap_sbref = ap_sbref_list(1);
        pa_sbref = pa_sbref_list(1);

        % big fix it: this includes some of the sbref
        task_runs = dir(fullfile(bids_func_dir, sprintf('*task*%s', filetype)));
    
        for ii=1:numel(task_runs)
            try
                if contains(task_runs(ii).name, 'dir-AP', IgnoreCase=true)
                    copyfile(fullfile(ap_sbref.folder, ap_sbref.name), ...
                        fullfile(task_runs(ii).folder, strrep(task_runs(ii).name, '_bold', '_sbref')))
                elseif contains(task_runs(ii).name, 'dir-PA', IgnoreCase=true)
                    copyfile(fullfile(pa_sbref.folder, pa_sbref.name), ...
                        fullfile(task_runs(ii).folder, strrep(task_runs(ii).name, '_bold', '_sbref')))
                end
            catch
               sprintf('Skipping %s', task_runs(ii).name)
               sprintf('Either already converted of sbref not found.')
            end
        end
    
        % delete redundant files
        for dd=1:numel(ap_sbref_list)
            delete(fullfile(ap_sbref_list(dd).folder, ap_sbref_list(dd).name))
            delete(fullfile(pa_sbref_list(dd).folder, pa_sbref_list(dd).name))
        end
    
    end

end

%% clean up: delete leftover files

rmdir(fullfile(sourcedatadir,'tmpdir'), 's')
delete(tardir); 

%% Validating BIDS

cmd = sprintf("bids-validator %s", bids_dir);

[status, cmdout] = system(cmd, '-echo');
