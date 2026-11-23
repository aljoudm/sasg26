{
const LAT0 = 25.76607975, LON0 = 45.58630745, KX = 100.13957936, KY = 111.195;   // km per degree
const ZC = {1: 0x4575B5, 2: 0xE3B02B, 3: 0xD63026}, ZN = {1: "Cold", 2: "Neutral", 3: "Hot"}, ZCSS = {1: "var(--cold)", 2: "var(--neut)", 3: "var(--hot)"};
const PC = 0.983, M = 0.001;   // 1 m in scene units (km)
const EV = {walking: {label: "Walking", ai: "human (walking)", threat: true},
            digging: {label: "Digging", ai: "digging (cable-theft risk)", threat: true},
            vehicle: {label: "Vehicle", ai: "vehicle", threat: false}};
const $ = id => document.getElementById(id);
const mapEl = $("map");
let VE = 4, dem, fib, terrain, fibreGroup, eventGroup, fenceGroup, camsNear, camsClose, camsHead, pulses = [], chPts = [[], []];
let lastEvent = null, evType = "walking", seq = 0, actor = null, act = null, lod = "far";
const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;

const xz = (lat, lon) => [(lon - LON0) * KX, -(lat - LAT0) * KY];
const ll = (x, z) => [LAT0 - z / KY, LON0 + x / KX];
// height of the drawn terrain surface itself (same triangles as the mesh), metres
function hAt(lat, lon) {
  const fx = (lon - dem.lon_w) / (dem.lon_e - dem.lon_w) * (dem.nx - 1), fy = (dem.lat_n - lat) / (dem.lat_n - dem.lat_s) * (dem.ny - 1);
  const i = Math.max(0, Math.min(dem.nx - 2, Math.floor(fx))), j = Math.max(0, Math.min(dem.ny - 2, Math.floor(fy)));
  const u = Math.min(1, Math.max(0, fx - i)), v = Math.min(1, Math.max(0, fy - j)), z = dem.z, n = dem.nx;
  const a = z[j*n+i], b = z[j*n+i+1], c = z[(j+1)*n+i], d = z[(j+1)*n+i+1];
  return (u + v <= 1 ? a + u*(b-a) + v*(c-a) : d + (1-u)*(c-d) + (1-v)*(b-d)) / 10;
}
const yOf = h => (h - dem.zmin) / 1000 * VE;
const groundY = (x, z) => yOf(hAt(...ll(x, z)));

const renderer = new THREE.WebGLRenderer({antialias: true, logarithmicDepthBuffer: true});
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
mapEl.prepend(renderer.domElement);
const scene = new THREE.Scene();
scene.background = new THREE.Color(0xcfc6b6);
scene.fog = new THREE.Fog(0xcfc6b6, 14, 30);
const camera = new THREE.PerspectiveCamera(35, 1, 0.0005, 120);
const pipCam = new THREE.PerspectiveCamera(32, 1.5, 0.0005, 5);
const controls = new THREE.OrbitControls(camera, renderer.domElement);
controls.enableDamping = true; controls.maxPolarAngle = 1.5; controls.minDistance = 0.012; controls.maxDistance = 30;
controls.screenSpacePanning = false;
scene.add(new THREE.HemisphereLight(0xffffff, 0x8a7a66, 0.75));
const sun = new THREE.DirectionalLight(0xffffff, 0.8); sun.position.set(-6, 5, -6); scene.add(sun);

function resize() {
  const w = mapEl.clientWidth, h = mapEl.clientHeight;
  renderer.setSize(w, h, false); camera.aspect = w / h; camera.updateProjectionMatrix();
}
new ResizeObserver(resize).observe(mapEl);
async function img(url) { const b = await (await fetch(url)).blob(); return await createImageBitmap(b); }

function buildTerrain(baseImg, plantImg) {
  const bt = fib.base_tex, pt = fib.plant_tex;
  const cw = 4096, chh = Math.round(4096 * baseImg.height / baseImg.width);
  const cv = document.createElement("canvas"); cv.width = cw; cv.height = chh;
  const g = cv.getContext("2d"); g.drawImage(baseImg, 0, 0, cw, chh);
  const px = lon => (lon - bt.lon_w) / (bt.lon_e - bt.lon_w) * cw, py = lat => (bt.lat_n - lat) / (bt.lat_n - bt.lat_s) * chh;
  g.drawImage(plantImg, px(pt.lon_w), py(pt.lat_n), px(pt.lon_e) - px(pt.lon_w), py(pt.lat_s) - py(pt.lat_n));
  const tex = new THREE.CanvasTexture(cv); tex.anisotropy = renderer.capabilities.getMaxAnisotropy(); tex.encoding = THREE.sRGBEncoding;
  const nx = dem.nx, ny = dem.ny, pos = new Float32Array(nx * ny * 3), uv = new Float32Array(nx * ny * 2), idx = [];
  for (let j = 0; j < ny; j++) for (let i = 0; i < nx; i++) {
    const lon = dem.lon_w + (dem.lon_e - dem.lon_w) * i / (nx - 1), lat = dem.lat_n - (dem.lat_n - dem.lat_s) * j / (ny - 1);
    const [x, z] = xz(lat, lon), k = j * nx + i;
    pos[k*3] = x; pos[k*3+1] = yOf(dem.z[k] / 10); pos[k*3+2] = z;
    uv[k*2] = (lon - bt.lon_w) / (bt.lon_e - bt.lon_w); uv[k*2+1] = (lat - bt.lat_s) / (bt.lat_n - bt.lat_s);
    if (i < nx - 1 && j < ny - 1) idx.push(k, k + nx, k + 1, k + 1, k + nx, k + nx + 1);
  }
  const geo = new THREE.BufferGeometry();
  geo.setAttribute("position", new THREE.BufferAttribute(pos, 3)); geo.setAttribute("uv", new THREE.BufferAttribute(uv, 2));
  geo.setIndex(idx); geo.computeVertexNormals();
  terrain = new THREE.Mesh(geo, new THREE.MeshLambertMaterial({map: tex}));
  scene.add(terrain);
}
function updateTerrainHeights() {
  const p = terrain.geometry.attributes.position;
  for (let k = 0; k < p.count; k++) p.setY(k, yOf(dem.z[k] / 10));
  p.needsUpdate = true; terrain.geometry.computeVertexNormals();
}

let fpts = [];
function fibreVec(k, lift) { const [x, z] = xz(fib.lat[k], fib.lon[k]); return new THREE.Vector3(x, groundY(x, z) + lift, z); }
// frame at fibre point k: tangent t, outward normal o (away from the plant centre)
function frameAt(k) {
  const n = fpts.length, a = fpts[(k + 1) % n], b = fpts[(k - 1 + n) % n];
  const t = new THREE.Vector3(a.x - b.x, 0, a.z - b.z).normalize();
  const o = new THREE.Vector3(-t.z, 0, t.x), p = fpts[k];
  if (o.x * p.x + o.z * p.z < 0) o.negate();
  return {t, o};
}
const LODS = [["far", 0.018, 0.055, 0.006], ["near", 0.005, 0.016, 0.003], ["close", 0.0002, 0.0006, 0.0003]];
function buildFibre() {
  if (fibreGroup) scene.remove(fibreGroup);
  fibreGroup = new THREE.Group(); scene.add(fibreGroup);
  const n = fib.lat.length; fpts = [];
  for (let k = 0; k < n; k++) fpts.push(fibreVec(k, 0));
  for (const [name, core, glow, lift] of LODS) {
    let start = 0;
    while (start < n) {
      let end = start; while (end + 1 < n && fib.zone[end + 1] === fib.zone[start]) end++;
      const ids = []; for (let k = start; k <= Math.min(n - 1, end + 1); k++) ids.push(k); if (end + 1 >= n) ids.push(0);
      const run = ids.map(k => fibreVec(k, lift));
      if (name === "close") {   // follow the ground closely: densify the run
        const dense = []; for (let q = 0; q < run.length - 1; q++) for (let s = 0; s < 8; s++) {
          const x = run[q].x + (run[q+1].x - run[q].x) * s / 8, z = run[q].z + (run[q+1].z - run[q].z) * s / 8;
          dense.push(new THREE.Vector3(x, groundY(x, z) + lift, z)); }
        dense.push(run[run.length - 1]); run.length = 0; run.push(...dense);
      }
      if (run.length >= 2) {
        const curve = new THREE.CatmullRomCurve3(run, false, "centripetal"), seg = Math.max(8, run.length * (name === "close" ? 1 : 3)), col = ZC[fib.zone[start]];
        const a = new THREE.Mesh(new THREE.TubeGeometry(curve, seg, core, 6, false), new THREE.MeshBasicMaterial({color: col}));
        const b = new THREE.Mesh(new THREE.TubeGeometry(curve, seg, glow, 6, false),
          new THREE.MeshBasicMaterial({color: col, transparent: true, opacity: 0.3, depthWrite: false, blending: THREE.AdditiveBlending}));
        a.userData.lod = b.userData.lod = name; fibreGroup.add(a, b);
      }
      start = end + 1;
    }
  }
  chPts = [[], []]; const e = fib.entry;
  for (let s = 0; s < n; s++) { const a = (e + s) % n, b = (e - s + n) % n; if (fib.ch[a] === 1) chPts[0].push(fpts[a]); if (fib.ch[b] === 2) chPts[1].push(fpts[b]); }
  const [bx, bz] = xz(fib.building[0], fib.building[1]), by = groundY(bx, bz);
  const iu = new THREE.Mesh(new THREE.BoxGeometry(0.03, 0.012, 0.02), new THREE.MeshLambertMaterial({color: 0xf2f2f2}));
  iu.position.set(bx, by + 0.006, bz); fibreGroup.add(iu);
  const lead = new THREE.CatmullRomCurve3([new THREE.Vector3(bx, by + 0.002, bz), fibreVec(e, 0.002)]);
  fibreGroup.add(new THREE.Mesh(new THREE.TubeGeometry(lead, 8, 0.004, 6, false), new THREE.MeshBasicMaterial({color: 0xffffff})));
  anchors.iu = new THREE.Vector3(bx, by + 0.03, bz);
  const [sx, sz] = xz(fib.substation[0], fib.substation[1]); anchors.sub = new THREE.Vector3(sx, groundY(sx, sz) + 0.03, sz);
  buildCameras();
}
// fixed cameras on poles every 20 m along the inner side of the fence (illustrative spacing, as in the re-ID grid)
const camPoles = [];
function buildCameras() {
  [camsNear, camsClose, camsHead].forEach(m => m && scene.remove(m));
  const n = fpts.length; camPoles.length = 0;
  for (let k = 0; k < n; k++) { const {o} = frameAt(k); const x = fpts[k].x - o.x * 2 * M, z = fpts[k].z - o.z * 2 * M; camPoles.push({k, x, z, y: groundY(x, z), o}); }
  camsNear = new THREE.InstancedMesh(new THREE.SphereGeometry(1, 8, 6), new THREE.MeshBasicMaterial({color: 0x34c27a}), n);
  camsClose = new THREE.InstancedMesh(new THREE.CylinderGeometry(0.06 * M, 0.08 * M, 4 * M, 6), new THREE.MeshLambertMaterial({color: 0x9aa3ad}), n);
  camsHead = new THREE.InstancedMesh(new THREE.BoxGeometry(0.22 * M, 0.2 * M, 0.42 * M), new THREE.MeshLambertMaterial({color: 0xf4f6f8}), n);
  const m4 = new THREE.Matrix4(), q = new THREE.Quaternion(), s1 = new THREE.Vector3(), up = new THREE.Vector3(0, 1, 0);
  camPoles.forEach((c, i) => {
    m4.compose(new THREE.Vector3(c.x, c.y + 0.004, c.z), q.identity(), s1.set(0.0035, 0.0035, 0.0035)); camsNear.setMatrixAt(i, m4);
    m4.compose(new THREE.Vector3(c.x, c.y + 2 * M, c.z), q.identity(), s1.set(1, 1, 1)); camsClose.setMatrixAt(i, m4);
    q.setFromAxisAngle(up, Math.atan2(c.o.x, c.o.z));
    m4.compose(new THREE.Vector3(c.x, c.y + 4.1 * M, c.z), q, s1.set(1, 1, 1)); camsHead.setMatrixAt(i, m4);
  });
  camsNear.userData.lod = "near"; camsClose.userData.lod = camsHead.userData.lod = "close";
  scene.add(camsNear, camsClose, camsHead);
}
// short fence (posts + 3 wires) around the event so the scene reads at human scale
function buildFence(k) {
  if (fenceGroup) scene.remove(fenceGroup);
  fenceGroup = new THREE.Group(); scene.add(fenceGroup);
  const n = fpts.length, pts = [];
  for (let d = -8; d <= 8; d++) pts.push(fpts[(k + d + n) % n]);
  const curve = new THREE.CatmullRomCurve3(pts), L = curve.getLength(), np = Math.floor(L / (4 * M));
  const posts = new THREE.InstancedMesh(new THREE.CylinderGeometry(0.035 * M, 0.035 * M, 2.4 * M, 5), new THREE.MeshLambertMaterial({color: 0x6f757c}), np + 1);
  const m4 = new THREE.Matrix4(), wires = [[], [], []];
  for (let i = 0; i <= np; i++) {
    const p = curve.getPointAt(i / np), y = groundY(p.x, p.z);
    m4.makeTranslation(p.x, y + 1.2 * M, p.z); posts.setMatrixAt(i, m4);
    [0.8, 1.6, 2.35].forEach((hh, w) => wires[w].push(new THREE.Vector3(p.x, y + hh * M, p.z)));
  }
  fenceGroup.add(posts);
  const wm = new THREE.LineBasicMaterial({color: 0xc9ced4});
  wires.forEach(w => fenceGroup.add(new THREE.Line(new THREE.BufferGeometry().setFromPoints(w), wm)));
  fenceGroup.userData.lod = "close";
}

// pulses
function glowTex(r, g, b) {
  const c = document.createElement("canvas"); c.width = c.height = 64; const x = c.getContext("2d");
  const gr = x.createRadialGradient(32, 32, 0, 32, 32, 32);
  gr.addColorStop(0, `rgba(${r},${g},${b},1)`); gr.addColorStop(0.35, `rgba(${r},${g},${b},.55)`); gr.addColorStop(1, `rgba(${r},${g},${b},0)`);
  x.fillStyle = gr; x.fillRect(0, 0, 64, 64); return new THREE.CanvasTexture(c);
}
const pulseMat = new THREE.SpriteMaterial({map: glowTex(220, 250, 255), blending: THREE.AdditiveBlending, depthWrite: false, transparent: true});
function buildPulses() {
  pulses.forEach(p => scene.remove(p.s)); pulses = [];
  for (let c = 0; c < 2; c++) for (let i = 0; i < 7; i++) { const s = new THREE.Sprite(pulseMat); scene.add(s); pulses.push({s, c, t: i / 7}); }
}
// Rayleigh backscatter: each forward pulse sheds faint light that travels back to IU-1;
// at the event the returning light is disturbed (phase change) and shown red
const bsMat = new THREE.SpriteMaterial({map: glowTex(255, 196, 120), blending: THREE.AdditiveBlending, depthWrite: false, transparent: true});
const evMat = new THREE.SpriteMaterial({map: glowTex(255, 70, 50), blending: THREE.AdditiveBlending, depthWrite: false, transparent: true});
const scat = [];
function emit(c, f, hot) {
  const s = new THREE.Sprite((hot ? evMat : bsMat).clone()); scene.add(s);
  scat.push({s, c, f, life: 0, max: hot ? 99 : 1.2 + Math.random() * 0.6, hot});
}
const camGlow = new THREE.Sprite(new THREE.SpriteMaterial({map: glowTex(60, 230, 140), blending: THREE.AdditiveBlending, depthWrite: false, transparent: true}));
camGlow.visible = false; scene.add(camGlow);
const anchors = {}, labels = {};
function label(key, text, cls = "") {
  let el = labels[key];
  if (!el) { el = document.createElement("div"); mapEl.appendChild(el); labels[key] = el; }
  el.className = "lbl " + cls; el.textContent = text; return el;
}
function dropLabel(key) { if (labels[key]) { labels[key].remove(); delete labels[key]; delete anchors[key]; } }

// ---------- actors: a person (walking or digging) or a pickup ----------
const skin = new THREE.MeshLambertMaterial({color: 0xb07a55}), cloth = new THREE.MeshLambertMaterial({color: 0x22262d}), cloth2 = new THREE.MeshLambertMaterial({color: 0x3c4450});
function limb(len, r, mat) { const g = new THREE.Group(), m = new THREE.Mesh(new THREE.CylinderGeometry(r, r * 0.85, len, 8), mat); m.position.y = -len / 2; g.add(m); return g; }
function makePerson(withShovel) {
  const g = new THREE.Group(), s = M;
  const torso = new THREE.Mesh(new THREE.BoxGeometry(0.42 * s, 0.6 * s, 0.24 * s), cloth); torso.position.y = 1.22 * s; g.add(torso);
  const head = new THREE.Mesh(new THREE.SphereGeometry(0.12 * s, 12, 10), skin); head.position.y = 1.66 * s; g.add(head);
  const hood = new THREE.Mesh(new THREE.SphereGeometry(0.13 * s, 12, 10, 0, Math.PI * 2, 0, 1.4), cloth); hood.position.y = 1.68 * s; g.add(hood);
  const legL = limb(0.9 * s, 0.075 * s, cloth2), legR = limb(0.9 * s, 0.075 * s, cloth2);
  legL.position.set(-0.11 * s, 0.92 * s, 0); legR.position.set(0.11 * s, 0.92 * s, 0); g.add(legL, legR);
  const armL = limb(0.66 * s, 0.055 * s, cloth), armR = limb(0.66 * s, 0.055 * s, cloth);
  armL.position.set(-0.27 * s, 1.48 * s, 0); armR.position.set(0.27 * s, 1.48 * s, 0); g.add(armL, armR);
  g.userData = {legL, legR, armL, armR, torso};
  if (withShovel) {
    const sh = new THREE.Group();
    const handle = new THREE.Mesh(new THREE.CylinderGeometry(0.018 * s, 0.018 * s, 1.2 * s, 6), new THREE.MeshLambertMaterial({color: 0x8a6a3c})); handle.position.y = -0.6 * s; sh.add(handle);
    const blade = new THREE.Mesh(new THREE.BoxGeometry(0.22 * s, 0.28 * s, 0.02 * s), new THREE.MeshLambertMaterial({color: 0x7c8187})); blade.position.y = -1.3 * s; sh.add(blade);
    sh.position.set(0, 1.1 * s, 0.35 * s); g.add(sh); g.userData.shovel = sh;
    const mound = new THREE.Mesh(new THREE.SphereGeometry(0.35 * s, 12, 8, 0, Math.PI * 2, 0, Math.PI / 2), new THREE.MeshLambertMaterial({color: 0xb98f63}));
    mound.position.set(0.45 * s, 0, 0.9 * s); mound.scale.y = 0.2; g.add(mound); g.userData.mound = mound;
  }
  return g;
}
function makeCar() {
  const g = new THREE.Group(), s = M, body = new THREE.MeshLambertMaterial({color: 0xe8e8e4}), dark = new THREE.MeshLambertMaterial({color: 0x1d2228});
  const b = new THREE.Mesh(new THREE.BoxGeometry(1.9 * s, 0.7 * s, 5.0 * s), body); b.position.y = 0.75 * s; g.add(b);
  const cab = new THREE.Mesh(new THREE.BoxGeometry(1.75 * s, 0.65 * s, 2.2 * s), body); cab.position.set(0, 1.42 * s, 0.6 * s); g.add(cab);
  const win = new THREE.Mesh(new THREE.BoxGeometry(1.77 * s, 0.4 * s, 1.9 * s), dark); win.position.set(0, 1.47 * s, 0.6 * s); g.add(win);
  const wheels = [];
  for (const [x, z] of [[-0.9, 1.6], [0.9, 1.6], [-0.9, -1.6], [0.9, -1.6]]) {
    const w = new THREE.Mesh(new THREE.CylinderGeometry(0.38 * s, 0.38 * s, 0.25 * s, 12), dark); w.rotation.z = Math.PI / 2; w.position.set(x * s, 0.38 * s, z * s); g.add(w); wheels.push(w);
  }
  g.userData.wheels = wheels; return g;
}
const dust = [];
function puff(p) {
  const m = new THREE.Mesh(new THREE.SphereGeometry(0.25 * M, 6, 5), new THREE.MeshLambertMaterial({color: 0xcaa57c, transparent: true, opacity: 0.6}));
  m.position.copy(p); scene.add(m); dust.push({m, t: 0});
}

const ringMat = new THREE.MeshBasicMaterial({color: 0xff3b30, transparent: true, opacity: 0.7, side: THREE.DoubleSide, depthWrite: false});
function placeEventMarkers(k) {
  if (eventGroup) scene.remove(eventGroup);
  eventGroup = new THREE.Group(); scene.add(eventGroup);
  const n = fpts.length, p = fpts[k].clone();
  for (const [name, core, glow, lift] of LODS) {
    const seg = []; for (let d = -8; d <= 8; d++) seg.push(fibreVec((k + d + n) % n, lift * 1.6));
    const c = new THREE.CatmullRomCurve3(seg);
    const a = new THREE.Mesh(new THREE.TubeGeometry(c, 60, core * 1.5, 6, false), new THREE.MeshBasicMaterial({color: 0xff2a1f}));
    const b = new THREE.Mesh(new THREE.TubeGeometry(c, 60, glow * (name === "close" ? 1.3 : 1.7), 8, false),
      new THREE.MeshBasicMaterial({color: 0xff2a1f, transparent: true, opacity: 0.4, depthWrite: false, blending: THREE.AdditiveBlending}));
    a.userData.lod = b.userData.lod = name; a.visible = b.visible = false; eventGroup.add(a, b);
  }
  for (const [name, r] of [["far", 0.05], ["near", 0.05], ["close", 0.004]]) for (let i = 0; i < 2; i++) {
    const ring = new THREE.Mesh(new THREE.RingGeometry(r, r * 1.16, 64), ringMat.clone());
    ring.rotation.x = -Math.PI / 2; ring.position.set(p.x, p.y + 0.0004, p.z); ring.userData = {phase: i * 0.5, ring: true, lod: name}; ring.visible = false; eventGroup.add(ring);
  }
  eventGroup.userData.on = false;
  return p;
}
function showEventGlow(on) { eventGroup.userData.on = on; }

// ---------- views ----------
function fly(pos, tgt, ms = 1100) {
  const p0 = camera.position.clone(), t0 = controls.target.clone(), t = performance.now();
  if (reduce) { camera.position.copy(pos); controls.target.copy(tgt); return; }
  (function step() {
    const u = Math.min(1, (performance.now() - t) / ms), e = u < .5 ? 2*u*u : 1 - (-2*u + 2)**2 / 2;
    camera.position.lerpVectors(p0, pos, e); controls.target.lerpVectors(t0, tgt, e);
    if (u < 1) requestAnimationFrame(step);
  })();
}
const centre = () => new THREE.Vector3(0.3, groundY(0.3, 0.2), 0.2);
const overview = () => { const c = centre(); fly(new THREE.Vector3(c.x, c.y + 5.2, c.z + 9.0), c); };
$("vOver").onclick = overview;
$("vTop").onclick = () => { const c = centre(); fly(new THREE.Vector3(c.x, c.y + 13, c.z + 0.01), c); };
$("vEvent").onclick = () => { if (lastEvent) closeView(lastEvent.k); };
function closeView(k) {
  const p = fpts[k], {t, o} = frameAt(k);
  const tgt = new THREE.Vector3(p.x + o.x * 4 * M, p.y + 1 * M, p.z + o.z * 4 * M);
  fly(new THREE.Vector3(tgt.x + o.x * 34 * M - t.x * 26 * M, tgt.y + 16 * M, tgt.z + o.z * 34 * M - t.z * 26 * M), tgt);
}

document.querySelectorAll(".chip").forEach(b => b.onclick = () => {
  evType = b.dataset.ev; document.querySelectorAll(".chip").forEach(o => o.setAttribute("aria-pressed", o === b));
});
$("ve").oninput = e => {
  VE = +e.target.value; $("veVal").textContent = VE; updateTerrainHeights(); buildFibre();
  if (lastEvent) start(lastEvent.k, lastEvent.type, lastEvent.seed);
};

// ---------- tap ----------
let down = null; const ray = new THREE.Raycaster(), ndc = new THREE.Vector2();
renderer.domElement.addEventListener("pointerdown", e => { down = {x: e.clientX, y: e.clientY, t: performance.now()}; });
renderer.domElement.addEventListener("pointerup", e => {
  if (!down || !terrain) return;
  const moved = Math.hypot(e.clientX - down.x, e.clientY - down.y), dt = performance.now() - down.t; down = null;
  if (moved > 7 || dt > 600) return;
  const r = renderer.domElement.getBoundingClientRect();
  ndc.set((e.clientX - r.left) / r.width * 2 - 1, -(e.clientY - r.top) / r.height * 2 + 1);
  ray.setFromCamera(ndc, camera);
  const hit = ray.intersectObject(terrain)[0]; if (!hit) return;
  let best = -1, bd = 1e9;
  for (let k = 0; k < fpts.length; k++) { const d = (fpts[k].x - hit.point.x)**2 + (fpts[k].z - hit.point.z)**2; if (d < bd) { bd = d; best = k; } }
  const tol = Math.max(0.03, camera.position.distanceTo(controls.target) * 0.06);
  if (Math.sqrt(bd) > tol) { hint("Tap on or near the fence line (the glowing fibre)"); return; }
  start(best, evType);
});
let hintTimer;
function hint(t) { const h = $("hint"); h.textContent = t; h.style.opacity = 1; clearTimeout(hintTimer); hintTimer = setTimeout(() => h.style.opacity = 0, 2600); }

function rng(seed) { let s = seed >>> 0 || 1; return () => (s = (s * 1664525 + 1013904223) >>> 0) / 4294967296; }

function drawWaterfall(type, dkm, seed) {
  const c = $("wf"), W = c.clientWidth, H = c.clientHeight, dpr = Math.min(devicePixelRatio, 2);
  c.width = W * dpr; c.height = H * dpr; const g = c.getContext("2d");
  const r = rng(seed), w = W * dpr, h = H * dpr, img = g.createImageData(w, h), win = 0.5, T = 10;
  const amp = (x, t) => {
    const d = (x - 0.5) * win * 1000;
    if (type === "walking") { const ph = (t / 0.55) % 1; return Math.exp(-(d*d) / 162) * Math.exp(-ph / 0.08) * (t > 1.2 ? 1 : 0); }
    if (type === "digging") { const ph = (t / 1.6) % 1; return Math.exp(-(d*d) / 338) * (Math.exp(-ph / 0.12) * 1.3 + 0.15) * (t > 0.8 ? 1 : 0); }
    const c0 = -110 + 22 * t; return Math.exp(-((d - c0)**2) / 1568) * 0.75;
  };
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) {
    const v = Math.min(1, 0.12 * r() + amp(i / w, j / h * T) * (0.75 + 0.25 * r())), k = (j * w + i) * 4, cv = Math.pow(v, 0.8);
    img.data[k] = 255 * Math.max(0, Math.min(1, cv * 2.2 - 0.6)); img.data[k+1] = 255 * Math.min(1, cv * 1.6); img.data[k+2] = 255 * Math.min(1, 0.25 + cv * 1.3); img.data[k+3] = 255;
  }
  g.putImageData(img, 0, 0); g.setTransform(dpr, 0, 0, dpr, 0, 0);
  g.fillStyle = "rgba(255,255,255,.85)"; g.font = "11px IBM Plex Sans, sans-serif";
  g.fillText(`${(dkm - win/2).toFixed(2)} km`, 6, H - 6); const t2 = `${(dkm + win/2).toFixed(2)} km`; g.fillText(t2, W - g.measureText(t2).width - 6, H - 6);
  g.fillText("time ↓ 10 s", 6, 14); g.strokeStyle = "rgba(255,80,60,.9)"; g.setLineDash([3, 3]); g.beginPath(); g.moveTo(W/2, 20); g.lineTo(W/2, H - 18); g.stroke();
}

