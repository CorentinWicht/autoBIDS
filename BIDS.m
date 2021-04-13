%% EEG-BIDS GENERATION SCRIPT

% This script enables the generation of BIDS formatted EEG metadata based
% on the BIDS EEGLAB Toolbox:
% https://github.com/sccn/bids-matlab-tools

% See this youtube video from Arnaud Delorme for additional information:
% https://www.youtube.com/watch?v=xdcRe3ak_IQ&feature=youtu.be 
% Example script: https://github.com/sccn/bids-matlab-tools/blob/master/bids_export_example2.m

% /!\ See the GitHub README page for detailed explanations. /!\
% https://github.com/CorentinWicht/autoBIDS
%% Authors

% Corentin Wicht(script, protocol)
% Michael Mouthon (script, protocol)
% Lucas Spierer (protocol)

% If you have questions or want to contribute to this pipeline, feel free 
% to contact :
% corentin.wicht@unifr.ch, corentinw.lcns@gmail.com
% michael.mouthon@unifr.ch 

% Laboratory for Neurorehabilitation Science
% Neurology Unit, Medicine Section
% Faculty of Science and Medicine,
% University of Fribourg
% Ch. du Musée 5, CH-1700 Fribourg
% https://www3.unifr.ch/med/spierer/en/

% Version 0.1, April 2021
%% Clear workspace, etc
clear variables;close all;clc
%% Parameters prompts

% Paths
addpath([pwd '\Functions'])
addpath([pwd '\Functions\inputsdlg'])
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

% PROMPTS
% 1) EEG parameters 
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

% 2) BIDS design parameters 
% Dialog Options
Options.Resize = 'on'; Options.Interpreter = 'tex'; Options.ButtonNames = {'OK'};  
Option.Dim = 1; Options.FontSize = 8; Prompt = {}; Formats = {}; 

% Title
Prompt(1,:) = {['Fill in the matching pattern for the each of the 4 categories below.', newline ...
    '! LEAVE ANY "PATTERN" ENTRY EMPTY IF NOT ATTRIBUTABLE TO YOUR DESIGN !', newline newline],[],[]};
Formats(1,1).type = 'text'; Formats(1,1).size = [-1 0]; Formats(1,1).span = [1 1]; % item is 1 field x 1 field

% Variables
PromptHeads = {['SUBJECTS',newline,'What is the matching pattern in each file corresponding the participant ID (e.g. P* if P1, P2, ...)? '];
    ['COGNITIVE TASKS',newline,'Write the name of the task(s) (! If more than 1 task, separate them by a semi-colon ";" !)'];
    ['RUNS',newline 'If the task(s) was/were recorded in SEPARATE FILES, indicate the matching pattern (e.g. B* for B1, B2,...):'];
    ['SESSIONS',newline 'Indicate the matchin pattern for each session for between which the EEG cap was removed (e.g. S* for S1, S2,...)']};
DefAns.SubjPattern = [];DefAns.TaskPattern = [];DefAns.RunPattern = [];DefAns.SessionPattern = [];
DefAns.SubjLoc =[];DefAns.TaskLoc =[];DefAns.RunLoc =[];DefAns.SessionLoc =[];
VarNames = reshape(fieldnames(DefAns),[numel(fieldnames(DefAns))/2,2]);
MatchPattDef = {'P*';'GNG;RVIP';'';'S*'};

% Loop through variables above
Idx = 2;
for k=1:length(PromptHeads)
    
    % Subtitles for each category
    Prompt(Idx,:) = {PromptHeads{k},[],[]};
    Formats(Idx,1).type = 'text'; Formats(Idx,1).size = [-1 0];Formats(Idx,1).span = [1 1]; 
    Idx = Idx + 1;
    
    % Matching Patterns
    Prompt(Idx,:) = {'Pattern', VarNames{k,1},[]};
    Formats(Idx,1).type = 'edit';
    Formats(Idx,1).format = 'text';
    DefAns.(VarNames{k,1}) = MatchPattDef{k};
    Idx = Idx + 1;
    
    % Button responses
    Prompt(Idx,:) = {'Is the pattern found in files or folders ?',VarNames{k,2},[]};
    Formats(Idx,1).type = 'list';
    Formats(Idx,1).format = 'text';
    Formats(Idx,1).style = 'radiobutton';
    Formats(Idx,1).items = {'files' 'folders'};
    DefAns.(VarNames{k,2}) = 'files';
    Idx = Idx + 1;
