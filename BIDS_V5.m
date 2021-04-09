%% EEG-BIDS GENERATION SCRIPT

% This script enables the generation of BIDS formatted EEG metadata based
% on the BIDS EEGLAB Toolbox:
% https://github.com/sccn/bids-matlab-tools

% See this youtube video from Arnaud Delorme for additional information:
% https://www.youtube.com/watch?v=xdcRe3ak_IQ&feature=youtu.be 

% /!\ See the GitHub README page for detailed explanations. /!\
% LINK GITHUB !!!! 
%% Authors

% Michael Mouthon (script, protocol)
% Corentin Wicht(script, protocol)
% Lucas Spierer (protocol)

% If you have questions or want to contribute to this pipeline, feel free 
% to contact :
% michael.mouthon@unifr.ch 
% corentin.wicht@unifr.ch

% Laboratory for Neurorehabilitation Science
% Neurology Unit, Medicine Section
% Faculty of Science and Medicine,
% University of Fribourg
% Ch. du Mus�e 5, CH-1700 Fribourg
% https://www3.unifr.ch/med/spierer/en/

% Version 5.0, March 2021
%% Clear workspace, etc
clear variables;close all;clc
%% Parameters prompts

% Paths
addpath([pwd '\Functions'])
addpath([pwd '\Functions\eeglab2021.0'])

% Path of your upper folder containing your data and list all bdf files
Extension='.bdf'; % Raw file as input
FilesFolder = uigetdir('title',...
    'Choose the path of your most upper folder containing your RAW EEG files (in .bdf)');
FileList = dir([FilesFolder '\**/*' Extension]);
[~,NatSortIdx] = natsort({FileList.name});
FileList = FileList(NatSortIdx); % Natural order

% Path of the folder to save filtered and epoched .set
mrk_folder = uigetdir('title',...
    ['OPTIONAL: Choose the path of your most upper folder containing your .mrk files' ...
    ' (if no file, press CANCEL)']);
MRKList = dir([mrk_folder '\**/*.mrk']);
[~,NatSortIdx] = natsort({MRKList.name});
MRKList = MRKList(NatSortIdx); % Natural order

% Specify the path of the electrodes localisation file
[chanloc_file,chanloc_path] = uigetfile('*.*', 'Select the electrodes localisation file for your data (.loc or .xyz)');
chanloc_path=[chanloc_path,chanloc_file]; 

% Importing participant information excel file (optional)
[PartInfoFile,PartInfoPath, PartFiltIdx] = uigetfile({'*.xlsx';'*.csv'},...
    ['OPTIONAL: Select an excel file containing participant information for BIDS'...
    ' (if no file, press CANCEL)']);
PartInfoData = readtable([PartInfoPath PartInfoFile],'Sheet','DATA');
PartInfoColNames = PartInfoData.Properties.VariableNames;
PartInfoData = table2cell(PartInfoData);
PartInfoDesc = readtable([PartInfoPath PartInfoFile],'Sheet','DESC');
PartInfoDesc = table2cell(PartInfoDesc);

% Importing EEG events information excel file (optional)
[EventInfoFile,EventInfoPath, EventFiltIdx] = uigetfile({'*.xlsx';'*.csv'},...
    ['OPTIONAL: Select an excel file containing EEG events information for BIDS'...
    ' (if no file, press CANCEL)']);

% EEG parameters
EEGParamInstruct = {'How many channels do you work with ?',...
    'What is the reference electrode number (i.e. Cz is 48) ?',...
    'What name would you like to give to the EEGLAB STUDY ?',...
    'Presentation triggers delay (in ms)'};
PromptValues = {'64','48','Study','0'};
PromptInputs = inputdlg(EEGParamInstruct,'Preprocessing parameters',1,PromptValues);
nbchan = str2double(PromptInputs{1});
ref_chan = str2double(PromptInputs{2});
StudyName = PromptInputs{3};
Error_ms = str2double(PromptInputs{4});

% BIDS design parameters
BIDSParamInstruct = {'What is the matching pattern for SUBJECTS (e.g. P* if P1, P2, ...)? ',...
    'Is the matching pattern found in files [1], folders [2] or there is none [0] ?',...
    ['Write the name of the COGNITIVE TASKS',...
    newline '! If more than one task, separate their names by a semi-colon ";" !'],...
    'Is the matching pattern found in files [1] or folders [2] ?',...    
    'If the blocks for one task were recorded in SEPARATE FILES/RUNS, indicate the matchin pattern (e.g. B* for B1, B2,...):',...
    'Is the matching pattern found in files [1], folders [2] or there is none [0] ?',...
    'If the files were recorded in more than 1 SESSION (i.e. the EEG cap was removed in between), indicate again the matchin pattern: (e.g. S* for S1, S2,...)',...
    'Is the matching pattern found in files [1], folders [2] or there is none [0] ?'};
PromptValues = {'P*','1','GNG;RVIP','1','','0','S*','1'};
PromptInputs = inputdlg(BIDSParamInstruct,'BIDS design parameters',1,PromptValues);
SubjPattern = PromptInputs{1}; 
Task = strsplit(PromptInputs{3},';'); 
TaskPattern = PromptInputs{4}; 
Run = PromptInputs{5}; 
RunPattern = PromptInputs{6}; 
Session = PromptInputs{7}; 
SessionPattern = PromptInputs{8}; 

%% MATCHING EEG & EXCEL FILES 

if PartFiltIdx~=0 % ONLY IF EXCEL FILE PROVIDED
    % Checking if same number of EEG files than lines in Excel file
    if length(FileList) ~= size(PartInfoData,1)
       error([sprintf('! The number of lines in the %s file is not the same as the number of EEG files !',PartInfoFile), ...
           newline 'EEG files: ' num2str( length(FileList)), ...
           newline 'Behav files: ' num2str(size(PartInfoData,1)),...
           newline newline 'Make sure to match them before restarting the script.']) ;
    end
end

%% LOADING DATA & BUILDING STUDY 

% Prompt to load existing STUDY
LoadSTUDY = questdlg('Would you like to load an existing EEGLAB STUDY ?', ...
	'LOAD EEGLAB STUDY', 'YES','NO','NO');

% Retrieving list of Subjects
StrPattern = ['(?<=' strrep(SubjPattern,'*','') ')[0-9]*'];
if str2double(PromptInputs{2}) == 1 % subject string pattern in files
    SubjList = cellfun(@(x) str2double(regexp(x, StrPattern, 'match')),{FileList.name}');
elseif str2double(PromptInputs{2}) == 2 % subject string pattern in folders
    SubjList = cellfun(@(x) str2double(regexp(x, StrPattern, 'match')),{FileList.folder}');
end

if strcmp(LoadSTUDY,'NO')
    % Create folder for temporary .set storage
    mkdir TEMP

    % Run EEGLAB
    STUDY = []; CURRENTSTUDY = 0; ALLEEG=[]; EEG=[]; CURRENTSET=[]; 
    eeglab nogui % Better than to close the GUI afterwards

    % EEGlAB options
    % set double-precision parameter & allows to process more datasets while only keeping 1 in memory
    pop_editoptions('option_single', 0, 'option_storedisk',1); 

    % Epitome of UI
    h = waitbar(0,{'Loading' , ['Progress: ' '0 /' num2str(size(FileList,1))]});

    % Filling in the STUDY in EEGLAB
    for i=1:size(FileList,1)

        % Current file's path
        FilePath = [FileList(i).folder '\' FileList(i).name];

        % Waitbar updating
        waitbar(i/size(FileList,1),h,{strrep(FileList(i).name,'_','-'), ...
            ['Progress: ' num2str(i) '/' num2str(size(FileList,1))]})

        % Import the .bdf file 
        EEG = pop_biosig(FilePath,'channels',1:nbchan); 

        % Load channels location file
        EEG = pop_chanedit(EEG, 'load',{chanloc_path 'filetype' 'autodetect'});

        % Re-referencing, because chanedit erase the information
        EEG = pop_reref(EEG,ref_chan);
        
        % Adding information to the EEG file (relevant for BIDS)
        EEG.filename = FileList(i).name;
        EEG.filepath = FileList(i).folder;
        EEG.subject = num2str(SubjList(i));
        % 1.TASK INFORMATION
        if str2double(TaskPattern)==1; EEG.task = Task{cellfun(@(x) contains(EEG.filename,x),Task)};
        elseif str2double(TaskPattern)==2; EEG.task = Task{cellfun(@(x) contains(EEG.filepath,x),Task)};
        else; EEG.task = '';
        end
        
        % 2.RUN INFORMATION
        StrPattern = ['(?<=' strrep(Run,'*','') ')[0-9]*'];
        if str2double(RunPattern)==1 % Matching pattern in files
            EEG.run = str2double(regexp(EEG.filename, StrPattern, 'match'));
        elseif str2double(RunPattern)==2 % Matching patter in folders
            EEG.run = str2double(regexp(EEG.filepath, StrPattern, 'match'));
        else; EEG.run = [];
        end
        
        % 3.SESSION INFORMATION
        StrPattern = ['(?<=' strrep(Session,'*','') ')[0-9]*'];
        if str2double(SessionPattern)==1 % Matching pattern in files
            EEG.session = str2double(regexp(EEG.filename, StrPattern, 'match'));
        elseif str2double(SessionPattern)==2 % Matching patter in folders
            EEG.session = str2double(regexp(EEG.filepath, StrPattern, 'match'));
        else; EEG.session = [];
        end
        
        %%%% STEP 1: Edit BIDS Task Information %%%%
        % ----------------------------------- %
        % Filling up the EEG data structures with default settings (LNS lab)
        % EEG manufacturer information
        EEG.BIDS.tInfo.CapManufacturer = 'Electro-Cap International';
        EEG.BIDS.tInfo.CapManufacturersModelName = ['medium-small, medium,' ...
            'medium-large, large'];
        EEG.BIDS.tInfo.EEGReference = 'Occipital between PO3 and POz';
        EEG.BIDS.tInfo.EEGGround = 'Occipital between POz and PO4';
        EEG.BIDS.tInfo.EEGPlacementScheme = '10-20';
        EEG.BIDS.tInfo.Manufacturer = 'BioSemi';
        EEG.BIDS.tInfo.ManufacturersModelName = 'ActiveTwo';
        EEG.BIDS.tInfo.DeviceSerialNumber = 'ADC16-11-758';
        EEG.BIDS.tInfo.SoftwareVersions = 'ActiView707';
        EEG.BIDS.tInfo.HardwareFilters = '3.6 Khz';
        EEG.BIDS.tInfo.SoftwareFilters = 'Hamming windowed sinc FIR filter [pop_eegfiltnew.m]';
        EEG.BIDS.tInfo.PowerLineFrequency = 50;
        
        % TEMPORARY FOR MY STUDY: !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        EEG.BIDS.tInfo.CogPOID = 'Inhibitory Control & Sustained Attention';
        EEG.BIDS.tInfo.CogAtlasID = 'Go/No-Go & Rapid Visual Information Processing';
        EEG.BIDS.tInfo.Instructions = ['Control for blinding',newline 'To preclude participants� attempt to guess which condition they are currently assigned to and to ensure that they will believe they have received in one session the CAF and in the two others the DECA, a second experimenter will prepare the beverages in front of the participants. Hence, the first experimenter will remain blind to condition assignment. To ensure that participants remain na�ve to the manipulation, the experimenter will draw each coffee pod from their respective box in front of the participant and prepare the beverage in his office, with open doors so as to hear the sound of the machine. Importantly, the second experimenter will swap coffee cups in his office when necessary (depending on condition assignment). For e.g., in the Told-DECA/Give-CAF condition, the second experimenter will draw a decaffeinated coffee pod from its box in front of the participant and swap it for a caffeinated coffee pod when preparing the beverage in his office. We will further ask participants to wash their mouth with water before drinking the beverage to reduce taste acuity (Rohsenow and Marlatt, 1981; George et al., 2012). ',newline...
        '',newline 'Cover Story',newline 'We will also implement a deceptive protocol (i.e. cover story) to enhance the credibility of our procedure as well as participants� expectations regarding the intervention. The method is the same as in Elkins-Brown and al. (2018) for which a complete description is available at the following address: https://osf.io/e3hw8/. The procedure was adapted to our paradigm as follows: participants will provide saliva samples which will be mixed with a small test tube of water and 3-4 drops of iodine (i.e. yellow solution). If the participant is in the Told-CAF condition, the yellow solution is poured in a solvent of water and starch, which will change the solution�s color to dark-blue. If the participant is in the Told-DECA condition, starch is replaced by milk and the solution will remain yellow. Beforehand, participants will be informed that if the solution turns dark-blue it means that caffeine concentration is high (i.e. Told-CAF condition) and if it stays yellow that caffeine concentration is so low that it can�t be detected (i.e. Told-DECA condition).'];                                                                   
        EEG.BIDS.tInfo.TaskDescription = ['The three experimental sessions will take place from 9 a.m. to 12 a.m. and 1 week apart (for comparable procedure see Campbell, Chambers, Allen, Hedge, & Sumner, 2017) at the Neurology Unit of the University of Fribourg, Switzerland. Each experimental session will last around 2.5 hours. The procedure of the sessions is summarized in Table 4 and the timing of events is matched to simulated caffeine pharmacokinetics in Figure 3. ',newline...
        'The procedure of the sessions will consist of the following steps:',newline '',newline 'Session 1 only:',newline...                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             
        '�	Participants will give their written consent for the study prior to entering any procedure or collection of data related to the study. In the informed consent document, participants� beliefs in the cognitive enhancing effects of caffeine will have been reinforced with the following paragraph:',newline...                                                                     
        '�Scientific studies agree that caffeine enhances cognitive performance and more specifically executive functions (attention, motor control). Moreover, many articles published by different types of media (e.g. newspapers, internet) appropriately highlight the health benefits of a moderate coffee consumption (between 1 and 4 cups/day)�. (Informed consent original text in French: https://osf.io/wnc5q/).',newline...
        '',newline 'Sessions 1,2 and 3:',newline...                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        
        '�	Participants will be screened regarding the inclusion and exclusion criteria and required to stay quietly seated so that the cardiovascular readings can be taken (see details in section 2.7.2).',newline...                                                                                                                                                             
        '�	The electrodes for the EEG recording system will be positioned on participants� head (duration ~15 min) and participants will be asked to close their eyes and lie comfortably for five minutes so that the baseline resting-state EEG will be recorded.',newline...                                                                                                      
        '�	Participants will be given either the CAF or DECA beverages (i.e. first two large coffee cups), depending on condition assignment (see section 2.5.2), and be required to drink it in less than 5min.',newline...                                                                                                                                                         
        '�	Participants will be instructed to complete two computerized cognitive tasks. Twenty minutes after the first coffee administration, before beginning the first cognitive task, a salivary sample will be collected which will be used for the cover procedure (see section 2.5.4). Then, participants will be given a third large coffee cup (i.e. half the caffeine content) exactly one hour after the first one, while again be required to drink it in less than 5min.',newline...
        '�	Once the cognitive tasks are completed, Participants will be reminded about the following session (session 1 and 2) or fill in the debriefing questionnaire (DPEQ; session 3).',newline...                                                                                                                                                                               
        '',newline 'End of the study:',newline...                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                
        'As soon as the last participant�s data is collected, we will send each participant an additional debriefing sheet by email and give them a phone call during which they will be able to react to the debriefing sheet. This follow-up session is recommended to comply with ethics requirements regarding placebo studies (see recommendations from George et al., 2012; Rohsenow and Marlatt, 1981).'];
        EEG.BIDS.tInfo.Taskname2 = 'Use dataset "task condition" instead of task above';
        EEG.BIDS.gInfo.ReferencesAndLinks = {'Zenodo Link'};
        EEG.BIDS.gInfo.Authors = {'Corentin Wicht'};
        EEG.BIDS.gInfo.TaskName = 'mixed';
        EEG.BIDS.gInfo.Name = 'CAF STUDY';
        EEG.BIDS.gInfo.README = ['Placebo effects (PE) are defined as the beneficial psychophysiological outcomes of an intervention that are not attributable to its inherent properties; PE thus follow from individuals� expectations about the effects of the intervention. The present study aims at examining how expectations influence neurocognitive processes.',newline...
        'We will address this question by contrasting three double-blinded within-subjects experimental conditions in which participants are given decaffeinated coffee, while being told they have received caffeinated (condition i) or decaffeinated coffee (ii), and given caffeinated coffee while being told they have received decaffeinated coffee (iii).',newline...
        'After each of these three interventions, performance and electroencephalogram will be recorded at rest as well as during sustained attention Rapid Visual Information Processing task and a Go/NoGo motor inhibitory control task.',newline...
        ' We first aim to confirm previous findings for caffeine-induced enhancement on these executive components and on their associated electrophysiological indexes (attentional P3 component, response conflict N2 and inhibition P3 components (ii vs iii contrast); and then to test the hypotheses that expectations also induce these effects (i vs ii), although with a weaker amplitude (i vs iii). '];
    
        % Institution information
        EEG.BIDS.tInfo.InstitutionName = 'University of Fribourg';
        EEG.BIDS.tInfo.InstitutionalDepartmentName = 'Neurosciences and Movement Sciences';
        EEG.BIDS.tInfo.InstitutionAddress = 'Fribourg, Switzerland';

        % Participant information
        % EEG(1).BIDS.pInfoDesc contains description of each variable
        % EEG(1).BIDS.pInfo contains data as cells
        if PartFiltIdx~=0 % ONLY IF EXCEL FILE PROVIDED
            Idx = ismember(cellfun(@(x) strrep(x,'.set',''),PartInfoData(:,1),'UniformOutput',0),...
                strrep(EEG.filename,Extension,'')); % Find subject specific data 
            EEG.BIDS.pInfo(1,:) = PartInfoColNames; % First line is headers
            EEG.BIDS.pInfo(2,:) = PartInfoData(Idx,:); % Second line is data

            % contains description of each variable
            for m=1:size(PartInfoDesc,1)
                IdxPartInfoDesc = PartInfoDesc(m,cellfun(@(x) ~isempty(x), PartInfoDesc(m,:)));
                EEG.BIDS.pInfoDesc.(PartInfoDesc{m,1}).Description = PartInfoDesc{m,2};

                % Defining levels (if provided)
                if length(IdxPartInfoDesc)>2
                    Levels = unique(PartInfoData(:,m)); % find unique levels in data
                    Levels = Levels(cellfun(@(x) ~isempty(x),Levels)); % Removing empty fields
                    % replacing spaces (if any, not accepted for structure field names)
                    Levels = cellfun(@(x) strrep(x,' ','_'), Levels, 'UniformOutput', 0);
                    for n=3:length(IdxPartInfoDesc) % Fill in the structure
                        EEG.BIDS.pInfoDesc.(PartInfoDesc{m,1}).Levels.(Levels{n-2}) = IdxPartInfoDesc{n};
                    end
                end
            end
        end
        
        % Loading .mrk file and replacing the EEG.event and .urevent
        % structures (thanks to Hugo Najberg for the code lines)
        if ~isempty(mrk_folder)
            
            % opening the .mrk file and capturing its data (trigger type and latency)
            Idx = ismember(cellfun(@(x) strrep(x,'.mrk',''),{MRKList.name},'UniformOutput',0),...
                strrep(EEG.filename,Extension,'')); % Find subject specific data 
            
            if nnz(Idx)% The .mrk file may not exist
                filenameMRK = [MRKList(Idx).folder '\' MRKList(Idx).name];
                delimiter = '\t';
                startRow = 2;
                formatSpec = '%q%q%q%[^\n\r]';
                fileID = fopen(filenameMRK,'r');

                % Scanning the file
                dataArray = textscan(fileID, formatSpec, 'Delimiter', delimiter, 'HeaderLines' ,startRow-1, 'ReturnOnError', false, 'EndOfLine', '\r\n');                       

                % deleting the structure EEG.event
                EEG = rmfield(EEG,{'event','urevent'});
                
                % Converting from ms to TF
                if Error_ms~=0; Error_TF = round(Error_ms/((1/EEG.srate)*1000));end

                % Creating the new EEG.event and EEG.urevent structures based on the .mrk data
                for row = 1:length(dataArray{1})
                    EEG.event(row).latency = str2num(cell2mat(dataArray{1}(row)))+Error_TF;
                    EEG.event(row).type    = str2num(cell2mat(dataArray{3}(row)));
                    EEG.urevent(row).latency = str2num(cell2mat(dataArray{1}(row)))+Error_TF;
                    EEG.urevent(row).type    = str2num(cell2mat(dataArray{3}(row)));
                    EEG.event(row).urevent = row;
                end
            end
        end

        % Save file as .set in temporary folder (will be emptied at the end)
        FileNameSet = strrep(EEG.filename,Extension,'.set');
        pop_saveset(EEG,[pwd '\TEMP\' FileNameSet]);  

        % Reload dataset (.set) from temp. folder
        EEG = pop_loadset(FileNameSet,[pwd '\TEMP\']);
        [ALLEEG, EEG, CURRENTSET] = eeg_store( ALLEEG, EEG, i);

        % Filling the STUDY structure
        [STUDY,ALLEEG] = std_editset(STUDY, ALLEEG,'name', StudyName, 'commands',...
        {{'index' i 'load' [pwd '\TEMP\' FileNameSet] 'subject' num2str(SubjList(i))}},'updatedat','off'); 
    end

    % Waitbar end
    waitbar(1,h,{'Done !' , ['Progress: ' num2str(i) ' /' num2str(size(FileList,1))]});

    % Save STUDY
    [STUDY EEG] = pop_savestudy(STUDY, EEG, 'filename',[StudyName '.study'],...
    'filepath',pwd);

    % Reloading the STUDY
    [STUDY EEG] = pop_loadstudy('filename', [StudyName '.study'], 'filepath',pwd);
else
    % Select .study file to load
    [STUDY_file,STUDY_path] = uigetfile('.study', 'Select the STUDY file you would like to load');
    
    % Load provided .study file
    [STUDY EEG] = pop_loadstudy('filename',STUDY_file,'filepath',STUDY_path);
end

%% BUILD BIDS INFORMATION
% see : https://github.com/sccn/bids-matlab-tools/wiki

% Run the GUI
% Data are contained in each dataset's EEG.BIDS.tInfo and EEG.BIDS.gInfo
EEG = pop_taskinfo(EEG);

%%% STEP 2: Participant Info %%%%
% ----------------------------------- %
if PartFiltIdx==0 % ONLY IF EXCEL FILE NOT PROVIDED
    EEG = pop_participantinfo(EEG, STUDY);
end

%%%% STEP 3: Event Info %%%%
% ----------------------------------- %

if EventFiltIdx==0 % ONLY IF EXCEL FILE NOT PROVIDED
    EEG = pop_eventinfo(EEG); 
end

%%%% STEP 4: Export BIDS structure %%%%
% ----------------------------------- %
pop_exportbids(STUDY, EEG,'targetdir',[pwd '\BIDS_EXPORT'])

%%%% STEP 5: Validate BIDS dataset %%%%
% Adopting Openneuro's command-line bids-validator
% https://github.com/bids-standard/bids-validator
pop_validatebids([pwd '\BIDS_EXPORT'])
% The ouputs looks terribly weird, I opened an issue (09.04.2021):
% https://github.com/bids-standard/bids-validator/issues/1262

% prompt output
fprintf('The script ran successfully and the output can be found in %s.',[pwd '\BIDS_EXPORT'])

%% REMOVE TEMPORARY DATA
% IF DO SO, WILL NOT BE ABLE TO RELOAD THE STUDY !!! 
% Removing TEMP folder with content (all .set files generated while creating
% the STUDY) ! 
% rmdir([pwd '\TEMP\'],'s');
