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
% This script pTPECAP_DAQ.m is 2 of 2 and includes the data acquisition
% portion of the pTPECAP experiment that collects the rows and the columns 
% of the PECAP matrix that are selected for focused (partial Tripolar)
% stimulation. pTP_Loudness_DAQ.m must be run before this script, as well
% as MP_Loudness_DAQ.m and MP_PECAP_DAQ.m.
%
% Required Software: 
%       - MP_PECAP_DAQ.m (must be run before this script)
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

% check to see if the pTP Loudness DAQ has been recorded already
if ~isfield(param,'pTP_electrodes')
    error('Please run pTP_Loudness_DAQ.m before recording pTP PECAP');
end

% check to see if monopolar PECAP has been recorded already
if ~isfield(param,'MP_PECAP_Collected')
    error('Please record Monopolar PECAP before recording pTP PECAP');
else
    % add MCL levels for pTP conditions to param structure
    param.pTP_levels = zeros(1,length(param.pTP_electrodes));
    param.pTP_alphas = zeros(1,length(param.pTP_electrodes));
    for ii = 1:length(pTP_Loudness)
        Sixes = zeros(sum([pTP_Loudness(ii).ECAP_Struct.LoudnessLevel] == ...
            param.MCL_loudnesslevel),2);
        counter = 1;
        for jj = 1:length(pTP_Loudness(ii).ECAP_Struct)
            % maximizes the alpha level for MCLs
            if pTP_Loudness(ii).ECAP_Struct(jj).LoudnessLevel == ...
                    param.MCL_loudnesslevel
                Sixes(counter,1) = ...
                    pTP_Loudness(ii).ECAP_Struct(jj).Probe_lvl;
                Sixes(counter,2) = ...
                    pTP_Loudness(ii).ECAP_Struct(jj).alpha;
                counter = counter + 1;
            end
        end
        param.pTP_alphas(ii) = max(Sixes(:,2));
        [ ~,idx] = max(Sixes(:,2));
        param.pTP_levels(ii) = Sixes(idx,1);
    end

    % clean workspace
    clear Sixes ii jj counter idx
end

% start parameter checking
fprintf('\nInitiating partial Tripolar PECAP (pTPECAP) Sequence\n\n');

% print out recording parameters
fprintf(['\n\npTPECAP Recording Parameters for Participant ' param.ID ...
    ':\n']);
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

% pause to allow user to cancel and adjust parameters if desired
fprintf('\n\nAre these the parameters you would like to continue with?\n')
fprintf('\tIf no, press ctrl+c, and adjust parameters in the script.\n\t')
nth = input('If yes, press enter to initiate the Loudness Scaling GUI');

%% pTP Data Collection

% initiate structure & reset sweeps to data collection level
pTPECAP_Data = struct();
param.sweeps = 50;

% allow user to set the number of sweeps to collect
fprintf('\n\npTPECAP Recording is currently set to %d sweeps\n',param.sweeps);
fprintf('It is recommended to use the same # of sweeps as Monopolar PECAP.\n');
fprintf('\tWould you like to change this?\n');
fprintf('\tIf you select No, pTPECAP will commence.\n\t');
cont = input('Yes (1) or No (0): ');
while cont ~= 0
    % enters this loop if the user wants to adjust the number of sweeps
    if cont == 1
        fprintf('Please enter a number of sweeps from the following: ')
        for ii = 1:length(param.available_sweeps)
            fprintf([num2str(param.available_sweeps(ii)) ' ']);
        end
        fprintf('\n\t');
        param.sweeps = input('Number of Sweeps: ');
        % throws an error and requires a new sweeps parameter if the
        % enetred value is not included in the available number of sweeps
        % parameters
        while nnz(param.available_sweeps - param.sweeps) == ...
                length(param.available_sweeps)
            fprintf(['Error. Please enter a number of sweeps from the' ...
                'following: ']);
            for ii = 1:length(param.available_sweeps)
                fprintf([num2str(param.available_sweeps(ii)) ' ']);
            end
            fprintf('\n\t');
            param.sweeps = input('Number of Sweeps: ');
        end
        % displays updated sweep parameter before commencing ECAP recording
        fprintf('\nECAP Recording is now set to %d sweeps\n',param.sweeps);
        fprintf('\tWould you like to change this?\n\t');
        fprintf('If you select No, the pTPECAP will commence.\n\t');
        cont = input('Yes (1) or No (0): ');
    end
end

% Cycle through data collection 
for ii = 1:length(param.pTP_electrodes)
    % update pTP parameters
    param.pTP_elec = param.pTP_electrodes(ii);
    param.pTP_lvl = param.pTP_levels(ii);
    param.pTP_alpha = param.pTP_alphas(ii);
    % print out the pTP factor being collected
    fprintf('\nCommencing Data Collection for partial Tripolar (pTP)\n');
    fprintf(['\tpTP electrode: \t\t' num2str(param.pTP_elec)]);
    fprintf(['\n\tpTP alpha: \t\t\t' num2str(param.pTP_alpha) '/1']);
    fprintf(['\n\tpTP MCL ('  num2str(param.MCL_loudnesslevel) ...
        ') Level: \t\t' num2str(param.pTP_lvl) ...
        ' Device Units (' num2str(round(20*log10(param.pTP_lvl),1)) ...
        ' dB re 1 uA)']);
    fprintf('\n\n');
    pTPECAP_Data(ii).Electrode = param.pTP_elec;
    pTPECAP_Data(ii).alpha = param.pTP_alpha;
    pTPECAP_Data(ii).pTP_ECAPs = run_pTPECAP(param);
end

% plot M matrix for collected PECAP Data
pTPECAP_Data = plot_pTPECAP(PECAP_Data, pTPECAP_Data, param);               

% save PECAP data to file
datetimestr = datestr(datetime);
save(['data/Subj' param.ID '_cond' param.condition '_PECAPData_' date ...
    '_' datetimestr(13:14) '-' datetimestr(16:17) '-', ...
    datetimestr(19:20)], 'param', 'pTPECAP_Data');
clear datetimestr ii ans nth cont