// ---------- the event: actor animation drives the console ----------
const timers = [];
function resetConsole() {
  timers.forEach(clearTimeout); timers.length = 0;
  document.querySelectorAll("#steps li").forEach(li => li.classList.remove("on"));
  $("outcome").className = "outcome"; $("outcome").textContent = "";
  $("pip").classList.remove("on"); dropLabel("ev"); camGlow.visible = false;
}
function start(k, type, seedIn) {
  resetConsole();
  if (actor) scene.remove(actor);
  const id = ++seq, seed = seedIn ?? (k * 7919 + id * 104729), r = rng(seed);
  const keys = Object.keys(EV); let pred = type;
  if (r() > PC) { const others = keys.filter(x => x !== type); pred = others[Math.floor(r() * others.length)]; }
  const p = placeEventMarkers(k); buildFence(k);
  const ci = fib.ch[k] - 1, chIdx = [ci, chPts[ci].indexOf(fpts[k])];
  lastEvent = {k, type, seed, p}; $("vEvent").disabled = false;
  const {t, o} = frameAt(k);
  // nearest fixed camera: 1 pole along the fence from the event, inner side
  const cp = camPoles[(k + 1) % camPoles.length], camHead = new THREE.Vector3(cp.x, cp.y + 4.1 * M, cp.z);
  if (type === "vehicle") {
    actor = makeCar();
    act = {type, k, pred, from: -70, to: 70, dur: 12, off: 22, t, o, p, camHead, t0: performance.now(), stage: 0};
    act.chIdx = chIdx;
  } else {
    actor = makePerson(type === "digging");
    act = type === "walking" ? {type, k, pred, from: 16, to: -9, dur: 15, t, o, p, camHead, t0: performance.now(), stage: 0}
                             : {type, k, pred, from: 7, to: 1.4, dur: 4.5, t, o, p, camHead, t0: performance.now(), stage: 0};
  }
  act.chIdx = chIdx; scene.add(actor);
  bn("run", type === "vehicle" ? "A vehicle drives on the fence road…" : type === "digging" ? "Someone approaches the fence with a shovel…" : "Someone walks toward the fence…");
  closeView(k);
  if (reduce) { act.t0 -= 60000; }
}
function bn(cls, txt) { const b = $("banner"); b.className = "banner " + cls; b.textContent = txt; }

