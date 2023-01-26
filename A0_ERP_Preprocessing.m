% Preprocessing script for ERP Decoding
% 
% EEGLAB & ERPLAB must be installed on MATLAB for the script to run. Replace "home_path" variable with the path for the main folder including the data
% & the scripts.

%% Start
% Clear memory and the command window.
clear
%Make sure all EEGLAB functions are on the MATLAB path
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;
close all
clc

%% Script Settings

% **********************************
% Set 1 to enable, 0 to disable
% **********************************

epoch_data    =     1;    % resample, rereference, LP & HP Filtering, event list, binlister, epoching

art_detect    =     1;    % Detect & reject artifacts

sum_ar_reject =     1;    % Prints a summary of artifact rejection results for all subjects

%% Subjects

subject_list = {'1163', '1164', '1168', '1182', '1184', '1185', '1221', '1223', '1226', '1230', '1233', '1234', '1235', '1237', '1248', '1255', '1261', '1262', '1279', '1280', '1161', '1165', '1169', '1170', '1172', '1174', '1176', '1177', '1178', '1179', '1180', '1181', '1183', '1220', '1222', '1224', '1225', '1227'};


%% Variables

%****REPLACE THIS PATH WITH THE LOCATION OF THE MAIN ANALYSIS FOLDER ON YOUR COMPUTER****

home_path  = '/Research/ERP_Decoding/FNC/';

%**************************************************************

ALLERP = buildERPstruct([]); % Initialize the ALLERP structure and CURRENTERP
CURRENTERP = 0;
nsubj = length(subject_list); % number of subjects
figScale = [ -500.0 2000.0   -500:10:2000 ]; % Figure intervals for ERP decoding

%% Epoch Data

if (epoch_data) 
    disp('Epoching Data');
    for s=1:nsubj % Loop through all subjects
        
        data_path  = [home_path 'Data/ContinousBEData/' subject_list{s} '/'];   % Path to the folder containing the current subject's data
        EEG = pop_loadset('filename',[subject_list{s} '.set'], 'filepath', data_path); 
        
        % resample to 250 hZ
        EEG = pop_resample( EEG, 250);
        EEG = eeg_checkset( EEG );

        %re-reference to average
        EEG = pop_chanedit(EEG, 'append',31,'changefield',{32 'labels' 'Cz'},'lookup',[home_path 'standard_BESA/standard-10-5-cap385.elp'],'setref',{'1:31' 'Cz'});
        EEG = pop_reref( EEG, [],'refloc',struct('labels',{'Cz'},'type',{''},'theta',{0},'radius',{0},'X',{5.2047e-15},'Y',{0},'Z',{85},'sph_theta',{0},'sph_phi',{90},'sph_radius',{85},'urchan',{32},'ref',{''},'datachan',{0}));
        EEG = pop_saveset(EEG, 'filename', [EEG.setname '.set'], 'filepath', data_path);
        
        % HP filter at 0.1 Hz
        EEG  = pop_basicfilter( EEG,  1:32 , 'Boundary', 'boundary', 'Cutoff', 0.1, 'Design', 'butter', 'Filter', 'highpass', 'Order',  2, 'RemoveDC', 'on' ); 
     
        % LP filter at 6 Hz
        EEG  = pop_basicfilter( EEG,  1:32 , 'Boundary', 'boundary', 'Cutoff', 6, 'Design', 'butter', 'Filter', 'lowpass', 'Order',  2, 'RemoveDC', 'on' ); 

        EEG = pop_saveset(EEG, 'filename', [EEG.setname '.set'], 'filepath', data_path);
        
        % create event list
        EEG  = pop_creabasiceventlist( EEG , 'AlphanumericCleaning', 'on', 'BoundaryNumeric', { -99 }, 'BoundaryString', { 'boundary' }, 'Eventlist', [data_path 'elist.txt'] );

        % assign events to bins with binlister
        EEG  = pop_binlister( EEG , 'BDF', [home_path 'BinFiles/' 'binDescriptor.txt'], 'ExportEL', [data_path 'elist.txt'], 'Ignore',  246, 'IndexEL',  1, 'SendEL2', 'EEG&Text', 'Voutput', 'EEG' );

        % epoch data
        EEG = pop_epochbin( EEG , [-500.0  2000.0],  'pre');
        EEG.setname=[subject_list{s} '_binned_be'];
        EEG = pop_saveset(EEG, 'filename', [EEG.setname '.set'], 'filepath', data_path);
    end
end


%% Artifact Detection

if(art_detect)
    disp('Artifact Detection');
    for s=1:nsubj % Loop through all subjects  
        
        data_path  = [home_path 'Data/ContinousBEData/' subject_list{s} '/'];   % Path to the folder containing the current subject's data
        EEG = pop_loadset('filename',[subject_list{s} '_binned_be.set'], 'filepath', data_path);

        EEG  = pop_artmwppth( EEG , 'Channel', [ 1 31], 'Flag',  1, 'Threshold',  60, 'Twindow', [ -500 496], 'Windowsize',  80, 'Windowstep',20 ); % Moving window, for eye blinks
        EEG  = pop_artstep( EEG , 'Channel',  1:31, 'Flag', [ 1 3], 'Threshold',  50, 'Twindow', [ -500 496], 'Windowsize',  200, 'Windowstep', 100 ); %Step-like for eye movements
               
        EEG.setname = [EEG.setname '_ar'];
        EEG = pop_saveset(EEG, 'filename', [EEG.setname '.set'], 'filepath', data_path);
        
        % report percentage of rejected trials (collapsed across all bins)
        artifact_proportion = getardetection(EEG);
        fprintf('%s: Percentage of rejected trials was %1.2f\n', subject_list{s}, artifact_proportion);
    end
end

%% Summarize Artifact Rejection
clc

if (sum_ar_reject)
    disp('Summarizing Artifact Rejection');
    for s=1:nsubj % Loop through all subjects
        data_path  = [home_path 'Data//ContinousBEData/' subject_list{s} '/'];   % Path to the folder containing the current subject's data
        EEG = pop_loadset('filename',[subject_list{s} '_binned_be_ar.set'], 'filepath', data_path);
        artifact_proportion = getardetection(EEG); %artifact stats for eeg
        fprintf('%s: Percentage of rejected trials was %1.2f\n', subject_list{s}, artifact_proportion);
    end
end

disp('**** FINISHED ****');

