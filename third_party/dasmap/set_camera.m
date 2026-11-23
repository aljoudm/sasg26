function set_camera(ax, target, cam)
% SET_CAMERA  Oblique perspective camera. az = compass bearing of the camera position seen from the
% target (200 = camera to the south-south-west looking north-north-east); el = elevation above horizon.
az = deg2rad(cam.az);  el = deg2rad(cam.el);
off = cam.dist * [sin(az) * cos(el), cos(az) * cos(el), sin(el)];
ax.Projection = 'perspective';
ax.CameraTarget = target;
ax.CameraPosition = target + off;
ax.CameraUpVector = [0 0 1];
ax.CameraViewAngle = cam.fov;
end