function detected() {
  const {k, type, pred} = act, zone = fib.zone[k], ch = fib.ch[k], dkm = fib.dkm[k], threat = EV[pred].threat;
  showEventGlow(true);
  const gap = reduce ? 0 : 900;
  const step = (i, fn) => timers.push(setTimeout(() => { fn(); document.querySelector(`#steps li[data-s="${i}"]`).classList.add("on"); }, gap * (i - 1)));
  step(1, () => { $("s1").innerHTML = `<span class="big">${dkm.toFixed(2)} km</span> from IU-1 along the fibre`; label("ev", `DAS: ${dkm.toFixed(2)} km`, "ev"); anchors.ev = new THREE.Vector3(act.p.x, act.p.y + 4.5 * M, act.p.z); bn("run", `Fibre: vibration at ${dkm.toFixed(2)} km`); });
  step(2, () => { $("s2").innerHTML = `Channel ${ch} · <span class="tag" style="background:${ZCSS[zone]}">${ZN[zone]} zone</span><br>Localised within 4–6 m (simulated)`; bn("run", `Located: channel ${ch}, ${ZN[zone]} zone`); });
  step(3, () => drawWaterfall(type, dkm, act.k + seq));
  step(4, () => { $("s4").innerHTML = `AI: <b>${EV[pred].ai}</b>${pred !== type ? ' <span class="tag" style="background:#6b7383">misclassified</span>' : ""}<br>Interface stub, Pc = 0.983 from literature · route: ${threat ? "threat → alarm" : "vehicle on fence road → log"}`; bn("run", `AI: ${EV[pred].ai}`); });
  step(5, () => {
    if (threat) { act.track = true; $("pip").classList.add("on"); camGlow.position.copy(act.camHead); camGlow.visible = true; }
    $("s5").innerHTML = threat ? "Nearest fixed camera turns to the event and follows it; DAS track linked to the camera track.<br>99.9 % correct links, 93 % linked (simulated, 20 m spacing)." : "No alarm, so no hand-off; the event is stored with its camera clip reference.";
  });
  timers.push(setTimeout(() => {
    const o = $("outcome"); o.className = "outcome " + (threat ? "alarm" : "logged");
    o.textContent = threat ? `ALARM · ${ZN[zone]} zone · ${dkm.toFixed(2)} km` : `LOGGED · ${dkm.toFixed(2)} km`;
    bn(threat ? "alarm" : "logged", o.textContent); addLog(type, pred, dkm, zone, threat);
  }, gap * 5));
}
function addLog(type, pred, dkm, zone, threat) {
  const L = $("log"); if (L.dataset.empty !== "0") { L.innerHTML = ""; L.dataset.empty = "0"; }
  const li = document.createElement("li");
  li.innerHTML = `<span>${EV[type].label} → AI ${pred} · ${dkm.toFixed(2)} km · ${ZN[zone]}</span><span style="color:${threat ? "var(--hot)" : "var(--mute)"}">${threat ? "ALARM" : "LOGGED"}</span>`;
  L.prepend(li); while (L.children.length > 8) L.lastChild.remove();
}
$("preset").onclick = () => {
  evType = "walking"; document.querySelectorAll(".chip").forEach(o => o.setAttribute("aria-pressed", o.dataset.ev === "walking"));
  let best = 0, bd = 1e9; for (let k = 0; k < fib.lat.length; k++) { const d = (fib.lat[k] - 25.780142)**2 + (fib.lon[k] - 45.615659)**2; if (d < bd) { bd = d; best = k; } }
  start(best, "walking", 42);
};

