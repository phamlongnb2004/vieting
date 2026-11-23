#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

// VieTing: hiệu ứng thời tiết như thật (mây thể tích, mưa nhiều lớp, nắng, sao, chớp, sương, tuyết)
uniform vec2 uSize;
uniform float uTime;
uniform float uMode; // 1 nắng, 2 đêm quang, 3 có mây (ngày), 4 có mây (đêm), 5 nhiều mây, 6 sương mù, 7 mưa nhỏ, 8 mưa, 9 mưa to, 10 dông, 11 tuyết
uniform float uDark;

out vec4 fragColor;

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  mat2 m = mat2(1.6, 1.2, -1.2, 1.6);
  for (int i = 0; i < 5; i++) {
    v += a * noise(p);
    p = m * p;
    a *= 0.5;
  }
  return v;
}

// Một lớp mưa: các vệt mảnh, đầu vệt sáng hơn đuôi, xiên nhẹ theo gió
float rainLayer(vec2 pc, float cw, float len, float period, float speed, float lw, float seed, float t) {
  float x = pc.x + pc.y * 0.14;
  float col = floor(x / cw);
  float r = hash(vec2(col, seed));
  float r2 = hash(vec2(col + 7.0, seed * 1.7));
  float cx = (col + 0.2 + 0.6 * r2) * cw;
  float dx = abs(x - cx);
  float line = 1.0 - smoothstep(lw * 0.5, lw * 0.5 + 1.0, dx);
  float per = period * (0.7 + 0.6 * r);
  float yy = pc.y - t * speed * (0.85 + 0.3 * r) + r * per * 3.0;
  float k = mod(yy, per);
  float cell = floor(yy / per);
  float on = step(0.32, hash(vec2(col, cell + seed)));
  float s = (1.0 - step(len, k)) * smoothstep(0.0, len, k);
  return line * s * on;
}

// Một lớp tuyết: bông mềm, rơi chậm và lắc lư
float snowLayer(vec2 pc, float cell, float speed, float size, float seed, float t) {
  vec2 p = pc;
  p.y -= t * speed;
  p.x += sin(t * 0.7 + pc.y * 0.01 + seed) * 12.0;
  vec2 id = floor(p / cell);
  vec2 f = fract(p / cell) - 0.5;
  float r = hash(id + seed);
  if (r < 0.45) return 0.0;
  vec2 o = vec2(hash(id + 3.1 + seed), hash(id + 5.7 + seed)) - 0.5;
  float d = length((f - o * 0.6) * cell);
  return 1.0 - smoothstep(size * 0.4, size, d);
}

vec4 over(vec4 dst, vec3 c, float a) {
  return vec4(mix(dst.rgb, c, a), dst.a + a * (1.0 - dst.a));
}

