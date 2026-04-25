/* 777-MERGED-SHADER-NTSC-SMART-CRT-SAT
   - INTEGRATED: NTSC SIGNAL (SMART-DITHER-16) + CRT QUILEZ (HYBRID-STABLE)
   - ADDED: Saturation Control
*/

#version 110

// --- NTSC Parameters ---
#pragma parameter ntsc_hue "NTSC Color Hue" 0.0 -3.14 3.14 0.05
#pragma parameter SATURATION "Saturation" 1.0 0.0 2.0 0.05
#pragma parameter COL_BLEED "Chroma Bleed Strength" 1.5 0.0 5.0 0.05
#pragma parameter red_persistence "Red Persistence" 1.2 0.0 5.0 0.05
#pragma parameter rb_power "Rainbow Strength" 0.15 0.0 2.0 0.01
#pragma parameter rb_size "Rainbow Width" 3.0 0.5 10.0 0.1
#pragma parameter rb_detect "Rainbow Detection" 0.30 0.0 1.0 0.01
#pragma parameter rb_speed "Rainbow Crawl Speed" 0.5 0.0 2.0 0.05
#pragma parameter rb_tilt "Rainbow Diagonal Tilt" 0.5 -2.0 2.0 0.1
#pragma parameter ntsc_blur "Smart Dither 16 Intensity" 0.5 0.0 1.0 0.05
#pragma parameter sig_noise "Signal RF Grain" 0.04 0.0 0.50 0.01
#pragma parameter BLACK_LEVEL "Black Level" 0.0 -0.5 0.5 0.01

// --- CRT Parameters ---
#pragma parameter BARREL_DISTORTION "Screen Curve" 0.15 0.0 1.0 0.02
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.17 1.0 2.0 0.01
#pragma parameter VIG_STR "Vignette Intensity" 0.15 0.0 2.0 0.05
#pragma parameter SCAN_STR "Scanline Intensity" 0.35 0.0 1.0 0.05
#pragma parameter SCAN_SIZE "Scanline Density" 1.0 0.5 2.0 0.05
#pragma parameter MASK_STR "Mask Strength" 0.15 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width" 3.0 1.0 10.0 1.0
#pragma parameter BLOOM_INT "Bloom Intensity" 0.3 0.0 1.0 0.05
#pragma parameter BLOOM_TH "Bloom Threshold" 0.7 0.0 1.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv, screen_scale;
varying vec2 hTrig;
uniform mat4 MVPMatrix;
uniform vec2 TextureSize, InputSize;
uniform float ntsc_hue;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    uv = TexCoord;
    screen_scale = TextureSize / InputSize;
    hTrig = vec2(sin(ntsc_hue), cos(ntsc_hue));
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 uv, screen_scale;
varying vec2 hTrig;
uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;
uniform int FrameCount;

uniform float SATURATION, COL_BLEED, red_persistence, rb_power, rb_size, rb_detect, rb_speed, rb_tilt, ntsc_blur, sig_noise, BLACK_LEVEL;
uniform float BARREL_DISTORTION, BRIGHT_BOOST, VIG_STR, SCAN_STR, SCAN_SIZE, MASK_STR, MASK_W, BLOOM_INT, BLOOM_TH;

const vec3 kY = vec3(0.2989, 0.5870, 0.1140);
const vec3 kI = vec3(0.5959, -0.2744, -0.3216);
const vec3 kQ = vec3(0.2115, -0.5229, 0.3114);

float hash(vec2 co) { return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453); }

void main() {
    // 1. CRT Geometry (Warp)
    vec2 p = (uv * screen_scale) - 0.5;
    float r2 = dot(p, p);
    vec2 p_curved = p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8));
    p_curved *= (1.0 - 0.1 * BARREL_DISTORTION);
    
    vec2 tex_uv = (p_curved + 0.5) / screen_scale;
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float check = bounds.x * bounds.y;

    // 2. NTSC SIGNAL PROCESSING
    vec2 ps = vec2(1.0 / TextureSize.x, 0.0);
    float time = mod(float(FrameCount), 600.0);
    
    vec3 cC = texture2D(Texture, tex_uv).rgb;
    vec3 cL = texture2D(Texture, tex_uv - ps).rgb;
    vec3 cR = texture2D(Texture, tex_uv + ps).rgb;

    float yC = dot(cC, kY);
    float yL = dot(cL, kY);
    float yR = dot(cR, kY);

    float d_mask = clamp(abs(yC - yL) * abs(yC - yR) * 50.0, 0.0, 1.0);
    d_mask *= clamp(1.0 - abs(yL - yR) * 5.0, 0.0, 1.0);
    
    vec3 col = mix(cC, (cL + cC + cR) * 0.3333, ntsc_blur * d_mask);
    float final_y = dot(col, kY);

    final_y += (hash(tex_uv + time * 0.01) - 0.5) * sig_noise * step(0.001, sig_noise);

    float fI = dot(col, kI);
    float fQ = dot(col, kQ);

    vec2 b_off = ps * COL_BLEED * 1.5;
    vec3 bcL = texture2D(Texture, tex_uv - b_off).rgb;
    vec3 bcR = texture2D(Texture, tex_uv + b_off).rgb;
    
    float has_bleed = step(0.001, COL_BLEED);
    fI = mix(fI, (dot(bcL, kI) + dot(bcR, kI)) * 0.5, 0.7 * has_bleed);
    fQ = mix(fQ, (dot(bcL, kQ) + dot(bcR, kQ)) * 0.5, 0.7 * has_bleed);
    fI = mix(fI, dot(bcL, kI), 0.4 * red_persistence * step(0.001, red_persistence));

    float edge = abs(yC - yL) + abs(yC - yR);
    float rb_mask = smoothstep(rb_detect, rb_detect + 0.1, edge) * step(0.001, rb_power);
    float ang = (tex_uv.x * TextureSize.x / rb_size) + (tex_uv.y * TextureSize.y * rb_tilt) + (time * rb_speed);
    fI += sin(ang) * rb_power * rb_mask;
    fQ += cos(ang) * rb_power * rb_mask;

    // Apply Saturation & Hue
    float resI = (fI * hTrig.y - fQ * hTrig.x) * SATURATION;
    float resQ = (fI * hTrig.x + fQ * hTrig.y) * SATURATION;

    vec3 res = vec3(
        final_y + 0.956 * resI + 0.621 * resQ,
        final_y - 0.272 * resI - 0.647 * resQ,
        final_y - 1.106 * resI + 1.703 * resQ
    );

    res = mix(vec3(BLACK_LEVEL), vec3(1.0), res);

    // 3. CRT POST-PROCESSING (Scanlines, Mask, Bloom)
    float scan_pos = (p_curved.y + 0.5) * InputSize.y;
    float scanline = sin(scan_pos * 6.28318 * SCAN_SIZE) * 0.5 + 0.5;
    res = mix(res, res * scanline, SCAN_STR);
    
    float pos = mod(gl_FragCoord.x, floor(MASK_W)) / floor(MASK_W);
    res = mix(res, res * clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), 0.6, 1.6), MASK_STR);
    
    float bloom_mask = max(0.0, dot(res, kY) - BLOOM_TH);
    res += res * bloom_mask * BLOOM_INT;
    
    res *= BRIGHT_BOOST * (1.0 - r2 * VIG_STR);
    
    gl_FragColor = vec4(clamp(res, 0.0, 1.0) * check, 1.0);
}
#endif