const tmpV = new THREE.Vector3(), up = new THREE.Vector3(0, 1, 0);
function animateActor(now) {
  if (!act || !actor) return;
  const T = (now - act.t0) / 1000, {o, t, p} = act, u = actor.userData;
  if (act.type === "walking") {
    // approach (stop 1.5 s at the fence), then cross into the plant
    const dApp = act.from, walk = 1.4, tFence = dApp / walk, pause = 1.5;
    let d; if (T < tFence) d = dApp - walk * T; else if (T < tFence + pause) d = 0; else d = Math.max(act.to, -(T - tFence - pause) * walk);
    const moving = !(T >= tFence && T < tFence + pause) && d > act.to;
    const x = p.x + o.x * d * M + t.x * 0.6 * M, z = p.z + o.z * d * M + t.z * 0.6 * M;
    actor.position.set(x, groundY(x, z), z); actor.rotation.y = Math.atan2(-o.x, -o.z);
    const sw = moving ? Math.sin(T * 2 * Math.PI * 0.95) * 0.55 : 0;
    u.legL.rotation.x = sw; u.legR.rotation.x = -sw; u.armL.rotation.x = -sw * 0.8; u.armR.rotation.x = sw * 0.8;
    if (!moving && T >= tFence) { u.armL.rotation.x = u.armR.rotation.x = -1.2 + Math.sin(T * 9) * 0.15; }
    if (act.stage === 0 && d < 4) { act.stage = 1; detected(); }
  } else if (act.type === "digging") {
    const walkT = (act.from - act.to) / 1.2, d = T < walkT ? act.from - 1.2 * T : act.to;
    const x = p.x + o.x * d * M, z = p.z + o.z * d * M;
    actor.position.set(x, groundY(x, z), z); actor.rotation.y = Math.atan2(-o.x, -o.z);
    if (T < walkT) { const sw = Math.sin(T * 6) * 0.5; u.legL.rotation.x = sw; u.legR.rotation.x = -sw; u.armL.rotation.x = u.armR.rotation.x = -0.6; }
    else {
      const ph = ((T - walkT) / 1.6) % 1, dig = ph < 0.4 ? ph / 0.4 : 1 - (ph - 0.4) / 0.6;
      u.torso.rotation.x = 0.35 * dig; u.armL.rotation.x = u.armR.rotation.x = -0.9 - 0.7 * dig; u.legL.rotation.x = 0.2 * dig; u.legR.rotation.x = -0.1;
      u.shovel.rotation.x = -0.5 + 0.9 * dig; u.mound.scale.y = Math.min(1, 0.2 + (T - walkT) * 0.06);
      if (ph < 0.05 && !act.lastPuff) { tmpV.set(0.3 * M, 0.2 * M, 0.9 * M).applyAxisAngle(up, actor.rotation.y).add(actor.position); puff(tmpV); act.lastPuff = true; }
      if (ph > 0.5) act.lastPuff = false;
      if (act.stage === 0 && T > walkT + 1.2) { act.stage = 1; detected(); }
    }
  } else {
    const s = Math.min(act.to, act.from + (act.to - act.from) * (T / act.dur));
    const x = p.x + o.x * act.off * M + t.x * s * M, z = p.z + o.z * act.off * M + t.z * s * M;
    actor.position.set(x, groundY(x, z), z); actor.rotation.y = Math.atan2(t.x, t.z);
    u.wheels.forEach(w => w.rotation.x += 0.25);
    if (Math.random() < 0.3 && s < act.to) { tmpV.set(0, 0.3 * M, -2.6 * M).applyAxisAngle(up, actor.rotation.y).add(actor.position); puff(tmpV); }
    if (act.stage === 0 && s > -8) { act.stage = 1; detected(); }
  }
}

