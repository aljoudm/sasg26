function P = backscatter_power(m, z)
% BACKSCATTER_POWER  Analytic Rayleigh backscatter power [W] returned from distance z [m] along ONE channel
% (same model as DAS-Simulation). All parameters come from map_params.m:
%   P_bs(z) = P0 * 10^((R_bs_dB + 10*log10(tau/1e-9))/10) * 10^(-2*alpha_dB_km*z/1e4)
P = m.P0 * 10 .^ ((m.R_bs_dB + 10 * log10(m.tau / 1e-9)) / 10) .* 10 .^ (-2 * m.alpha_dB_km * z / 1e4);
end
