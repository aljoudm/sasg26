function tgt = main_target(scene)
% MAIN_TARGET  Camera target of the main view: centre of the fibre's bounding box.
F = scene.fibre;
tgt = [mean([min(F.x) max(F.x)]), mean([min(F.y) max(F.y)]), 1];
end