// frame loop
const v = new THREE.Vector3(), needle = $("needle"), pipEl = $("pip"), pipBox = $("pipbox");
function place(key, anchor) {
  const el = labels[key]; if (!el || !anchor) return;
  v.copy(anchor).project(camera);
  const vis = v.z < 1 && Math.abs(v.x) < 1.1 && Math.abs(v.y) < 1.1;
  el.style.display = vis ? "block" : "none";
  el.style.left = ((v.x + 1) / 2 * mapEl.clientWidth) + "px"; el.style.top = ((1 - v.y) / 2 * mapEl.clientHeight) + "px";
}
function setLod(obj, name) { obj.visible = obj.userData.lod === name; }
let lastT = 0;
function loop(now) {
  const dt = Math.min(0.05, (now - lastT) / 1000); lastT = now;
  controls.update();
  const dist = camera.position.distanceTo(controls.target);
  lod = dist < 0.25 ? "close" : dist < 3.2 ? "near" : "far";
  if (fibreGroup) fibreGroup.children.forEach(o => { if (o.userData.lod) setLod(o, lod); });
  [camsNear, camsClose, camsHead].forEach(m => m && (m.visible = m.userData.lod === lod || (m === camsNear && lod === "near")));
  if (fenceGroup) fenceGroup.visible = lod === "close";
  if (eventGroup) eventGroup.children.forEach(o => { o.visible = eventGroup.userData.on && o.userData.lod === lod;
    if (o.userData.ring) { const u = ((now / 1400) + o.userData.phase) % 1; o.scale.setScalar(0.6 + u * 2.4); o.material.opacity = 0.9 * (1 - u); } });
  const ps = lod === "far" ? 0.16 : lod === "near" ? 0.06 : 0.004;
  if (chPts[0].length) for (const p of pulses) {
    const arr = chPts[p.c], fPrev = p.t * (arr.length - 1); if (!reduce) p.t = (p.t + 0.0009) % 1;
    const f = p.t * (arr.length - 1), i = Math.floor(f); p.s.position.lerpVectors(arr[i], arr[Math.min(arr.length - 1, i + 1)], f - i); p.s.position.y += ps * 0.3; p.s.scale.set(ps, ps, 1);
    if (!reduce && scat.length < 900) { emit(p.c, f, false); if (Math.random() < 0.5) emit(p.c, f - 0.3, false); }
    if (act && eventGroup && eventGroup.userData.on && act.chIdx && act.chIdx[0] === p.c && fPrev <= act.chIdx[1] && f > act.chIdx[1]) { emit(p.c, act.chIdx[1], true); emit(p.c, act.chIdx[1] + 0.6, true); }
  }
  const back = 0.0009 * (chPts[0].length - 1);
  for (let j = scat.length - 1; j >= 0; j--) {
    const q = scat[j], arr = chPts[q.c]; q.life += dt; q.f -= reduce ? 0 : back;
    if (q.f <= 0 || q.life > q.max) { scene.remove(q.s); scat.splice(j, 1); continue; }
    const i = Math.floor(q.f); q.s.position.lerpVectors(arr[i], arr[Math.min(arr.length - 1, i + 1)], q.f - i);
    const sz = ps * (q.hot ? 1.1 : 0.6); q.s.position.y += ps * 0.3; q.s.scale.set(sz, sz, 1);
    q.s.material.opacity = q.hot ? 1 : 0.85 * (1 - q.life / q.max);
  }
  animateActor(now);
  if (camGlow.visible) { const g = (lod === "close" ? 0.003 : 0.05) * (1 + 0.25 * Math.sin(now / 150)); camGlow.scale.set(g, g, 1); }
  for (let i = dust.length - 1; i >= 0; i--) { const d = dust[i]; d.t += dt; d.m.position.y += dt * 0.6 * M; d.m.scale.setScalar(1 + d.t * 2); d.m.material.opacity = 0.6 * (1 - d.t / 1.4); if (d.t > 1.4) { scene.remove(d.m); dust.splice(i, 1); } }
  if (actor) { actor.visible = lod !== "far"; }
  for (const k of Object.keys(labels)) place(k, anchors[k]);
  const dir = new THREE.Vector3(); camera.getWorldDirection(dir);
  needle.style.transform = `rotate(${Math.atan2(dir.x, -dir.z) * -180 / Math.PI}deg)`;
  const W = mapEl.clientWidth, H = mapEl.clientHeight;
  renderer.setViewport(0, 0, W, H); renderer.setScissorTest(false); renderer.render(scene, camera);
  // picture-in-picture: the turned camera's live view, following the target
  if (act && act.track && pipEl.classList.contains("on")) {
    const r = pipEl.getBoundingClientRect(), m = mapEl.getBoundingClientRect();
    const px = r.left - m.left, py = H - (r.top - m.top) - r.height;
    const aim = actor.position.clone().add(new THREE.Vector3(0, 1.0 * M, 0));
    pipCam.position.copy(act.camHead); pipCam.aspect = r.width / r.height; pipCam.fov = 24; pipCam.updateProjectionMatrix(); pipCam.lookAt(aim);
    const vis = actor.visible; actor.visible = true;
    renderer.setScissorTest(true); renderer.setScissor(px, py, r.width, r.height); renderer.setViewport(px, py, r.width, r.height);
    renderer.render(scene, pipCam); renderer.setScissorTest(false); actor.visible = vis;
    // tracking box around the person in the camera view
    const top = actor.position.clone().add(new THREE.Vector3(0, 1.85 * M, 0)).project(pipCam), bot = actor.position.clone().project(pipCam);
    const bh = (top.y - bot.y) / 2 * r.height, bw = bh * 0.55, cx = (bot.x + 1) / 2 * r.width, cy = (1 - top.y) / 2 * r.height;
    pipBox.style.cssText = `left:${cx - bw / 2}px;top:${cy}px;width:${bw}px;height:${bh}px`;
  }
  requestAnimationFrame(loop);
}

