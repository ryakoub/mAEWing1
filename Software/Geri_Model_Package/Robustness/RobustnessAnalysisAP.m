% #######################################################################
%   Robust Control Design for Active Flutter Suppression
% #######################################################################
%   Julian Theis, Peter Seiler
% ########################################################################
%
% ### ANALYSIS PART ###
% last modified 2018-08-15 Julian Theis
%
% RUN PART1_DESIGN_ROBUSTFLUTTERSUPPRESSION FIRST
% uses variables in workspace, requires 
% GeriFDsysPID2_IO : model with physical inputs/outputs
% C : controller with physical inputs/outputs
% Vinf : vector of airspeed
%
% The controller needs to have the correct naming of inputs and outputs
% (matching the GeriFDsysPID2_IO model)
%% Define Example System / Controller
 load HinfController %loads H-Infinity controller as an example

 %BEST MIDAAS Controller so far...
%  load('C:\Users\bdanowsky\Documents\Work\1439 - PAAW\matlab\Geri_MIDAAS\Geri_MIDAAS_FluttSuppr_Rnd2_SET08_wrolloff.mat');
%  clear GeriFDsysPID2_IO %get rid of this to avoid conflicts
 
%% load some preliminary model stuff

addpath('./..'); %path to model PID box functions including the model function
addpath('../GeriACProps'); %path to model PID box functions including the model function
addpath('../PAAW_IDBox'); %path to model PID box functions including the model function

%load the data
load GeriACProps/Geri_Database
load GeriACProps/GerimassProp
load GeriACProps/GeriaeroPropNOM

%load initial guess and final data -----------------------------------------------------------------

%nominal model (before PID update)
load GeriACProps/GericoeffsNOM
coeffdataNOM = coeffdata;
coeffdataNOM.IputIx = [1:9];
coeffdata.IputIx = [1:9]; %never change this, just means use all inputs

%PID-updated coefficients
indat = load('GeriACProps/GericoeffsPIDUpdate.mat');
coeffdataPIDfull = indat.coeffsPIDfull;

ft2m = 0.3048;

load GeriActuators
engine_lag = tf(1); %tf(4,[1 4]); %tf(1); %perfect engines (for now, can be changed later)
actdata.G_surface_actuator = G_surface_actuator*Delay_25ms; %delays are included with actuators
actdata.engine_lag = engine_lag*Delay_25ms; %delay is included with engine model

load Geri_SensorModels
sensdata.G_sens_IMU = G_sens_IMU;
sensdata.G_sens_Accel = G_sens_Accel;

ikeep = [1,2,3,4,5,6,7,8,9]; % all flaps + throttle
% okeep = [1 3 5 7 4 8 13:18]; %uses q and p (mean axis rates)
okeep = [1 3 5 7 10 11 13:18]; %uses qcg and pcg (sensor rates, more correct)

%bare airframe as a function of velocity 
gerifunc = @(Vmps)NdofwActSens(okeep,ikeep,AEC6,ModeShape,FEM,Vmps,aeroProp,massProp,...
    coeffdataPIDfull,actdata,sensdata);


%% generate models

Vinf = 20:0.5:45;

% generate complete model of the aircraft at various airspeeds
clear P
for ii=1:numel(Vinf)
%     [~, temp] = GenerateGeriModelAP(Vinf(ii));
    temp = gerifunc(Vinf(ii));
    P(:,:,ii) = temp;
%     P(:,:,ii) = modred(temp([1:2,4:12],:),17,'truncate');
end
GeriFDsysPID2_IO = P; %to be used in AnalysisSimAP
close all; clc

w = {0.01, 1000}; %relevant frequency range for plotting

AFCS = ss(zeros(size(P,2),size(P,1)));
AFCS.InputName = P.OutputName;
AFCS.OutputName = P.InputName;

AFCS(C.OutputName,C.InputName) = C;    % Flutter Suppression

load BaseLineController
load standard_sos
AFCS('Thrust','u') = AutoThrottle;                 % Autothrottle
AFCS({'L2','R2'},'pcg') = [1;-1]*RollDamper;       % Roll Damper
AFCS({'L2','R2'},'phi') = [1;-1]*RollController;   % Bank Angle Control
AFCS({'L3','R3'},{'theta','h'}) = [1;1]*ss(PitchController)*[1 AltitudeController]; % Pitch Angle and Altitude Control

