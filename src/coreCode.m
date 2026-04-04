clc;
clear;
close all;

disp('==================================================');
disp('   Text-Dependent Voice Password System (BUET)    ');
disp('==================================================');
disp('1. Enroll a New User');
disp('2. Verify a User');
disp('3. Exit');
disp('--------------------------------------------------');

choice = input('Enter choice (1/2/3): ');

if choice == 3
    disp('Exiting...');
    return;
end

% ---------------- File input ----------------
if choice == 1
    disp('--- ENROLLMENT MODE ---');
    defaultFile = 'train.wav';
else
    disp('--- VERIFICATION MODE ---');
    defaultFile = 'test.wav';
end

filename = input(['Enter filename (Enter = ' defaultFile '): '],'s');
if isempty(filename)
    filename = defaultFile;
end

 % Try to locate file automatically
    if ~exist(filename,'file')
    [file, path] = uigetfile('*.wav','Select audio file');
    if isequal(file,0)
        error('No audio file selected.');
    end
    filename = fullfile(path,file);
    end

% ---------------- Read audio ----------------
[x, fs] = audioread(filename);

% Convert to mono in case of sterio sound
if size(x,2) > 1
    x = mean(x,2);
end

% DC removal (0 hz frequency components)
x = x - mean(x);

% Pre-emphasis high pass filter with feedforward and feedback
x = filter([1 -0.97],1,x);

% Normalize the magnitude 
x = x / max(abs(x));

% Simple silence removal from the start and end
idx = abs(x) > 0.02;
x = x(find(idx,1,'first'):find(idx,1,'last'));

% ---------------- MFCC extraction ----------------
% applying 25ms hamming window to smooth out spectral leakage 
win = hamming(round(0.025*fs), 'periodic');

coeffs = mfcc(x, fs, ...
    'NumCoeffs', 13, ...
    'Window', win, ...
    'OverlapLength', round(0.015*fs), ...
    'LogEnergy', 'Ignore');   % IMPORTANT
features = coeffs(:,1:13);   % SAFETY
% Here, we are applying FFT(Fast-fourier transform) and 
% Mel filter bank maps spectrum to non-linear Mel scale.
% Log + DCT(Discrete cosine transform) produce compact MFCC features.

% ================== ENROLL ==================
if choice == 1
    user = input('Enter User ID: ','s');
    if isempty(user)
        user = 'User1';
    end
    % Vector Quantization: Your 200x13 features matrix is too big to easily 
    % compare later. The K-Means algorithm groups those 200 rows into 
    % exactly 16 average clusters (centroids).
    M = 16; 
   [~,codebook]= kmeans(features, M, 'Replicates', 5);

    save(['db_' user '.mat'], 'codebook');
    disp(['User "' user '" enrolled successfully.']);

% ================== VERIFY ==================
else
    db = dir('db_*.mat');
    if isempty(db)
        error('No enrolled users found.');
    end

    bestDist = inf;
    bestUser = 'None';

    fprintf('\n%-15s | %-10s\n','User','Distortion');
    fprintf('-------------------------------\n');

    for k = 1:length(db)
        load(db(k).name); % loads codebook

        D = mean(min(pdist2(features, codebook),[],2));
        % this returns the closest avarage distortion among co-efficient
        name = erase(db(k).name, {'db_','.mat'});
        fprintf('%-15s | %.4f\n', name, D);

        if D < bestDist
            bestDist = D;
            bestUser = name;
        end
    end

    THRESHOLD = 2;   % tune experimentally
    fprintf('-------------------------------\n');

    if bestDist < THRESHOLD
        fprintf('ACCESS GRANTED → %s\n', bestUser);
    else
        fprintf('ACCESS DENIED\n');
    end
end