(async () => {
  try {
    const [d, f, base, plant] = await Promise.all([fetch("dem.json").then(r => r.json()), fetch("fibre.json").then(r => r.json()), img("base.jpg"), img("plant.jpg")]);
    dem = d; fib = f; let zmin = 1e9; for (const z of dem.z) zmin = Math.min(zmin, z); dem.zmin = zmin / 10;
    buildTerrain(base, plant); buildFibre(); buildPulses();
    label("iu", "IU-1 · FEBUS A1-NEO · control room"); label("sub", "380 kV substation · Hot", "hot below");
    $("legend").innerHTML = [3, 2, 1].map(z => `<div><i style="background:${ZCSS[z]}"></i>${ZN[z]} fence<em>${fib.zone_km[ZN[z]]} km</em></div>`).join("") +
      `<div><i style="background:#fff;box-shadow:0 0 6px #bdf"></i>Laser pulses out from IU-1, 2 channels<em>${fib.L_km} km</em></div>` +
      `<div><i style="background:#ffc478;box-shadow:0 0 6px #ffc478"></i>Rayleigh backscatter returning to IU-1<em></em></div>` +
      `<div><i style="background:#ff4632;box-shadow:0 0 6px #ff4632"></i>Backscatter disturbed by the event<em></em></div>` +
      `<div><i style="background:#34c27a"></i>Fixed cameras on poles, every 20 m (illustrative)<em></em></div>`;
    resize(); const c = centre(); camera.position.set(c.x, c.y + 5.2, c.z + 9.0); controls.target.copy(c);
    $("loading").remove(); setTimeout(() => $("hint").style.opacity = 0, 6000);
    requestAnimationFrame(loop);
  } catch (err) { $("loading").textContent = "Could not load the Sudair data: " + err.message; }
})();
}
