function rp = reliability_params()
%RELIABILITY_PARAMS  Failure data for the essential-bus fault tree.
%
%   ILLUSTRATIVE orders of magnitude for a study, not qualified data. Real
%   numbers come from supplier reliability predictions and in-service data.
rp.lambda_gen  = 1.0e-4;   % [1/fh] generator channel (generator + GCU + feeder + GLC)
rp.beta_ccf    = 0.02;     % [-] common-cause fraction for losing both generators at once
rp.p_apu_start = 0.05;     % [-] in-flight APU start failure probability on demand
rp.lambda_apu  = 5.0e-4;   % [1/fh] APU running failure
rp.lambda_batt = 2.0e-5;   % [1/fh] battery pack + BMS
rp.lambda_bcru = 3.0e-5;   % [1/fh] battery converter
rp.lambda_efc  = 5.0e-6;   % [1/fh] each essential feed contactor path (EFC1, EFC2)
rp.lambda_hve  = 1.0e-7;   % [1/fh] essential busbar fault (single point in the baseline)
rp.beta_bus    = 0.005;    % [-] common-cause fraction between the two halves of a split essential bus
rp.apu_start_time_h = 45 / 3600;
% CS-25.1309 / AC 25.1309-1 style targets [per flight hour]
rp.target_catastrophic = 1e-9;
rp.target_hazardous    = 1e-7;
end
