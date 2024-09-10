%% pTripolar Panoramic ECAP Data Collection Script for Advanced Bionics
% 
% Garcia et al 2021 described a method for estimating neural activation
% patterns and separating current spread and neural health variation along
% the length of an electrode array for individual Cochlear Implant (CI) 
% users. This method requires measuring Electrically-Evoked Compound
% Action-Potentials (ECAPs) using the Forward-Masking Artefact-Reduction
% Technique for every combination of masker and probe electrodes at the
% Maximum Comfortable Level (MCL).
% Stimulating in tripolar mode wherein the current is returned partially to
% the two adjacent electrodes on either side of the stimulating electrode
% instead of entirely to the ground electrode, is hypothesized to focus the
% current at the central stimulating electrode in cochlear implant users,
% and may reduce channel interaction. As such, it is hypothesized that a
% local reduction in current spread would be observable in the current
% spread estimate of the PECAP method if ECAPs were recorded using partial
% tripolar stimulation on specific electrodes. Prior to running this script
% MP_PECAP_DAQ.m must be run in order to collect the standard, monopolar
% PECAP matrix. This script then calls a loudness GUI that allows the user
% to scale the loudness of two electrodes to stimulate in partial tripolar 
% (pTP) mode, starting with full tripolar (alpha = 1) and allowing for
% alpha adjustments. Once the loudness levels have been determined, one row
% and column of the PECAP matrix are recorded for each electrode for the 
% highest alpha level that it was possible to achieve MCL with on each 
% electrode. These ECAPs are then combined with the Monopolar PECAP matrix
% in order to create a full 'pTPECAP' matrix for each of the two
% electrodes.
%
% This script pTP_Loudness_DAQ.m is 1 of 2 and includes the loudness-
% scaling portion of the experiment, in partial Tripolar mode. It must be
% run before pTPECAP_DAQ.m. 
%
% Required Software: 
%       - Bionic Ear Data Collection System (BEDCS) version 1.8
%       - MATLAB 2018a
%         Note: this script may work with other versions of MATLAB but the
%               only version that has been debugged / checked is 2018a
% Required Hardware:
%       - Advanced Bionics Research Hardware required for measuring ECAPs
%         (i.e. a Clarion Programming Cable, Programming Interface, 
%         associated Power Supply, Advanced Bionics
%       - Optional: Advanced Bionics Load board (for testing prior to use
%         with a patient)
%
% Note: This script does not include checks to confirm that stimulation
% levels are presented to the CI patient within compliance. Please check
% this using separate software prior to use.
%
% Usage Disclaimer: Users of this script accept responsibility for safety
% checks undertaken whilst testing with CI patients. The developers of this
% software and their institutions (The MRC Cognition & Brain Sciences Unit
% and the University of Cambridge) accept no responsibility for the safety
% of the application of this script outside their institution. 
%
% Reference:
% (If you use this software, please cite the following publication that
% contains details of how the updated PECAP2 method works)
% Garcia, C., Goehring, T., Cosentino, S. et al. The Panoramic ECAP Method: 
% Estimating Patient-Specific Patterns of Current Spread and Neural Health 
% in Cochlear Implant Users. JARO (2021). 
% https://doi.org/10.1007/s10162-021-00795-2
%
% We hope you will find the software useful, but neither the authors nor
% their employers accept any responsibility for the consequencies of its
% use. The USER is responsible for ensuring the saftety of any subjects
% during testing.
%
% legal disclaimer from the University of Cambridge:
% The Software is the result work conducted within the MRC Cognition & 
% Brain Sciences unit at the University of Cambridge (the “University”)
% "The Software shall be used for non-commercial research purposes only.  
% The USER will not reverse engineer, manufacture, sell or sublicense for 
% manufacture and sale upon a commercial basis the Software, incorporate it 
% into other software or products or use the Software other than herein 
% expressly specified. The USER agrees that it will not translate, alter, 
% decompile, disassemble, reverse engineer, reverse compile, attempt to 
% derive, or reproduce source code from the Software. The USER also agrees 
% that it will not remove any copyright or other proprietary or product 
% identification notices from the Software. The Software is provided 
% without warranty of merchantability or fitness for a particular purpose 
% or any other warranty, express or implied, and without any representation 
% or warranty that the use or supply of the Software will not infringe any 
% patent, copyright, trademark or other right. In no event shall the 
% University or their staff and students be liable for any use by the USER 
% of the Software. The supply of the Software does not grant the USER any 
% title or interest in and to the Software, the related source code, and 
% any and all associated patents, copyrights, and other intellectual 
% property rights. The University and their staff and students reserve the 
% right to revise the Software and to make changes therein from time to 
% time without obligation to notify any person or organisation of such 
% revision or changes. While the University will make every effort to 
% ensure the accuracy of Software and the data contained therein, however 
% neither the University nor its employees or agents may be held 
% responsible for errors, omissions or other inaccuracies or any 
% consequences thereof."

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Script Developed by Charlotte Garcia, 2021                             %
% Loudness-Scaling GUI provided by Francois Guerit                       %
% MRC Cognition & Brain Sciences Unit, Cambridge, UK                     %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%% Add source files to path
[current_path, ~, ~] = fileparts(mfilename('fullpath'));
addpath(fullfile(current_path, 'source'))
clear current_path


%% pTP Parameters

% set pTP condition
param.condition = 'TP';

% start parameter checking
fprintf(['\nInitiating partial Tripolar PECAP (pTPECAP) Loudness' ...
    ' Sequence\n\n']);

% check to see if monopolar PECAP has been recorded already
if ~isfield(param,'ID')
    fprintf('Note that Monopolar PECAP has not already been collected\n');
    fprintf(['Please check that the parameters in lines 121-158 are '...
        'correct\n']);
    fprintf('\nPlease enter your research participant ID\n');
    fprintf('\tNote: do this in ''string'' form\n');
    fprintf('\ti.e. ''AB01'' instead of AB01\n\t');
    param.ID = 0; 
    param.ID = input('Research Participant ID: ');
    while ~ischar(param.ID)
        fprintf('\n\tID must be a string.');
        fprintf('\n\tPlease put single quotes around text.\n')
        param.ID = input('\nResearch Participant ID: ');
    end
    
    % if MP PECAP hasn't already been recorded, set recording parameters
    % basic parameters for Monopolar PECAP
    param.debug = 0;
    param.extraplot = 1;        % switch to 1 to see ABCD frames plotted
    param.BEDCSVisible = 1;     % switch to 1 to make BEDCS visible 
    param.available_sweeps = [1 5 10 25 50 75 100 125 150 175 200];
    
    % instructions for the following parameters are in MP_Loudness_DAQ.m
    param.loudness_electrodes = [1 4 15];%[1 4 7 10 13 16];
    param.loudness_options = [5 6 7 8];
    param.electrodes = ...
        param.loudness_electrodes(1):param.loudness_electrodes(end);
    
    % enter other recording parameters
    param.gain = 1000;          % gain of the amplifier [1,3,100,300,1000]
    param.fs_kHz = 56;          % amplifier sampling frequency [56,28,9kHz]
    param.rel_rec_EL = -3;      % -3 if recording apically, +3 if basally
    param.sweeps = 10;          % number of sweeps (restricted as in ln125)

    % enter stimulus properties
    param.phase_duration_us = 10.776*4;     % has to be multiples of 10.776
    param.masker_probe_delay_us = 600;      % MPI (400us in Cochlear)
    param.level_start_masker = 100;         % these will be adjusted in GUI
    param.level_start_probe = 100;          % these will be adjusted in GUI
end

% specify which electrodes to focus
fprintf('\nWhat electrodes would you like to stimulate in pTP mode?\n');
fprintf('\t(Must be between e%d and e%d)\n\t', min(param.electrodes) + 2, ...
    max(param.electrodes) - 2); % must be at least 1 away from the edge 
%focused electrode 1
pTPe1 = input('pTP Electrode 1: ');
if ~isnumeric(pTPe1)
    while ~isnumeric(pTPe1)
        fprintf('\nPlease enter a number for a pTP electrode\n\t');
        pTPe1 = input('pTP Electrode 1: ');
    end
end
if isnumeric(pTPe1)
    while pTPe1 < min(param.electrodes) + 2 || ...
            pTPe1 > max(param.electrodes) - 2
        fprintf(['\nPlease select an electrode to stimulate in pTP ' ...
            'between e%d and e%d\n\t'], min(param.electrodes) + 2, ...
            max(param.electrodes) - 2);
        pTPe1 = input('pTP Electrode 1: ');
    end
end
% focused electrode 2
fprintf('\t')
pTPe2 = input('pTP Electrode 2: ');
if ~isnumeric(pTPe2)
    while ~isnumeric(pTPe2)
        fprintf('\nPlease enter a number for a pTP electrode\n\t');
        pTPe2 = input('pTP Electrode 2: ');
    end
end
if isnumeric(pTPe2)
    while pTPe2 < min(param.electrodes) + 1 || ...
            pTPe2 > max(param.electrodes) - 1
        fprintf(['\nPlease select an electrode to stimulate in pTP ' ...
            'between e%d and e%d\n\t'], min(param.electrodes) + 1, ...
            max(param.electrodes) - 1);
        pTPe2 = input('pTP Electrode 2: ');
    end
end

% set partial tripolar stimulation parameters
param.pTP_electrodes = [pTPe1 pTPe2];   % must be 1 elec away from edge
param.sweeps = 10;                % this is just for loudness testing
param.start_alpha = 1;            % initial alpha (0 = MP and 1 = full TP)
clear pTPe1 pTPe2

% print out recording parameters
fprintf(['\n\npTPECAP Loudness Scaling Parameters for Participant ' ...
    param.ID ':\n']);
fprintf(['\tAmplifier Gain: \t\t\t\t' num2str(param.gain) '\n']);
fprintf(['\tSampling Frequency: \t\t\t' num2str(param.fs_kHz) ' kHz\n']);
if param.rel_rec_EL ~= 3 && param.rel_rec_EL ~= -3
    error(['Recording electrode must be 3 electrodes away from the ' ...
        'probe. Please enter 3 or -3 for param.rel_rec_EL and restart.']);
elseif param.rel_rec_EL == 3
    fprintf('\tRecording Electrode:\t\t\t3 basal to the probe\n');
elseif param.rel_rec_EL == -3
    fprintf('\tRecording Electrode:\t\t\t3 apical to the probe\n');
end
if mod(param.phase_duration_us,10.776)~=0
    error(['Phase Duration must be a multiple of 10.776 microseconds. ' ...
        'Please enter a multiple of 10.776 for param.phase_duration_us' ...
        ' and restart.']);
else
    fprintf(['\tPhase Duration: \t\t\t\t' ...
        num2str(param.phase_duration_us) ' us\n']);
end
fprintf(['\tMasker-Probe Interval (MPI): \t' ...
    num2str(param.masker_probe_delay_us) ' us\n']);
fprintf(['\tLoudness Scaling sweeps: \t\t' num2str(param.sweeps) '\n']);
fprintf('\tFocused (pTP) Electrodes: \t\t');
for ii = 1:length(param.pTP_electrodes)
    if ii == length(param.pTP_electrodes)
        fprintf(['and ' num2str(param.pTP_electrodes(ii))]);
    else
        fprintf([num2str(param.pTP_electrodes(ii)) ' ']);
    end
end
fprintf(['\n\tLoudness Scaling will required for the following' ...
    '\n\t\tlevels: ']);
for ii = 1:length(param.loudness_options)
    if ii == length(param.loudness_options)
        fprintf(['and ' num2str(param.loudness_options(ii))]);
    else
        fprintf([num2str(param.loudness_options(ii)) ', ']);
    end
end

% pause to allow user to cancel and adjust parameters if desired
fprintf('\n\nAre these the parameters you would like to continue with?\n')
fprintf('\tIf no, press ctrl+c, and adjust parameters in the script.\n\t')
nth = input('If yes, press enter to initiate the Loudness Scaling GUI');

%% pTP Loudness

% initiate loudness ECAP storage structure
pTP_Loudness = struct();

% initiate loudness GUI for partial tripolar stimulation for each pTP elec
for ii = 1:length(param.pTP_electrodes)
    param.electrode_masker = param.pTP_electrodes(ii);
    param.electrode_probe = param.pTP_electrodes(ii);
    if param.pTP_electrodes(ii) + param.rel_rec_EL >= 1 && ...
            param.pTP_electrodes(ii) + param.rel_rec_EL <= 16
        param.rec_EL = param.pTP_electrodes(ii) + param.rel_rec_EL;
    else
        param.rec_EL = param.pTP_electrodes(ii) - param.rel_rec_EL;
    end
    while param.pTP_electrodes(ii) < min(param.electrodes) + 1 || ...
            param.pTP_electrodes(ii) > max(param.electrodes) - 1
        fprintf('\nCannot do pTP stimulation with chosen electrodes.\n')
        fprintf('Please enter a pTP electrode between e2-15.\n');
        fprintf('\t(At least 1 elec away from the edge of the evaluated PECAP elecs)\n)')
    end
    % rename file for pTP conditions
    param.exp_file = sprintf('ForwardMaskingPTP_gain_%d_%dkHz_%d_repeats.bExp',...
        param.gain, param.fs_kHz, param.sweeps); 
    % call ECAP recording & loudness GUI
    pTP_Loudness(ii).ECAP_Struct = run_loudness_and_ecap(param);
end

% save pTP Loudness data to file
datetimestr = datestr(datetime);
save(['data/Subj' param.ID '_cond' param.condition '_LoudnessData_' ...
    date '_' datetimestr(13:14) '-' datetimestr(16:17) '-', ...
    datetimestr(19:20)], 'param', 'pTP_Loudness');
clear datetimestr ii nth