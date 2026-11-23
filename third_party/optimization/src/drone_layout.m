function L = drone_layout(cells, P, stationXY, nDrones)
% DRONE_LAYOUT  Verification coverage of every cell for a given set of drone stations (used for the optimal solution AND the baselines).
%
%   L = drone_layout(cells, P, stationXY, nDrones)
%     stationXY  [m, local frame of load_cells] one row per station;  nDrones  drones at each station
%
% A station serves a cell if the farthest point of the cell is within R_resp (P.v.R_resp_m). A station with m drones has a ready
% drone with probability min(1, m * T_drone / (T_drone + T_charge)); a cell is ready with probability A_ver = 1 - prod(1 - A_station)
% over the stations that serve it, and has its verification layer if A_ver >= A_ver_min.
% Output: reach (station x cell), A_ver, verified, nearest (index of the station closest to the cell centre), nearest_dist_m,
% nearest_in_reach.
v = P.v;   ring = cells.ring;   n = cells.n;   S = size(stationXY, 1);
A1 = v.T_drone_min / (v.T_drone_min + v.T_charge_min);
aSt = min(1, nDrones(:)' * A1);                                   % ready probability of every station
sp = 1:10:numel(ring.x);   px = ring.x(sp);   py = ring.y(sp);   pcell = ring.cell(sp);
reach = false(S, n);   far = zeros(S, n);
for s = 1:S
    far(s, :) = accumarray(pcell, hypot(px - stationXY(s, 1), py - stationXY(s, 2)), [n 1], @max)';
    reach(s, :) = far(s, :) <= v.R_resp_m;
end
Aver = zeros(n, 1);
for i = 1:n, Aver(i) = 1 - prod(1 - aSt(reach(:, i))); end
cx = (cells.lon - ring.lon0) * ring.kx;   cy = (cells.lat - ring.lat0) * ring.ky;      % cell centres in the local frame
D = hypot(cx(:)' - stationXY(:, 1), cy(:)' - stationXY(:, 2));                          % S x n
[nd, ni] = min(D, [], 1);
inr = false(n, 1);   for i = 1:n, inr(i) = reach(ni(i), i); end
L = struct('reach', reach, 'A_ver', Aver, 'verified', Aver >= v.A_ver_min - 1e-12 & any(reach, 1)', 'nearest', ni(:), ...
    'nearest_dist_m', nd(:), 'nearest_in_reach', inr, 'station_ready_prob', aSt, 'centre_xy', [cx(:) cy(:)]);
end
