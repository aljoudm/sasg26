function [L_hav_km, L_planar_km, A_km2] = ring_lengths(ring)
% RING_LENGTHS  Boundary length two ways: haversine (DAS-map compute_fibre method, R = 6371008.8 m) and the planar ring
% (equirectangular local frame, as used by the optimization). Area from the planar ring.
if norm(ring(1,:) - ring(end,:)) > 1e-9, ring(end+1,:) = ring(1,:); end
R = 6371008.8;  a = ring(1:end-1,:);  b = ring(2:end,:);
dlat = deg2rad(b(:,1) - a(:,1));  dlon = deg2rad(b(:,2) - a(:,2));
h = sin(dlat/2).^2 + cosd(a(:,1)) .* cosd(b(:,1)) .* sin(dlon/2).^2;
L_hav_km = sum(2 * R * asin(min(1, sqrt(h)))) / 1e3;
lat0 = mean(ring(:,1));  ky = 111195;  kx = 111195 * cosd(lat0);     % same constants as DAS-map compute_risk / intrinsic_risk_grid
x = (ring(:,2) - mean(ring(:,2))) * kx;  y = (ring(:,1) - lat0) * ky;
L_planar_km = sum(hypot(diff(x), diff(y))) / 1e3;
A_km2 = abs(polyarea(x, y)) / 1e6;
end