end

% Subtitles for method below
Prompt(Idx,:) = {['METHOD',newline,...
    'To provide information on participants, use either autogenerated excel files (recommended, faster) or the EEGLAB popup window ?'],[],[]};
Formats(Idx,1).type = 'text'; Formats(Idx,1).size = [-1 0];Formats(Idx,1).span = [1 1]; 

% Method
Prompt(Idx+1,:) = {'Method','MetaData',[]};
Formats(Idx+1,1).type = 'list';
Formats(Idx+1,1).format = 'text';
Formats(Idx+1,1).style = 'radiobutton';
Formats(Idx+1,1).items = {'Autogenerated' 'EEGLAB'};
DefAns.MetaData = 'Autogenerated';

% Run the prompt
PImp = inputsdlg(Prompt,'BIDS DESIGN PARAMETER PROMPT',Formats,DefAns,Options);
SubjPattern = PImp.SubjPattern; 
SubjLoc = fastif(strcmp(PImp.SubjLoc,'files'),1,2);
TaskPattern = strsplit(PImp.TaskPattern,';'); 
TaskLoc = fastif(strcmp(PImp.TaskLoc,'files'),1,2); 
RunPattern = PImp.RunPattern; 
RunLoc = fastif(strcmp(PImp.RunLoc,'files'),1,2); 
SessionPattern = PImp.SessionPattern; 
SessionLoc = fastif(strcmp(PImp.SessionLoc,'files'),1,2);  
MetaData = fastif(strcmp(PImp.MetaData,'Autogenerated'),1,2); 

