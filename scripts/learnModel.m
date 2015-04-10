function [modelParams, mu_col, sigma_col, selectedFeatInd] = learnModel(train0, train1, windowLength, overlapSampleLength, ...
                                  Fs, classifierType)
% Using raw data from two classes, perform feature extraction, features 
% selection, and train a classifier.
%
% Inputs
%   train0: raw EEG data for class 0 [nbSamples, nbCh]
%   train1: raw EEG data for class 1 [nbSamples, nbCh]
%   windowLength: number of samples to use for extracting one feature
%   overlapSampleLength: overlap in number of samples between two successive
%                    windows
%   Fs: sampling frequency of the raw data
%   classifierType: 'SVM' or 'LR'
%
% Output
%   modelParams: object containing the parameters of the trained classifier
%   mu_col: average value of each feature (for z-score normalization)
%   sigma_col: std of each feature (for z-score normalization)
%   selectedFeatInd: indices of selected features

disp('Extracting features...');

%Extract features for class 0
electUsed = double(train0);

L = length(electUsed);
nbWin = floor(L/(windowLength - overlapSampleLength))-2;

for i = 0:nbWin-1
    % Get the window
    start = (windowLength - overlapSampleLength)*i + 1;
    finish = start + windowLength - 1;
    dataWin = electUsed(start:finish,:);
    
    if i == 0
        nFeatures = length(dataWin);
        featArray0 = zeros(nbWin,nFeatures);
    end
    
    [featArray0(i+1,:), ~] = featureExtract(dataWin, Fs, 0);
end

% Extract features for class 1
electUsed = double(train1);

L = length(electUsed);
nbWin = floor(L/(windowLength - overlapSampleLength))-2;
for i = 0:nbWin-1
    % Get the window
    start = (windowLength - overlapSampleLength)*i + 1;
    finish = start + windowLength - 1;
    dataWin = electUsed(start:finish,:);
    
    if i == 0
        nFeatures = length(dataWin);
        featArray1 = zeros(nbWin,nFeatures);
    end
    
    [featArray1(i+1,:), featNames] = featureExtract(dataWin, Fs, 1);
end

% Remove start and end of featArray
featArray0 = featArray0(2:end-2,:);
featArray1 = featArray1(2:end-2,:);

% Z-score normalize the features
featArrayAll = [featArray0; featArray1];
mu_col = nanmean(featArrayAll);
sigma_col = nanstd(featArrayAll);
featArray0 = (featArray0-repmat(mu_col,nbWin,1))./repmat(sigma_col,nbWin,1);
featArray1 = (featArray1-repmat(mu_col,nbWin,1))./repmat(sigma_col,nbWin,1);

% Select the best features
nSelectedFeat = 5;
selectedFeatInd = featureSelect(featArrayAll(:,1:end-1), featArrayAll(:,end), nSelectedFeat);
disp('Selected features: ')
disp(featNames(selectedFeatInd))

% Remove outliers from selected features
[outInd0] = findOutliers(featArray0(:,selectedFeatInd));
[outInd1] = findOutliers(featArray1(:,selectedFeatInd));
featArray0(outInd0,:) = [];
featArray1(outInd1,:) = [];

% Train the classifier
disp('Training the classifier...');
[modelParams, trainingAcc] = trainClassifier(featArray0(:,selectedFeatInd), featArray1(:,selectedFeatInd), classifierType);

% Plot the main results
figure('units','normalized','outerposition',[0 0 1 1])
subplot(3,1,1);
plot([train0, train1]')
xlabel('Time points')
ylabel('Raw EEG amplitude')
legend(electNames);
title(['Calibration session for Player', num2str(playerNb),' (train acc.: ',num2str(trainingAcc),')']);

subplot(3,1,2);
plot([featArray0(:,selectedFeatInd); featArray1(:,selectedFeatInd)])
xlabel('Time points')
ylabel('Normalized feature amplitude')
legend(featNames{selectedFeatInd});
title([num2str(nSelectedFeat),' best features over time'])

subplot(3,1,3);
boxplot([featArray0, featArray1], 'labels', [featNames, featNames],...
    'labelorientation','inline');
ylabel('Normalized feature amplitude')
title('Distribution of features for the two classes')

drawnow
pause(0.01);

disp('Training Done !');