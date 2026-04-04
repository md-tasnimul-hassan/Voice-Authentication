classdef VoiceAuthApp < matlab.apps.AppBase

    properties (Access = public)
        UIFigure             matlab.ui.Figure
        GridLayout           matlab.ui.container.GridLayout
        TitlePanel           matlab.ui.container.Panel
        TitleLabel           matlab.ui.control.Label
        MainTabGroup         matlab.ui.container.TabGroup
        
        % --- TAB 1: ENROLLMENT ---
        EnrollTab            matlab.ui.container.Tab
        EnrollGrid           matlab.ui.container.GridLayout
        
        % Left Control Panel (Enroll)
        EnrollControlPanel   matlab.ui.container.Panel
        EnrollRecBtn         matlab.ui.control.Button
        EnrollPlayBtn        matlab.ui.control.Button
        EnrollLoadBtn        matlab.ui.control.Button
        EnrollSaveBtn        matlab.ui.control.Button
        EnrollDurationSpinner matlab.ui.control.Spinner
        EnrollDurationLabel  matlab.ui.control.Label
        EnrollStatusLabel    matlab.ui.control.Label
        
        % Right Visualization (Enroll)
        EnrollAxes           matlab.ui.control.UIAxes
        EnrollMFCCAxes       matlab.ui.control.UIAxes % NEW: For Visual Analysis of MFCC
        
        % --- TAB 2: VERIFICATION ---
        VerifyTab            matlab.ui.container.Tab
        VerifyGrid           matlab.ui.container.GridLayout
        
        % Top Control (Verify)
        VerifyRecBtn         matlab.ui.control.Button
        VerifyTestBtn        matlab.ui.control.Button
        VerifyDurationSpinner matlab.ui.control.Spinner
        VerifyLabel          matlab.ui.control.Label
        
        % Results (Verify)
        ResultPanel          matlab.ui.container.Panel
        ResultLamp           matlab.ui.control.Lamp
        ResultText           matlab.ui.control.Label
        ResultTable          matlab.ui.control.Table
        VerifyAxes           matlab.ui.control.UIAxes
        VerifyMFCCAxes       matlab.ui.control.UIAxes % NEW: For Visual Analysis of MFCC
    end

    % Properties for App Logic
    properties (Access = private)
        RecorderObj          % Audiorecorder object
        AudioData            % Raw audio vector
        Fs = 16000;          % Sample Rate
        NBits = 16;          % Bits
        TrainingFolder = 'training_audio_sample';
        IsAudioReady = false;
    end

    methods (Access = private)
        
        % --- HELPER: Pre-processing & Feature Extraction ---
        function[features, processed_x] = extractFeatures(app, x, fs)
            % 1. Mono conversion
            if size(x,2) > 1, x = mean(x,2); end
            
            % 2. DC Removal
            x = x - mean(x);
            
            % 3. Pre-emphasis
            x = filter([1 -0.97], 1, x);
            
            % 4. Normalize
            maxVal = max(abs(x));
            if maxVal > 0, x = x / maxVal; end
            
            % 5. Silence Removal
            idx = abs(x) > 0.02; 
            if any(idx)
                x = x(find(idx,1,'first'):find(idx,1,'last'));
            end
            
            processed_x = x; % Return processed audio if needed
            
            % 6. MFCC Extraction (Using Audio Toolbox)
            try
                win = hamming(round(0.025*fs), 'periodic');
                coeffs = mfcc(x, fs, ...
                    'NumCoeffs', 13, ...
                    'Window', win, ...
                    'OverlapLength', round(0.015*fs), ...
                    'LogEnergy', 'Ignore');
                features = coeffs(:, 1:13);
            catch ME
                % BUG 3 FIX: Fail loudly instead of using dummy features
                uialert(app.UIFigure, 'Audio Toolbox is required for MFCC extraction, or an error occurred.', 'Toolbox Error');
                rethrow(ME);
            end
        end

        % --- HELPER: Update Waveform Plot ---
        function updateWaveform(app, ax, data, titleText)
            plot(ax, data, 'Color', [0 0.447 0.741]);
            ax.Title.String = titleText;
            axis(ax, 'tight');
            ax.YLim = [-1 1];
            grid(ax, 'on');
        end
        
        % --- HELPER: Update MFCC Plot (NEW) ---
        function updateMFCC(app, ax, features, titleText)
            imagesc(ax, features');
            axis(ax, 'xy');
            colormap(ax, 'jet');
            ax.Title.String = titleText;
            ax.XLabel.String = 'Frames';
            ax.YLabel.String = 'MFCC Coefficients (1-13)';
        end
    end

    % --- CALLBACKS ---
    methods (Access = private)

        % 1. ENROLL: Record
        function EnrollRecBtnPushed(app, ~)
            duration = app.EnrollDurationSpinner.Value;
            app.EnrollStatusLabel.Text = 'Recording...';
            app.EnrollStatusLabel.FontColor = 'r';
            drawnow;
            
            try
                app.RecorderObj = audiorecorder(app.Fs, app.NBits, 1);
                recordblocking(app.RecorderObj, duration);
                
                app.AudioData = getaudiodata(app.RecorderObj);
                app.IsAudioReady = true;
                
                app.updateWaveform(app.EnrollAxes, app.AudioData, 'Recorded Waveform');
                
                % Display MFCC visually
                try
                    [features, ~] = app.extractFeatures(app.AudioData, app.Fs);
                    app.updateMFCC(app.EnrollMFCCAxes, features, 'MFCC Features (Recorded)');
                catch
                    % Ignore if too short for immediate plot
                end
                
                app.EnrollStatusLabel.Text = 'Recording Complete. Review or Save.';
                app.EnrollStatusLabel.FontColor = [0 0.5 0];
                
                % Enable buttons
                app.EnrollSaveBtn.Enable = 'on';
                app.EnrollPlayBtn.Enable = 'on';
            catch ME
                uialert(app.UIFigure, ME.message, 'Recording Error');
            end
        end

        % 2. ENROLL: Load File
        function EnrollLoadBtnPushed(app, ~)
            [file, path] = uigetfile({'*.wav';'*.mp3'}, 'Select Audio');
            if isequal(file, 0), return; end
            
            fullPath = fullfile(path, file);
            [x, f_in] = audioread(fullPath);
            if f_in ~= app.Fs
                x = resample(x, app.Fs, f_in);
            end
            
            app.AudioData = x;
            app.IsAudioReady = true;
            app.updateWaveform(app.EnrollAxes, app.AudioData, ['Loaded: ' file]);
            
            % Display MFCC visually
            try
                [features, ~] = app.extractFeatures(app.AudioData, app.Fs);
                app.updateMFCC(app.EnrollMFCCAxes, features, 'MFCC Features (Loaded)');
            catch
            end
            
            app.EnrollStatusLabel.Text = 'Audio Loaded.';
            app.EnrollSaveBtn.Enable = 'on';
            app.EnrollPlayBtn.Enable = 'on';
        end

        % 3. ENROLL: Play
        function EnrollPlayBtnPushed(app, ~)
            if ~isempty(app.AudioData)
                sound(app.AudioData, app.Fs);
            end
        end

        % 4. ENROLL: Save & Train
        function EnrollSaveBtnPushed(app, ~)
            if ~app.IsAudioReady, return; end
            
            % Ask for Name
            prompt = {'Enter Name for this Voice:'};
            dlgtitle = 'Save & Enroll';
            dims = [1 35];
            definput = {'User1'};
            answer = inputdlg(prompt, dlgtitle, dims, definput);
            
            if isempty(answer), return; end % Cancelled
            name = answer{1};
            
            % Ensure folder exists
            if ~exist(app.TrainingFolder, 'dir')
                mkdir(app.TrainingFolder);
            end
            
            try
                % A. Save WAV into correct folder (BUG 1 FIX)
                wavFile = fullfile(app.TrainingFolder,[name '.wav']);
                audiowrite(wavFile, app.AudioData, app.Fs);
                
                % B. Train Model (VQ Codebook)
                [features, ~] = app.extractFeatures(app.AudioData, app.Fs);
                
                if size(features,1) < 16
                    uialert(app.UIFigure, 'Recording too short for analysis. Please record a longer sample.', 'Error');
                    return;
                end
                
                M = 16; % Clusters
                % Changed Replicates to 5 to match core code
                [~, codebook] = kmeans(features, M, 'Replicates', 5);
                
                % C. Save Model into correct folder (BUG 1 FIX)
                save(fullfile(app.TrainingFolder, ['db_' name '.mat']), 'codebook');
                
                app.EnrollStatusLabel.Text =['Saved: ' name '.wav & Enrolled successfully.'];
                uialert(app.UIFigure, ['User ' name ' has been enrolled.'], 'Success');
                
            catch ME
                uialert(app.UIFigure,['Error saving/training: ' ME.message], 'Error');
            end
        end

        % 5. VERIFY: Record
        function VerifyRecBtnPushed(app, ~)
            duration = app.VerifyDurationSpinner.Value;
            app.ResultText.Text = 'Recording...';
            app.ResultText.FontColor = 'k';
            drawnow;
            
            app.RecorderObj = audiorecorder(app.Fs, app.NBits, 1);
            recordblocking(app.RecorderObj, duration);
            
            app.AudioData = getaudiodata(app.RecorderObj);
            app.IsAudioReady = true;
            
            app.updateWaveform(app.VerifyAxes, app.AudioData, 'Test Audio Waveform');
            
            % Display MFCC visually
            try[features, ~] = app.extractFeatures(app.AudioData, app.Fs);
                app.updateMFCC(app.VerifyMFCCAxes, features, 'MFCC Features (Test)');
            catch
            end
            
            app.ResultText.Text = 'Audio captured. Press Verify.';
            app.VerifyTestBtn.Enable = 'on';
        end

        % 6. VERIFY: Execute Test
        function VerifyTestBtnPushed(app, ~)
            if ~app.IsAudioReady, return; end
            
            % Get features of current test audio
            testFeatures = app.extractFeatures(app.AudioData, app.Fs);
            
            % BUG 2 FIX: Ensure test features aren't empty or too short before pdist2
            if isempty(testFeatures) || size(testFeatures,1) < 16
                uialert(app.UIFigure, 'Audio too short or silent. Please record a longer sample.', 'Error');
                return;
            end
            
            % Load all databases from correct folder (BUG 1 FIX)
            files = dir(fullfile(app.TrainingFolder, 'db_*.mat'));
            if isempty(files)
                uialert(app.UIFigure, 'No enrolled users found. Please Enroll first.', 'Error');
                return;
            end
            
            bestDist = inf;
            bestUser = 'Unknown';
            
            % Table Data Setup
            tblData = table('Size',[length(files), 2], ...
                'VariableTypes',{'string','double'}, ...
                'VariableNames',{'User','Distortion'});
            
            for k = 1:length(files)
                try
                    % BUG 1 FIX: Load codebook using full path
                    data = load(fullfile(files(k).folder, files(k).name), 'codebook');
                    
                    % Vector Quantization Distortion
                    dists = pdist2(testFeatures, data.codebook);
                    minDist = min(dists,[], 2);
                    avgDist = mean(minDist);
                    
                    userName = erase(files(k).name, {'db_', '.mat'});
                    
                    tblData.User(k) = userName;
                    tblData.Distortion(k) = avgDist;
                    
                    if avgDist < bestDist
                        bestDist = avgDist;
                        bestUser = userName;
                    end
                catch
                    % Skip corrupted files
                end
            end
            
            % Sort Table
            app.ResultTable.Data = sortrows(tblData, 'Distortion');
            
            % Threshold Logic
            THRESHOLD = 1.5; % Tuned to core code
            
            if bestDist < THRESHOLD
                app.ResultText.Text = ['Access Granted: ' bestUser];
                app.ResultText.FontColor = [0 0.5 0];
                app.ResultLamp.Color =[0 1 0]; % Green
            else
                app.ResultText.Text = 'Access Denied (User not found)';
                app.ResultText.FontColor = [1 0 0];
                app.ResultLamp.Color = [1 0 0]; % Red
            end
        end
    end

    % --- UI CREATION ---
    methods (Access = private)

        function createComponents(app)
            % Main Window
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 750 650]; % Slightly taller to fit new axes
            app.UIFigure.Name = 'Voice Authentication System';
            
            % Grid Layout
            app.GridLayout = uigridlayout(app.UIFigure);
            app.GridLayout.ColumnWidth = {'1x'};
            app.GridLayout.RowHeight = {50, '1x'};
            
            % Title
            app.TitlePanel = uipanel(app.GridLayout);
            app.TitlePanel.BackgroundColor = [0.2 0.2 0.2];
            app.TitleLabel = uilabel(app.TitlePanel);
            app.TitleLabel.Text = 'Voice Security System';
            app.TitleLabel.FontColor = 'w';
            app.TitleLabel.FontSize = 22;
            app.TitleLabel.FontWeight = 'bold';
            app.TitleLabel.Position = [20 10 400 30];
            
            % Tabs
            app.MainTabGroup = uitabgroup(app.GridLayout);
            
            % === TAB 1: ENROLLMENT ===
            app.EnrollTab = uitab(app.MainTabGroup);
            app.EnrollTab.Title = '1. Enrollment';
            app.EnrollGrid = uigridlayout(app.EnrollTab);
            app.EnrollGrid.ColumnWidth = {200, '1x'};
            app.EnrollGrid.RowHeight = {'1x', '1x'}; % 2 Rows for Waveform + MFCC
            
            % Enroll Left Panel
            app.EnrollControlPanel = uipanel(app.EnrollGrid);
            app.EnrollControlPanel.Layout.Row = [1 2]; % Span both rows
            app.EnrollControlPanel.Layout.Column = 1;
            app.EnrollControlPanel.Title = 'Controls';
            
            % Duration
            app.EnrollDurationLabel = uilabel(app.EnrollControlPanel);
            app.EnrollDurationLabel.Text = 'Seconds:';
            app.EnrollDurationLabel.Position = [10 430 60 22];
            
            app.EnrollDurationSpinner = uispinner(app.EnrollControlPanel);
            app.EnrollDurationSpinner.Limits =[1 10];
            app.EnrollDurationSpinner.Value = 3;
            app.EnrollDurationSpinner.Position = [80 430 80 22];
            
            % Record Button
            app.EnrollRecBtn = uibutton(app.EnrollControlPanel, 'push');
            app.EnrollRecBtn.Text = 'Record New';
            app.EnrollRecBtn.BackgroundColor =[0.8 0.3 0.3];
            app.EnrollRecBtn.FontColor = 'w';
            app.EnrollRecBtn.FontWeight = 'bold';
            app.EnrollRecBtn.Position = [10 380 160 35];
            app.EnrollRecBtn.ButtonPushedFcn = createCallbackFcn(app, @EnrollRecBtnPushed, true);
            
            % Load Button
            app.EnrollLoadBtn = uibutton(app.EnrollControlPanel, 'push');
            app.EnrollLoadBtn.Text = 'Load from File';
            app.EnrollLoadBtn.Position = [10 335 160 30];
            app.EnrollLoadBtn.ButtonPushedFcn = createCallbackFcn(app, @EnrollLoadBtnPushed, true);
            
            % Play Button
            app.EnrollPlayBtn = uibutton(app.EnrollControlPanel, 'push');
            app.EnrollPlayBtn.Text = 'Play Audio';
            app.EnrollPlayBtn.Enable = 'off';
            app.EnrollPlayBtn.Position =[10 290 160 30];
            app.EnrollPlayBtn.ButtonPushedFcn = createCallbackFcn(app, @EnrollPlayBtnPushed, true);
            
            % Save Button
            app.EnrollSaveBtn = uibutton(app.EnrollControlPanel, 'push');
            app.EnrollSaveBtn.Text = 'SAVE & TRAIN';
            app.EnrollSaveBtn.BackgroundColor = [0 0.5 0];
            app.EnrollSaveBtn.FontColor = 'w';
            app.EnrollSaveBtn.FontWeight = 'bold';
            app.EnrollSaveBtn.Enable = 'off';
            app.EnrollSaveBtn.Position = [10 230 160 40];
            app.EnrollSaveBtn.ButtonPushedFcn = createCallbackFcn(app, @EnrollSaveBtnPushed, true);
            
            % Status
            app.EnrollStatusLabel = uilabel(app.EnrollControlPanel);
            app.EnrollStatusLabel.Text = 'Ready to record.';
            app.EnrollStatusLabel.Position =[10 20 180 60];
            app.EnrollStatusLabel.WordWrap = 'on';
            
            % Enroll Right Panel (Waveform)
            app.EnrollAxes = uiaxes(app.EnrollGrid);
            app.EnrollAxes.Layout.Row = 1;
            app.EnrollAxes.Layout.Column = 2;
            title(app.EnrollAxes, 'Audio Signal');
            
            % Enroll Right Panel (MFCC - NEW)
            app.EnrollMFCCAxes = uiaxes(app.EnrollGrid);
            app.EnrollMFCCAxes.Layout.Row = 2;
            app.EnrollMFCCAxes.Layout.Column = 2;
            title(app.EnrollMFCCAxes, 'MFCC Features');
            
            % === TAB 2: VERIFICATION ===
            app.VerifyTab = uitab(app.MainTabGroup);
            app.VerifyTab.Title = '2. Verification';
            app.VerifyGrid = uigridlayout(app.VerifyTab);
            app.VerifyGrid.ColumnWidth = {150, '1x', 200};
            app.VerifyGrid.RowHeight = {50, '1x', '1x', 150}; % Added row for MFCC
            
            % Top Controls
            app.VerifyLabel = uilabel(app.VerifyGrid);
            app.VerifyLabel.Text = 'Duration:';
            app.VerifyLabel.Layout.Row = 1; app.VerifyLabel.Layout.Column = 1;
            
            app.VerifyDurationSpinner = uispinner(app.VerifyGrid);
            app.VerifyDurationSpinner.Limits =[1 10];
            app.VerifyDurationSpinner.Value = 3;
            app.VerifyDurationSpinner.Layout.Row = 1; app.VerifyDurationSpinner.Layout.Column = 1;
            app.VerifyDurationSpinner.Position = [70 15 60 22]; 
            
            app.VerifyRecBtn = uibutton(app.VerifyGrid, 'push');
            app.VerifyRecBtn.Text = 'Record Probe';
            app.VerifyRecBtn.BackgroundColor =[0.8 0.3 0.3];
            app.VerifyRecBtn.FontColor = 'w';
            app.VerifyRecBtn.Layout.Row = 1; app.VerifyRecBtn.Layout.Column = 2;
            app.VerifyRecBtn.ButtonPushedFcn = createCallbackFcn(app, @VerifyRecBtnPushed, true);
            
            app.VerifyTestBtn = uibutton(app.VerifyGrid, 'push');
            app.VerifyTestBtn.Text = 'VERIFY IDENTITY';
            app.VerifyTestBtn.BackgroundColor = [0.2 0.6 0.9];
            app.VerifyTestBtn.FontColor = 'w';
            app.VerifyTestBtn.FontWeight = 'bold';
            app.VerifyTestBtn.Enable = 'off';
            app.VerifyTestBtn.Layout.Row = 1; app.VerifyTestBtn.Layout.Column = 3;
            app.VerifyTestBtn.ButtonPushedFcn = createCallbackFcn(app, @VerifyTestBtnPushed, true);
            
            % Waveform
            app.VerifyAxes = uiaxes(app.VerifyGrid);
            app.VerifyAxes.Layout.Row = 2; 
            app.VerifyAxes.Layout.Column =[1 3];
            title(app.VerifyAxes, 'Probe Signal');
            
            % MFCC - NEW
            app.VerifyMFCCAxes = uiaxes(app.VerifyGrid);
            app.VerifyMFCCAxes.Layout.Row = 3; 
            app.VerifyMFCCAxes.Layout.Column = [1 3];
            title(app.VerifyMFCCAxes, 'MFCC Features');
            
            % Results Panel
            app.ResultPanel = uipanel(app.VerifyGrid);
            app.ResultPanel.Layout.Row = 4;
            app.ResultPanel.Layout.Column =[1 3];
            app.ResultPanel.Title = 'Verification Results';
            
            % Lamp
            app.ResultLamp = uilamp(app.ResultPanel);
            app.ResultLamp.Position =[20 80 40 40];
            app.ResultLamp.Color =[0.8 0.8 0.8];
            
            % Big Text
            app.ResultText = uilabel(app.ResultPanel);
            app.ResultText.Text = 'Waiting for input...';
            app.ResultText.FontSize = 18;
            app.ResultText.FontWeight = 'bold';
            app.ResultText.Position = [80 80 300 40];
            
            % Table
            app.ResultTable = uitable(app.ResultPanel);
            app.ResultTable.Position = [450 10 250 110];
            app.ResultTable.ColumnName = {'User', 'Distortion'};
            app.ResultTable.RowName = {};

            % Show App
            app.UIFigure.Visible = 'on';
        end
    end

    % --- CONSTRUCTOR & DESTRUCTOR ---
    methods (Access = public)
        function app = VoiceAuthApp
            createComponents(app);
            
            % Create training folder if not exists
            if ~exist(app.TrainingFolder, 'dir')
                mkdir(app.TrainingFolder);
            end
        end

        function delete(app)
            delete(app.UIFigure);
        end
    end
end