% Retrieving list of Subjects
StrPattern = ['(?<=' strrep(SubjPattern,'*','') ')[0-9]*'];
if SubjLoc == 1 % subject string pattern in files
    SubjList = cellfun(@(x) str2double(regexp(x, StrPattern, 'match')),{FileList.name}');
elseif SubjLoc == 2 % subject string pattern in folders
    SubjList = cellfun(@(x) str2double(regexp(x, StrPattern, 'match')),{FileList.folder}');
end

%% GENERATING EXCEL TEMPLATE PARTICIPANT FILE


if MetaData == 1
    if ~isfile('ParticipantInfo_BIDS.xlsx') % only if file doesn't exist yet
        
        % Column names
        ColNames = {'EEGFiles','Participant'};
        
        % 1. Data sheet
        if SubjLoc == 1 
            PartTab = [{FileList.name}' num2cell(SubjList)];
        elseif SubjLoc == 2
            TEMP = [{FileList.folder}' repmat({'\'},length(FileList),1) {FileList.name}'];
            Dat = cell(size(TEMP,1),1);
            for k=1:size(TEMP,1); Dat{k,:} = horzcat(TEMP{k,:});
            end
            PartTab = [Dat num2cell(SubjList)];
        end
        
        % Content is adjusted based on responses to BIDS prompt
        % 1.1 Task
        if length(TaskPattern)>1; TEMP = cell(size(PartTab,1),1);
            ColNames = [ColNames {'Task'}];
            for k=1:size(PartTab,1)
                TEMP{k} = TaskPattern{cellfun(@(x) contains(PartTab{k,1},x),TaskPattern)};
            end
            PartTab = [PartTab TEMP];
        elseif length(TaskPattern)==1
            ColNames = [ColNames {'Task'}];
            PartTab = [PartTab repmat(TaskPattern,size(PartTab,1),1)];
        end
        
        % 1.2 Run
        StrPattern = ['(?<=' strrep(RunPattern,'*','') ')[0-9]*'];
        if ~isempty(RunPattern) && RunLoc == 1 
            TEMP = cell(size(PartTab,1),1);
            ColNames = [ColNames {'Run'}];
            for k=1:size(PartTab,1)
                TEMP{k} = str2double(regexp(PartTab{k,1}, StrPattern, 'match'));
            end; PartTab = [PartTab TEMP];
        elseif ~isempty(RunPattern) && RunLoc == 2 
            TEMP = cell(size(PartTab,1),1);
            ColNames = [ColNames {'Run'}];
            for k=1:size(PartTab,1)
                TEMP{k} = str2double(regexp(PartTab{k,1}, StrPattern, 'match'));
            end; PartTab = [PartTab TEMP];
        end
        
        % 1.3 Session
        StrPattern = ['(?<=' strrep(SessionPattern,'*','') ')[0-9]*'];
        if ~isempty(SessionPattern) && SessionLoc == 1 
            TEMP = cell(size(PartTab,1),1);
            ColNames = [ColNames {'Session'}];
            for k=1:size(PartTab,1)
                TEMP{k} = str2double(regexp(PartTab{k,1}, StrPattern, 'match'));
            end; PartTab = [PartTab TEMP];
        elseif ~isempty(SessionPattern) && SessionLoc == 2 
            TEMP = cell(size(PartTab,1),1);
            ColNames = [ColNames {'Session'}];
            for k=1:size(PartTab,1)
                TEMP{k} = str2double(regexp(PartTab{k,1}, StrPattern, 'match'));
            end; PartTab = [PartTab TEMP];
        end
        
        %% NEW METHOD W/O EXCEL 
        % 1) PARTICIPANT INFO DATA
        % Matrix to integrate in the following uitable
        PartTab = [PartTab  cell(length(FileList),2)];
        ColNames = [ColNames {'HeadCircumference','SubjectArtefactDescription'}]; 
        ToDisp = [ColNames cell(1,5);PartTab cell(size(PartTab,1),5)];

        % Select folders on which to apply analyses       
        f = figure('unit','normalized','Position',[0.15 0.15 0.7 0.7]);
        fPos= get(f, 'position');
        p=uitable('Parent', f,'unit','normalized','Position', [0.15 0.15 0.7 0.7],...
        'Data',ToDisp,'ColumnEdit',true,'RowName',[{'Variables'} cell(1,size(PartTab,1)-1)],...
        'CellEditCallBack','DATA = get(gco,''Data'');');
        uicontrol('Style', 'text','unit','normalized','Position',[0.1 0.85 0.85 0.1], 'String',...
                {'PARTICIPANT INFORMATION DATA','You can add more information if needed (first line = name of each variable).'});
        % Wait for t to close until running the rest of the script
        waitfor(p)

        % If table modified
        if exist('DATA','var') 
            ColNames = DATA(1,:);
            PartTab = DATA(2:end,:);
        end
        
        % Removing empty columns
        Idx = sum(~cellfun('isempty', PartTab),1)>0;
        PartTab = PartTab(:,sum(~cellfun('isempty', PartTab),1)>0);
        ColNames = ColNames(Idx);
        
        % Identify categorical variables remaining
        ToDisp = cell(length(ColNames),10); % Matrix to integrate in the following uitable
        Cat = {'Task','Run','Session'};
        for k=1:length(Cat)
            Idx = ismember(ColNames,Cat{k});
            if nnz(Idx)
                try % if cell array of strings
                    ToDisp(Idx,2:2+length(unique(PartTab(:,Idx)))-1) = unique(PartTab(:,Idx))';
                catch % if cell array of integers
                    ToDisp(Idx,2:2+length(unique(cell2mat(PartTab(:,Idx))))-1) = ...
                        num2cell(unique(cell2mat(PartTab(:,ismember(ColNames,Cat{k}))))');
                end
            end
        end
        
        % Changing to table format
        PartTab = cell2table(PartTab,'VariableNames',ColNames);
        
        
        % 2) VARIABLES DESC
        
        % Select folders on which to apply analyses       
        f = figure('unit','normalized','Position',[0.15 0.15 0.7 0.7]);
        fPos= get(f, 'position');
        ColumnNames = [{'Description'} strseq('Levels',1:size(ToDisp,2)-2)'];
        p=uitable('Parent', f,'unit','normalized','Position', [0.15 0.15 0.7 0.7],...
        'Data',ToDisp,'ColumnEdit',true,'RowName',ColNames,'ColumnName',ColumnNames,...
        'CellEditCallBack','DESC = get(gco,''Data'');');
        uicontrol('Style', 'text','unit','normalized','Position',[0.1 0.85 0.85 0.1], 'String',...
                {'VARIABLES DESCRIPTION',['For each variable (line) :' newline,...
                '1) Give a brief description.',newline...
                '2) Rename the levels for each categorical variables.']});
        % Wait for t to close until running the rest of the script
        waitfor(p)
        
        % If table not modified 
        if ~exist('DESC','var') 
            DESC = [ColNames' ToDisp];
        else
            DESC = [ColNames' DESC];
        end
        
        % Remove empty columns
        DESC = DESC(:,sum(~cellfun('isempty', DESC),1)>0);
        
        % Changing to table
        DESC = cell2table(DESC,'VariableNames',VarNames(1:size(DESC,2)));
        
        % Write the excel file
        writetable(PartTab,'ParticipantInfo_BIDS.xlsx','Sheet','DATA')
        writetable(DESC,'ParticipantInfo_BIDS.xlsx','Sheet','DESC')

    end

    % Load data
    PartInfoData = readtable('ParticipantInfo_BIDS.xlsx','Sheet','DATA');
    PartInfoColNames = PartInfoData.Properties.VariableNames;
    PartInfoData = table2cell(PartInfoData);
    PartInfoDesc = readtable('ParticipantInfo_BIDS.xlsx','Sheet','DESC');
    PartInfoDesc = table2cell(PartInfoDesc);
end

%% LOADING DATA & BUILDING STUDY 

% Prompt to load existing STUDY
LoadSTUDY = questdlg('Would you like to load an existing EEGLAB STUDY ?', ...
	'LOAD EEGLAB STUDY', 'YES','NO','NO');

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
        if TaskLoc==1; EEG.task = TaskPattern{cellfun(@(x) contains(EEG.filename,x),TaskPattern)};
        elseif TaskLoc==2; EEG.task = TaskPattern{cellfun(@(x) contains(EEG.filepath,x),TaskPattern)};
        else; EEG.task = '';
        end
        
        % 2.RUN INFORMATION
        StrPattern = ['(?<=' strrep(RunPattern,'*','') ')[0-9]*'];
        if RunLoc==1 % Matching pattern in files
            EEG.run = str2double(regexp(EEG.filename, StrPattern, 'match'));
        elseif RunLoc==2 % Matching patter in folders
            EEG.run = str2double(regexp(EEG.filepath, StrPattern, 'match'));
        else; EEG.run = [];
        end
        
        % 3.SESSION INFORMATION
        StrPattern = ['(?<=' strrep(SessionPattern,'*','') ')[0-9]*'];
        if SessionLoc==1 % Matching pattern in files
            EEG.session = str2double(regexp(EEG.filename, StrPattern, 'match'));
        elseif SessionLoc==2 % Matching patter in folders
            EEG.session = str2double(regexp(EEG.filepath, StrPattern, 'match'));
        else; EEG.session = [];
        end
        
        %%%% STEP 1: Edit BIDS Task Information %%%%
        % ----------------------------------- %
        % Filling up the EEG data structures with default settings (LNS lab)
        % EEG manufacturer information
        EEG.BIDS.tInfo.CapManufacturer = 'Electro-Cap International';
        EEG.BIDS.tInfo.CapManufacturersModelName = 'medium-small, medium, medium-large, large';
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
        
        % Institution information
        EEG.BIDS.tInfo.InstitutionName = 'University of Fribourg';
        EEG.BIDS.tInfo.InstitutionalDepartmentName = 'Neurosciences and Movement Sciences';
        EEG.BIDS.tInfo.InstitutionAddress = 'Fribourg, Switzerland';

        % Participant information
        % EEG(1).BIDS.pInfoDesc contains description of each variable
        % EEG(1).BIDS.pInfo contains data as cells
        if MetaData==1 
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
if MetaData==2 
    EEG = pop_participantinfo(EEG, STUDY);
end

%%%% STEP 3: Event Info %%%%
% ----------------------------------- %
EEG = pop_eventinfo(EEG); 

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