%% Robustness Margins
% Robustness margins are calculated using the LOOPMARGIN command (called
% inside the function DisplayLoopmargin which also prints the data to the workspace)
%
% The considered metrics here are 
% - the classical single loop margins at both input and output 
% - the multi loop input disk margin 
%   (simultaneous gain and phase perturbation in all inputs)
% - the multi loop output disk margin 
%   (simultaneous gain and phase perturbation in all outputs)
% - the multi loop output disk margin 
%   (simultaneous gain and phase perturbation in all outputs)
% - the multi loop IO disk margin 
%   (simultaneous gain and phase perturbation in all inputs AND outputs)
%
% Covers the following points from our discussion:
%  * single loop margins for all individual feedback loops that are closed by the respective controllers
%  ** classical gain and phase margins
%  ** (symmetric) disk margins
%  ** delay margins
%  * multi loop margins for all simultaneously closed feedback loops by the respective controller
%  ** (symmetric) disk margins


for ii=1:numel(Vinf)
    fprintf('\nModel at airspeed %2.1f m/s:\n', Vinf(ii))
[ICM_G(:,ii), ICM_P(:,ii), ICM_D(:,ii), IDM_G(:,ii), IDM_P(:,ii), ...
 OCM_G(:,ii), OCM_P(:,ii), OCM_D(:,ii), ODM_G(:,ii), ODM_P(:,ii), ...
 MMI_G(:,ii), MMI_P(:,ii), MMO_G(:,ii), MMO_P(:,ii), MMIO_G(:,ii), MMIO_P(:,ii)] = ...
 DisplayLoopmargin(P(:,:,ii),AFCS);
end

%calculate Robust and Absolute Flutter Speed

[RFS, AFS, vis] = CalculateRobustFlutterSpeed(ICM_P,OCM_P,ICM_G,OCM_G,Vinf);
fprintf('Robust Flutter Speed: %2.1f \nAbsolute Flutter Speed: %2.1f \n',RFS,AFS)


% plot of minimum classical phase margin at input over airspeed
InputPhase = ICM_P; InputPhase(InputPhase>=90)=90; InputPhase(InputPhase==0)=-Inf;
figure; plot(Vinf,InputPhase,'LineWidth',3); title('Minimum Input Phase Margin'); xlabel('airspeed'); ylabel('degrees');legend(P.InputName(:),'Location','southwest')
xlim([Vinf(1) Vinf(end)]); ylim([0 90]);
hold on; plot([AFS AFS],[0 90],'k--','LineWidth',3); 
% area(vis.RFS_P_x, vis.RFS_P_y); hold off;
fill(vis.RFS_P_x, vis.RFS_P_y,[1 0.7 0.7],'LineStyle','none'); hold off;
legend([P.InputName(:);['AFS = ' num2str(AFS,'%2.1f') ' m/s'];['RFS = ' num2str(RFS,'%2.1f') ' m/s']],'Location','best')
grid on

% plot of minimum classical gain margin at input over airspeed
InputGain = abs(db(ICM_G));
figure; semilogy(Vinf,InputGain,'LineWidth',3); title('Minimum Input Gain Margin'); xlabel('airspeed'); ylabel('dB');legend(P.InputName(:),'Location','southwest')
xlim([Vinf(1) Vinf(end)]); ylim([0 40]);
hold on; plot([AFS AFS],[1 100],'k--','LineWidth',3); 
% area(vis.RFS_G_x, vis.RFS_G_y); hold off;
ylims = vis.RFS_G_y;
ylims(ylims==0) = 1;
fill(vis.RFS_G_x, ylims,[1 0.7 0.7],'LineStyle','none'); hold off;
ylim([1 100]);
legend([P.InputName(:);['AFS = ' num2str(AFS,'%2.1f') ' m/s'];['RFS = ' num2str(RFS,'%2.1f') ' m/s']],'Location','best')
grid on