void main() {
  vec2 pc = FlutterFragCoord().xy;
  float W = uSize.x;
  float H = uSize.y;
  float t = uTime;
  int m = int(uMode + 0.5);
  float dark = uDark;
  float yN = pc.y / H;

  bool night = (m == 2 || m == 4);
  bool rainy = (m >= 7 && m <= 10);
  bool sunny = (m == 1 || m == 3);

  // ---- Bầu trời ----
  vec3 skyTop;
  vec3 skyLow;
  if (m == 1) { skyTop = vec3(0.16, 0.50, 0.90); skyLow = vec3(0.55, 0.78, 0.98); }
  else if (m == 3) { skyTop = vec3(0.26, 0.54, 0.86); skyLow = vec3(0.62, 0.78, 0.94); }
  else if (night) { skyTop = vec3(0.03, 0.06, 0.18); skyLow = vec3(0.10, 0.16, 0.34); }
  else if (m == 5 || m == 6) { skyTop = vec3(0.45, 0.50, 0.58); skyLow = vec3(0.70, 0.73, 0.78); }
  else if (m == 9 || m == 10) { skyTop = vec3(0.16, 0.19, 0.25); skyLow = vec3(0.34, 0.38, 0.45); }
  else { skyTop = vec3(0.30, 0.36, 0.45); skyLow = vec3(0.55, 0.60, 0.67); }
  float skyA = (dark > 0.5 ? 0.78 : 0.62) * (1.0 - smoothstep(0.08, 0.62, yN));
  vec4 acc = vec4(mix(skyTop, skyLow, smoothstep(0.0, 0.5, yN)), skyA);

  // ---- Sao và trăng ----
  if (night) {
    vec2 cellP = pc / 38.0;
    vec2 id = floor(cellP);
    vec2 f = fract(cellP);
    float r = hash(id);
    if (r > 0.72 && yN < 0.55) {
      vec2 sp = vec2(hash(id + 1.3), hash(id + 2.9));
      float d = length((f - sp) * 38.0);
      float tw = 0.55 + 0.45 * sin(t * (1.2 + r * 3.0) + r * 40.0);
      float star = (1.0 - smoothstep(0.4, 1.6 + r, d)) * tw * (1.0 - smoothstep(0.2, 0.55, yN));
      acc = over(acc, vec3(1.0, 0.98, 0.92), star);
    }
    vec2 mc = vec2(W - 62.0, 64.0);
    float md = length(pc - mc);
    float glow = exp(-md / 70.0) * 0.55 + exp(-md / 200.0) * 0.18;
    acc = over(acc, vec3(0.80, 0.86, 1.0), glow);
    float disc = 1.0 - smoothstep(19.0, 21.0, md);
    float crater = fbm((pc - mc) * 0.12 + 3.0);
    vec3 moonCol = mix(vec3(0.98, 0.97, 0.90), vec3(0.78, 0.78, 0.76), smoothstep(0.45, 0.75, crater));
    acc = over(acc, moonCol, disc);
  }

  // ---- Mặt trời: lõi, quầng, tia nắng, lóa ống kính ----
  if (sunny) {
    float k = (m == 1) ? 1.0 : 0.8;
    vec2 sc = vec2(W - 58.0, 52.0);
    vec2 dv = pc - sc;
    float d = length(dv);
    float ang = atan(dv.y, dv.x);
    float rays = pow(noise(vec2(ang * 7.0, t * 0.12)), 3.0) * exp(-d / 330.0) * 0.55;
    float halo = exp(-d / 80.0) * 0.85 + exp(-d / 300.0) * 0.35;
    float core = 1.0 - smoothstep(20.0, 28.0, d);
    vec3 warm = vec3(1.0, 0.92, 0.70);
    acc = over(acc, warm, clamp((halo + rays) * k, 0.0, 1.0));
    acc = over(acc, vec3(1.0, 0.99, 0.94), core * k);
    vec2 center = vec2(W * 0.5, H * 0.45);
    for (int i = 1; i <= 3; i++) {
      float fi = float(i);
      vec2 g = sc + (center - sc) * (0.35 * fi);
      float gd = length(pc - g);
      float gr = 10.0 + 9.0 * fi;
      float ghost = (1.0 - smoothstep(gr * 0.6, gr, gd)) * 0.07 * k;
      acc = over(acc, mix(vec3(1.0, 0.85, 0.6), vec3(0.6, 0.85, 1.0), fi / 3.0), ghost);
    }
  }

  // ---- Chớp (dông) ----
  float flash = 0.0;
  float boltX = 0.0;
  float n = 0.0;
  if (m == 10) {
    float cyc = 6.5;
    n = floor(t / cyc);
    float start = hash(vec2(n, 2.0)) * 3.0;
    float ph = t - n * cyc - start;
    if (ph > 0.0 && ph < 0.12) flash = 1.0 - ph / 0.12;
    else if (ph > 0.2 && ph < 0.55) flash = (1.0 - (ph - 0.2) / 0.35) * 0.8;
    boltX = W * (0.18 + 0.64 * hash(vec2(n, 9.0)));
  }

  // ---- Mây thể tích: nhiễu fbm bẻ cong + ánh sáng theo hướng mặt trời ----
  float cover = 0.0;
  float heavy = 0.0;
  if (m == 1) cover = 0.18;
  else if (m == 3) cover = 0.42;
  else if (m == 4) cover = 0.40;
  else if (m == 5) { cover = 0.75; heavy = 0.25; }
  else if (m == 6) { cover = 0.55; heavy = 0.15; }
  else if (m == 7) { cover = 0.72; heavy = 0.35; }
  else if (m == 8) { cover = 0.82; heavy = 0.55; }
  else if (m == 9) { cover = 0.92; heavy = 0.75; }
  else if (m == 10) { cover = 0.95; heavy = 0.85; }
  else if (m == 11) { cover = 0.80; heavy = 0.30; }
  if (cover > 0.0 && yN < 0.7) {
    vec2 p = pc / vec2(420.0, 260.0) + vec2(t * 0.010, 0.0);
    vec2 q = vec2(fbm(p + vec2(0.0, t * 0.006)), fbm(p + vec2(5.2, 1.3)));
    float d = fbm(p + 1.7 * q);
    float d2 = fbm(p + 1.7 * q + vec2(-0.05, 0.05));
    float thr = 1.0 - cover;
    float c = smoothstep(thr * 0.75, thr * 0.75 + 0.32, d);
    c *= 1.0 - smoothstep(0.18, 0.68, yN);
    float shade = clamp(0.55 + (d - d2) * 4.0, 0.0, 1.0);
    vec3 lit = night ? vec3(0.42, 0.46, 0.58) : vec3(1.0, 0.99, 0.97);
    vec3 shadow = night ? vec3(0.12, 0.14, 0.22) : vec3(0.52, 0.56, 0.63);
    vec3 cc = mix(shadow, lit, shade);
    cc = mix(cc, cc * vec3(0.42, 0.45, 0.50), heavy);
    if (flash > 0.0) {
      float lg = exp(-length(pc - vec2(boltX, 90.0)) / 260.0);
      cc += vec3(0.85, 0.88, 1.0) * flash * lg;
    }
    acc = over(acc, cc, c * (0.92 - 0.25 * (1.0 - cover)));
  }

  // ---- Sương mù ----
  if (m == 6) {
    float f1 = fbm(pc * vec2(0.0025, 0.006) + vec2(t * 0.025, 0.0));
    float f2 = fbm(pc * vec2(0.004, 0.01) - vec2(t * 0.018, 3.0));
    float fog = smoothstep(0.35, 0.8, (f1 + f2) * 0.6) * (1.0 - smoothstep(0.25, 0.8, yN));
    acc = over(acc, dark > 0.5 ? vec3(0.78, 0.80, 0.84) : vec3(0.86, 0.88, 0.91), fog * 0.75);
  }

  // ---- Mưa: 4 lớp xa gần ----
  if (rainy) {
    float amt = (m == 7) ? 0.45 : ((m == 8) ? 0.75 : 1.0);
    float r = 0.0;
    r += rainLayer(pc, 11.0, 34.0, 520.0, 650.0, 0.8, 1.0, t) * 0.35;
    r += rainLayer(pc, 17.0, 52.0, 640.0, 900.0, 1.1, 2.0, t) * 0.55;
    r += rainLayer(pc, 27.0, 78.0, 780.0, 1250.0, 1.5, 3.0, t) * 0.75 * step(0.5, amt);
    r += rainLayer(pc, 45.0, 120.0, 1000.0, 1700.0, 2.2, 4.0, t) * 0.9 * step(0.9, amt);
    r *= amt * (1.0 - 0.6 * smoothstep(0.35, 1.0, yN));
    vec3 rc = dark > 0.5 ? vec3(0.82, 0.88, 0.96) : vec3(0.40, 0.52, 0.68);
    acc = over(acc, rc, clamp(r, 0.0, 0.85));
    // màn hơi nước khi mưa to
    if (m >= 9) {
      float mist = fbm(pc * 0.004 + vec2(t * 0.05, -t * 0.03)) * (1.0 - smoothstep(0.2, 0.7, yN));
      acc = over(acc, dark > 0.5 ? vec3(0.6, 0.65, 0.72) : vec3(0.75, 0.78, 0.83), mist * 0.25);
    }
  }

  // ---- Tuyết ----
  if (m == 11) {
    float s = 0.0;
    s += snowLayer(pc, 46.0, 22.0, 2.2, 1.0, t) * 0.55;
    s += snowLayer(pc, 70.0, 38.0, 3.4, 2.0, t) * 0.8;
    s += snowLayer(pc, 110.0, 60.0, 5.0, 3.0, t);
    s *= 1.0 - 0.5 * smoothstep(0.4, 1.0, yN);
    acc = over(acc, dark > 0.5 ? vec3(1.0) : vec3(0.70, 0.78, 0.90), clamp(s, 0.0, 0.95));
  }

  // ---- Tia sét + chớp sáng cả trời ----
  if (flash > 0.0) {
    float yEnd = H * (0.28 + 0.18 * hash(vec2(n, 4.0)));
    float bx = boltX + (fbm(vec2(pc.y * 0.010, n)) - 0.5) * 230.0 + (noise(vec2(pc.y * 0.09, n + 1.0)) - 0.5) * 26.0;
    float dist = abs(pc.x - bx);
    float alive = 1.0 - smoothstep(yEnd - 30.0, yEnd, pc.y);
    float coreB = exp(-dist * 0.9) * alive;
    float glowB = exp(-dist * 0.045) * alive * 0.35;
    acc = over(acc, vec3(0.80, 0.86, 1.0), clamp(glowB * flash, 0.0, 1.0));
    acc = over(acc, vec3(1.0), clamp(coreB * flash, 0.0, 1.0));
    acc = over(acc, vec3(0.92, 0.94, 1.0), flash * (dark > 0.5 ? 0.18 : 0.28) * (1.0 - 0.6 * yN));
  }

  float a = clamp(acc.a, 0.0, 1.0);
  fragColor = vec4(acc.rgb * a, a);
}
