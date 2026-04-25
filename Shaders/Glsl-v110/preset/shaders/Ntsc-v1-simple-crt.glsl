/* 777-SUPER-HYBRID-NTSC-CRT-QUITEZ
   - MERGED: NTSC Signal processing + CRT Geometry & Bloom
   - FEATURES: Hue, Chroma Bleed, Rainbow, RF Grain, Scanlines, Mask, Barrel Distortion
*/

#version 110

// NTSC Parameters
#pragma parameter ntsc_hue "NTSC Color Hue" 0.0 -3.14 3.14 0.05
#pragma parameter COL_BLEED "Chroma Bleed Strength" 1.5 0.0 5.0 0.05
#pragma parameter SATURATION "Saturation" 1.0 0.0 2.0 0.05
#pragma parameter BLACK_LEVEL "Black Level" 0.0 0.0 1.0 0.05
#pragma parameter red_persistence "Red Persistence" 1.2 0.0 5.0 0.05
#pragma parameter rb_power "Rainbow Strength" 0.15 0.0 2.0 0.01
#pragma parameter rb_size "Rainbow Width" 3.0 0.5 10.0 0.1
#pragma parameter rb_detect "Rainbow Detection" 0.30 0.0 1.0 0.01
#pragma parameter rb_speed "Rainbow Crawl Speed" 0.5 0.0 2.0 0.05
#pragma parameter rb_tilt "Rainbow Diagonal Tilt" 0.5 -2.0 2.0 0.1
#pragma parameter de_dither "MD De-Dither Intensity" 1.0 0.0 2.0 0.1
#pragma parameter sig_noise "Signal RF Grain" 0.04 0.0 0.50 0.01

// CRT/Quilez Parameters
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
varying vec2 vTexCoord;
varying vec2 hTrig;
varying vec2 screen_scale;
uniform mat4 MVPMatrix;
uniform vec2 TextureSize, InputSize;
uniform float ntsc_hue;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord;
    hTrig = vec2(sin(ntsc_hue), cos(ntsc_hue));
    screen_scale = TextureSize / InputSize;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;
uniform int FrameCount;
varying vec2 vTexCoord;
varying vec2 hTrig;
varying vec2 screen_scale;

uniform float ntsc_hue, COL_BLEED, SATURATION, BLACK_LEVEL, red_persistence, rb_power, rb_size, rb_detect, rb_speed, rb_tilt, de_dither, sig_noise;
uniform float BARREL_DISTORTION, BRIGHT_BOOST, VIG_STR, SCAN_STR, SCAN_SIZE, MASK_STR, MASK_W, BLOOM_INT, BLOOM_TH;

const vec3 kY = vec3(0.2989, 0.5870, 0.1140);
const vec3 kI = vec3(0.5959, -0.2744, -0.3216);
const vec3 kQ = vec3(0.2115, -0.5229, 0.3114);

float hash(vec2 co) { return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453); }

void main() {
    // 1. Geometric Warp (CRT)
    vec2 p = (vTexCoord * screen_scale) - 0.5;
    float r2 = dot(p, p);
    vec2 p_curved = p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8));
    vec2 uv = (p_curved + 0.5) / screen_scale;
    
    // 2. NTSC Processing (Using warped UV)
    vec2 ps = vec2(1.0 / TextureSize.x, 0.0);
    float time = float(FrameCount);
    
    vec3 cM = texture2D(Texture, uv).rgb;
    float d_off = max(de_dither, 1.0);
    vec3 cL = texture2D(Texture, uv - ps * d_off).rgb;
    vec3 cR = texture2D(Texture, uv + ps * d_off).rgb;

    float yM = dot(cM, kY);
    float yL = dot(cL, kY);
    float yR = dot(cR, kY);
    float final_y = mix(yM, (yL + yR) * 0.5, 0.5 * de_dither * step(0.001, de_dither));
    final_y += (hash(uv + time * 0.01) - 0.5) * sig_noise * step(0.001, sig_noise);
    final_y = clamp(final_y, 0.0, 1.0);

    float fI = dot(cM, kI);
    float fQ = dot(cM, kQ);
    vec2 b_off = ps * COL_BLEED * 1.5;
    vec3 bcL = texture2D(Texture, uv - b_off).rgb;
    vec3 bcR = texture2D(Texture, uv + b_off).rgb;
    
    float has_bleed = step(0.001, COL_BLEED);
    fI = mix(fI, (dot(bcL, kI) + dot(bcR, kI)) * 0.5, 0.7 * has_bleed);
    fQ = mix(fQ, (dot(bcL, kQ) + dot(bcR, kQ)) * 0.5, 0.7 * has_bleed);
    fI = mix(fI, dot(bcL, kI), 0.4 * red_persistence * step(0.001, red_persistence));

    float edge = abs(yM - yL) + abs(yM - yR);
    float rb_mask = smoothstep(rb_detect, rb_detect + 0.1, edge) * step(0.001, rb_power);
    float ang = (uv.x * TextureSize.x / rb_size) + (uv.y * TextureSize.y * rb_tilt) + (time * rb_speed);
    fI += sin(ang) * rb_power * rb_mask;
    fQ += cos(ang) * rb_power * rb_mask;

    float resI = (fI * hTrig.y - fQ * hTrig.x) * SATURATION;
    float resQ = (fI * hTrig.x + fQ * hTrig.y) * SATURATION;

    vec3 res = vec3(
        final_y + 0.956 * resI + 0.621 * resQ,
        final_y - 0.272 * resI - 0.647 * resQ,
        final_y - 1.106 * resI + 1.703 * resQ
    );
    res = mix(vec3(BLACK_LEVEL), vec3(1.0), res);

    // 3. CRT Aesthetics (Scanlines, Mask, Bloom)
    float scan_pos = (p_curved.y + 0.5) * InputSize.y;
    float scanline = sin(scan_pos * 6.28318 * SCAN_SIZE) * 0.5 + 0.5;
    res = mix(res, res * scanline, SCAN_STR);
    
    float W = floor(MASK_W);
    float pos = mod(gl_FragCoord.x, W) / W;
    vec3 mcol = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), 0.6, 1.6);
    res = mix(res, res * mcol, MASK_STR);

    float luma = dot(res, vec3(0.299, 0.587, 0.114));
    float bloom_mask = max(0.0, luma - BLOOM_TH);
    res += res * bloom_mask * BLOOM_INT;

    res *= BRIGHT_BOOST * (1.0 - r2 * VIG_STR);
    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif