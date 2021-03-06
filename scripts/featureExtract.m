function [featArray, featNames] = featureExtract(rawData, Fs, varargin)
%% Extract the features from the EEG.
% 
% Feature list:
% - Log-band powers
% - Log-ratios of band powers
% - [IMPLEMENTED BUT NOT USED FOR THE MOMENT]:
%   . Std of band powers
%   . Std of ratios of band power
%   . Temporal statistics (mean and std)
%   . Autoregressive model coefficients
%   . Entropy

% Inputs:
%   rawData: array of dimension [number of samples, number of channels]
%   Fs: sampling frequency of the raw data
%   [Optional] chNames: (cell) electrode names
%   [Optional] currentClass: (int) class of raw data
%   [Optional] plotY: (bool) if true, plot the PSD of the preprocessed data
% Outputs:
%   featArray: array of dimension [1, number of different features]
%   featNames: cell array containing the names of all the computed features

% TODO:
% - Extract band powers per channel instead of averaging over them!

% If it is calibration data, extract the class target from varargin
nVarargs = length(varargin);
switch nVarargs
    case 1
        chNames = varargin{1};
        plotY = false;
    case 2
        chNames = varargin{1};
        currentClass = varargin{2};
        plotY = false;
    case 3
        chNames = varargin{1};
        currentClass = varargin{2};
        plotY = varargin{3};
    otherwise
        chNames = {};
        currentClass = NaN;
        plotY = false;
end

%% 1. Compute the log-normalized PSD

[winSampleLength, nbCh] = size(rawData);
t = (0:winSampleLength-1)/Fs;
w = hamming(winSampleLength,'periodic');

% PCA (To use the PCA, we would need an heuristic to know which component to remove...)
% [coeff,score,~,~,~,~] = pca(rawData);
% componentsToKeep = [2,3,4];
% dataWinCentered = score(:,componentsToKeep)*coeff(componentsToKeep,:);

% Center raw data
% dataWinCentered = (rawData - repmat(mean(rawData),winSampleLength,1))./repmat(std(rawData),winSampleLength,1);
dataWinCentered = (rawData - repmat(mean(rawData),winSampleLength,1));

% Apply the Hamming window
dataWinCenteredHam = dataWinCentered.*repmat(w, 1, nbCh);

NFFT = 2^nextpow2(winSampleLength);
Y  = fft(dataWinCenteredHam, NFFT)/winSampleLength;
absY = (2*abs(Y(1:NFFT/2+1,:)));
f = Fs/2*linspace(0,1,NFFT/2+1);

%% 2. Bandpass the PCA-corrected time signals (not used)
% Wp = 0.1/Fs/2; Ws = 40/Fs/2;
% [n,Wn] = buttord(Wp,Ws,1,60);
% [b,a]=butter(n,Wn);
% dataWinFiltered = filter(b,a,dataWinCentered);
% dataWinFiltered = dataWinCentered;

%% 3. [Sanity check] Plot EEG and spectrum

% Plot logY
if plotY
    figure(101);
    
    subplot(4,1,1)
    plot(t, [rawData])
    legend('A1','Fp1','Fp2','A2')
    title(['Original signals (class ',num2str(currentClass),')']);
    ylabel('Amplitude')
    
    subplot(4,1,2)
    plot(t, [score])
    legend('PC1','PC2','PC3','PC4')
    title('Principal components')
    ylabel('Amplitude')
    
    subplot(4,1,3)
    plot(t, [dataWinCentered])
    legend('A1','Fp1','Fp2','A2')
    title('Reconstructed signals');
    xlabel('Time (s)')
    ylabel('Amplitude')
    
    subplot(4,1,4)
    plot(f, [absY])
    legend('A1','Fp1','Fp2','A2')
    title('PSD');
    xlabel('Frequency (Hz)')
    set(gca,'XTick',0:10:Fs/2)
    ylabel('Power')
    
    pause()
end

%% 4. Compute the features

% If no channel names were provided, make fake ones
if isempty(chNames)
    chNames = cell(nbCh,1);
    for i = 1:nbCh
        chNames{i} = ['ch',num2str(i)];
    end
end

% Define features to extract
featTypes = {'pwr-delta', ...
             'pwr-theta', ...
             'pwr-low-alpha', ...
             'pwr-high-alpha', ...
             'pwr-low-beta', ...
             'pwr-high-beta', ...
             ...
             'pwr-delta/beta', ...
             'pwr-theta/beta', ...
             'pwr-alpha/beta', ...
             'pwr-alpha/theta'};
         
nbFeatTypes = length(featTypes);

featNames = cell(nbFeatTypes*nbCh,1);
for i = 1:nbFeatTypes
    for j = 1:nbCh
        featNames{j+(i-1)*nbCh} = [featTypes{i},'-',chNames{j}];
    end
end

% SPECTRAL FEATURES
% Average and standard deviation of band powers
% Delta <4
ind_delta = (f<4);
meanDelta = mean(absY(ind_delta,:));
% stdDelta = std(absY(ind_delta,:),0,1);

% Theta 4-8
ind_theta = (f>=4 & f<=8);
meanTheta = mean(absY(ind_theta,:));
% stdTheta = std(absY(ind_theta,:),0,1);

% Low alpha 8-10
ind_low_alpha = (f>=8 & f<=10);
meanLowAlpha = mean(absY(ind_low_alpha,:));
% stdLowAlpha = std(absY(ind_low_alpha,alphaCh),0,1);