% plot of minimum classical phase margin at output over airspeed
OutputPhase = OCM_P; OutputPhase(OutputPhase>=90)=90; OutputPhase(OutputPhase==0)=-Inf;
figure; plot(Vinf,OutputPhase,'LineWidth',3); title('Minimum Output Phase Margin'); xlabel('airspeed'); ylabel('degrees');legend(P.OutputName(:),'Location','southwest')
xlim([Vinf(1) Vinf(end)]); ylim([0 90]);
hold on; plot([AFS AFS],[0 90],'k--','LineWidth',3); 
% area(vis.RFS_P_x, vis.RFS_P_y); hold off;
fill(vis.RFS_P_x, vis.RFS_P_y,[1 0.7 0.7],'LineStyle','none'); hold off;
legend([P.OutputName(:);['AFS = ' num2str(AFS,'%2.1f') ' m/s'];['RFS = ' num2str(RFS,'%2.1f') ' m/s']],'Location','best')
grid on

% plot of minimum classical gain margin at output over airspeed
OutputGain = abs(db(OCM_G));
figure; semilogy(Vinf,OutputGain,'LineWidth',3); title('Minimum Output Gain Margin'); xlabel('airspeed'); ylabel('dB');legend(P.OutputName(:),'Location','southwest')
xlim([Vinf(1) Vinf(end)]);
hold on; plot([AFS AFS],[1 100],'k--','LineWidth',3); 
% area(vis.RFS_G_x, vis.RFS_G_y); hold off;
ylims = vis.RFS_G_y;
ylims(ylims==0) = 1;
fill(vis.RFS_G_x, ylims,[1 0.7 0.7],'LineStyle','none');
ylim([1 100])
legend([P.OutputName(:);['AFS = ' num2str(AFS,'%2.1f') ' m/s'];['RFS = ' num2str(RFS,'%2.1f') ' m/s']],'Location','best')
grid on

%% Closed-Loop Transfer Function Analysis
% All relevant closed-loop (or broken loop) transfer functions are 
% calculated by LOOPSENS:
% So  : output sensitivity (I+P*C)^-1     with plant P and compensator C
% Si  : input sensitivity (I+C*P)^-1
% To  : complementary output sensitivity P*C(I+P*C)^-1
% Ti  : complementary input sensitivity C*P(I+C*P)^-1
% CSo : controller sensitivity 
% PSi : sensitivity to input disturbances

% Covers the following points from our discussion:
% * multi loop margins for all simultaneously closed feedback loops by the respective controller
%   ** (non-symmetric) disk margins, i.e. peaks of S and T
% * structured uncertainty descriptions
% ** combinations of dynamic actuator, plant, and sensor uncertainty

% check at robust flutter speed
DisplayLoopsens(P(:,:,Vinf==RFS),AFCS,w,'g'); %plot gang of six Singular Values

DisplayLoopsens(P(:,:,Vinf==RFS),AFCS,w,'ui'); %plot allowable dynamic multiplicative uncertainty in each input
DisplayLoopsens(P(:,:,Vinf==RFS),AFCS,w,'uo'); %plot allowable dynamic multiplicative uncertainty in each output
DisplayLoopsens(P(:,:,Vinf==RFS),AFCS,w,'ua'); %plot allowable dynamic additive uncertainty
DisplayLoopsens(P(:,:,Vinf==RFS),AFCS,w,'si'); %plot allowable dynamic multiplicative uncertainty in each output
[~, Peaks] = DisplayLoopsens(P(:,:,Vinf==RFS),AFCS,w,'so') %plot allowable dynamic multiplicative uncertainty in each input



%% QUALITATIVE (Root Loci)
% * root loci over airspeed and how they are affected by feedback
% * root loci over airspeed for samples of parametrically perturbed model (structural mode frequency/damping)
% * flutter speed predicted by root-loci (also under uncertainty)

varypzmap(P)
caxis([Vinf(1) Vinf(end)])
xlim([-60,10])
ylim([0,60])
sgrid

varypzmap(feedback(P,AFCS))
caxis([Vinf(1) Vinf(end)])
xlim([-60,10])
ylim([0,60])
sgrid
%% FURTHER ANALYSIS 
% perform time-domain simulation in Simulink using rate-limited and
% saturated control surfaces and the autopilot modules in the loop
open AnalysisSimAp