% High alpha 10-12
ind_high_alpha = (f>=10 & f<=12);
meanHighAlpha = mean(absY(ind_high_alpha,:));
% stdHighAlpha = std(absY(ind_high_alpha,alphaCh),0,1);

% Low beta 12-18
ind_low_beta = (f>=12 & f<=18);
meanLowBeta = mean(absY(ind_low_beta,:));
% stdLowBeta = std(absY(ind_low_beta,betaCh),0,1);

% High beta 18-20
ind_high_beta = (f>=18 & f<=30);
meanHighBeta = mean(absY(ind_high_beta,:));
% stdHighBeta = std(absY(ind_high_beta,betaCh),0,1);

% Fill the array of features
featArray = zeros(1,nbCh*nbFeatTypes);
featArray(1:nbCh) = meanDelta;
featArray(nbCh+1:2*nbCh) = meanTheta;
featArray(2*nbCh+1:3*nbCh) = meanLowAlpha;
featArray(3*nbCh+1:4*nbCh) = meanHighAlpha;
featArray(4*nbCh+1:5*nbCh) = meanLowBeta;
featArray(5*nbCh+1:6*nbCh) = meanHighBeta;

featArray(6*nbCh+1:7*nbCh) = meanDelta./(meanLowBeta+meanHighBeta);
featArray(7*nbCh+1:8*nbCh) = meanTheta./(meanLowBeta+meanHighBeta);
featArray(8*nbCh+1:9*nbCh) = (meanLowAlpha+meanLowBeta)./(meanLowBeta+meanHighBeta);
featArray(9*nbCh+1:10*nbCh) = (meanLowAlpha+meanLowBeta)./meanTheta;

% % Fill the array of features
% featArray(1) = mean(meanDelta);
% featArray(2) = mean(meanTheta);
% featArray(3) = mean(meanLowAlpha);
% featArray(4) = mean(meanHighAlpha);
% featArray(5) = mean(meanLowBeta);
% featArray(6) = mean(meanHighBeta);
% 
% featArray(7) = featArray(1)./(featArray(5)+featArray(6));
% featArray(8) = featArray(2)./(featArray(5)+featArray(6));
% featArray(9) = (featArray(3)+featArray(4))./(featArray(5)+featArray(6));
% featArray(10) = (featArray(3)+featArray(4))./featArray(2);

% Log-transform the band power features
featArray = log10(featArray);

% % Standard deviation features
% featArray(11) = mean(stdDelta);
% featArray(12) = mean(stdTheta);
% featArray(13) = mean(stdLowAlpha);
% featArray(14) = mean(stdHighAlpha);
% featArray(15) = mean(stdLowBeta);
% featArray(16) = mean(stdHighBeta);
% 
% featArray(17) = featArray(11)./(featArray(15)+featArray(16));
% featArray(18) = featArray(12)./(featArray(15)+featArray(16));
% featArray(19) = (featArray(13)+featArray(14))./(featArray(15)+featArray(16));
% featArray(20) = (featArray(13)+featArray(14))./featArray(12);

currFeatInd = length(featArray)+1;

% TEMPORAL FEATURES
% a) Mean and log variance of the amplitude values
%  This is functional, but not used for the moment.
% meanAmp = mean(dataWinCenteredHam);
% varAmp = log10(var(dataWinCenteredHam));
% 
% featArray(currFeatInd:currFeatInd+nbCh-1) = meanAmp;
% featArray(currFeatInd+nbCh:currFeatInd+2*nbCh-1) = varAmp;
% for j = 1:nbCh
%     featNames{end+1} = ['meanAmp_ch',num2str(j)];
%     featNames{end+1} = ['varAmp_ch',num2str(j)];
% end
% currFeatInd = length(featArray)+1;

% % b) Autoregressive model
% This is functional, but tends to mostly pick up noise, and thus leads to
% overfitting...
%
% order = 6;
% for i = 1:nbCh
%     arcoeff = aryule(dataWinCenteredHam(:,i),order);
%     featArray(currFeatInd:currFeatInd+order-1) = arcoeff(2:end);
%     currFeatInd = length(featArray)+1;
%     for j = order:-1:1 % skip the last coefficient! (It's always 1...)
%         featNames{end+1} = ['ar',num2str(order),'_coeff',num2str(j),'_ch',num2str(i)];
%     end
% end

% c) Information theoritic features
% Entropy
% This is functional, but not used for the moment.
% for i = 1:nbCh
%     signal = dataWinCenteredHam(:,i);
% 
%     % Get the normalized histogram
%     [nelements,xcenters] = hist(signal,50);
%     prob = nelements/trapz(xcenters,nelements);
%     H = -sum(prob(prob>0).*reallog(prob(prob>0)));
%     
%     featArray(currFeatInd) = H;
%     currFeatInd = length(featArray)+1;
%     featNames{end+1} = ['entropy_ch',num2str(i)];
% end

% d) Wavelet coefficients
% This is not yet functional.
% cw1 = cwt(dataWinFiltered(:,1),1:32,'sym2','plot'); 
% title('Continuous Transform, absolute coefficients.') 
% ylabel('Scale')
% [cw1,sc] = cwt(dataWinFiltered(:,1),1:32,'sym2','scal');
% title('Scalogram') 
% ylabel('Scale')


% Add the targets in featArray
% featArray(1,currFeatInd) = currentClass;

