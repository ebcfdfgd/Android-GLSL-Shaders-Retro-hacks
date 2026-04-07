#version 110

/* ULTIMATE-OMNI-ENGINE (Hybrid 300 Optimized - Backported to 110)
    - Integrated: Toshiba Cylindrical Curve & Dual Mask System (RGB/PNG).
    - Integrated: Blargg NTSC 131-Genesis Precision (Dithering & Rainbows).
    - Integrated: Pro-E Color Profiles (EU, US, JP) & High-Luma Glow.
    - Performance: Exactly 5 Texture Samples for Maximum Speed.
*/

// --- 1. Blargg NTSC & Artifacts Parameters ---
#pragma parameter ntsc_hue "NTSC Phase Shift" 0.0 -3.14 3.14 0.05
#pragma parameter ntsc_res "Resolution" 0.0 -1.0 1.0 0.05
#pragma parameter ntsc_sharp "Sharpness" 0.1 -1.0 1.0 0.05
#pragma parameter fring "Fringing" 0.0 0.0 1.0 0.05
#pragma parameter afacts "Artifacts" 0.0 0.0 1.0 0.05
#pragma parameter COL_BLEED "Chroma Bleed Strength" 1.2 0.0 5.0 0.05
#pragma parameter rb_power "Rainbow Strength" 0.35 0.0 2.0 0.01
#pragma parameter dot_crawl "Dot Crawl Intensity" 0.25 0.0 1.0 0.01
#pragma parameter rb_detect "Dither Sensitivity" 0.10 0.01 1.0 0.01
#pragma parameter de_dither "Blur (Fog) Strength" 0.40 0.0 1.0 0.01
#pragma parameter pi_mod "Subcarrier Phase Angle" 131.5 0.0 360.0 0.1
#pragma parameter vert_scal "Vertical Phase Scale" 0.5 0.0 2.0 0.01

// --- 2. Color Profiles & Adjustments ---
#pragma parameter CLU_PROFILE "Color Profile (EU, US, JP)" 0.0 0.0 3.0 1.0
#pragma parameter CLU_CONTRAST "CRT Contrast" 1.10 0.5 2.0 0.05
#pragma parameter CLU_SATURATION "CRT Saturation" 1.3 0.0 2.0 0.05
#pragma parameter CLU_BRIGHT "CRT Brightness" 1.1 1.0 2.0 0.05
#pragma parameter CLU_GLOW "CRT Glow Strength" 0.15 0.0 1.5 0.05
#pragma parameter CLU_HALATION "CRT Halation Strength" 0.15 0.0 1.0 0.02
#pragma parameter CLU_BLK_D "CRT Black Depth" 0.20 0.0 1.0 0.05

// --- 3. X-Light Geometry, Mask & Scanlines ---
#pragma parameter BARREL_DISTORTION "Toshiba Curve Strength" 0.12 0.0 0.5 0.01
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 2.5 0.05
#pragma parameter v_amount "Vignette Intensity" 0.25 0.0 2.5 0.01
#pragma parameter MASK_TYPE "Mask: 0:RGB, 1:PNG" 0.0 0.0 1.0 1.0
#pragma parameter MASK_STR "Mask Intensity" 0.45 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width" 3.0 1.0 15.0 1.0
#pragma parameter MASK_H "Mask Height" 3.0 1.0 15.0 1.0
#pragma parameter SCAN_STR "Scanline Intensity" 0.40 0.0 1.0 0.05
#pragma parameter SCAN_DENS "Scanline Density" 1.0 0.2 10.0 0.1

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 TEX0;
varying vec2 hue_trig;
uniform mat4 MVPMatrix;
uniform float ntsc_hue;

void main() {
    TEX0 = TexCoord;
    hue_trig = vec2(cos(ntsc_hue), sin(ntsc_hue));
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 TEX0;
varying vec2 hue_trig;

uniform sampler2D Texture, SamplerMask1;
uniform vec2 TextureSize, InputSize, OutputSize;
uniform int FrameCount;

#ifdef PARAMETER_UNIFORM
uniform float ntsc_hue, ntsc_res, ntsc_sharp, fring, afacts, COL_BLEED, rb_power, dot_crawl, rb_detect, de_dither, pi_mod, vert_scal;
uniform float CLU_PROFILE, CLU_CONTRAST, CLU_SATURATION, CLU_BRIGHT, CLU_GLOW, CLU_HALATION, CLU_BLK_D;
uniform float BARREL_DISTORTION, BRIGHT_BOOST, v_amount, MASK_TYPE, MASK_STR, MASK_W, MASK_H, SCAN_STR, SCAN_DENS;
#endif

#define PI 3.14159265

void main() {
    // --- [A] Geometry: Toshiba Cylindrical Curve ---
    vec2 sc = TextureSize / InputSize;
    vec2 uv_base = (TEX0 * sc) - 0.5;
    float kx = BARREL_DISTORTION * 0.2;
    float ky = BARREL_DISTORTION * 0.9; 
    vec2 d_uv;
    d_uv.x = uv_base.x * (1.0 + (uv_base.y * uv_base.y) * kx);
    d_uv.y = uv_base.y * (1.0 + (uv_base.x * uv_base.x) * ky);
    d_uv *= (1.0 - 0.15 * BARREL_DISTORTION);

    if (abs(d_uv.x) > 0.5 || abs(d_uv.y) > 0.5) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0); 
        return;
    }
    
    vec2 final_uv = (d_uv + 0.5) / sc;
    vec2 ps = 1.0 / TextureSize;
    float time = float(FrameCount);

    // --- [B] Optimized 5-Tap Sampling (Blargg + Bleed) ---
    vec3 col_m = texture2D(Texture, final_uv).rgb;
    vec3 col_l = texture2D(Texture, final_uv - vec2(ps.x, 0.0)).rgb;
    vec3 col_r = texture2D(Texture, final_uv + vec2(ps.x, 0.0)).rgb;
    
    float bleed_off = ps.x * (COL_BLEED + fring * 2.0);
    vec3 cL = texture2D(Texture, final_uv - vec2(bleed_off, 0.0)).rgb;
    vec3 cR = texture2D(Texture, final_uv + vec2(bleed_off, 0.0)).rgb;

    // --- [C] NTSC Processing (Blargg Logic) ---
    float y_m = dot(col_m, vec3(0.299, 0.587, 0.114));
    float y_l = dot(col_l, vec3(0.299, 0.587, 0.114));
    float y_r = dot(col_r, vec3(0.299, 0.587, 0.114));
    
    float dither_diff = abs((y_m - y_l) + (y_m - y_r));
    float rb_mask = clamp(dither_diff / rb_detect, 0.0, 1.0);
    float fog_mix = clamp(de_dither - ntsc_res - ntsc_sharp, 0.0, 1.0);
    float final_y = mix(y_m, (y_l + y_m + y_r) * 0.3333, fog_mix * rb_mask);

    float phase = (floor(final_uv.x * TextureSize.x) * pi_mod * 0.01745) + (floor(final_uv.y * TextureSize.y) * vert_scal * PI) + (mod(time, 2.0) * PI);
    final_y += sin(phase) * dot_crawl * rb_mask * (1.0 + afacts);

    float i = dot(col_m, vec3(0.596, -0.274, -0.322)) + sin(phase) * rb_power * rb_mask * (1.0 + afacts);
    float q = dot(col_m, vec3(0.211, -0.523, 0.311)) + cos(phase) * rb_power * rb_mask * (1.0 + afacts);

    i = mix(i, (dot(cL, vec3(0.596, -0.274, -0.3216)) + dot(cR, vec3(0.596, -0.274, -0.3216))) * 0.5, 0.5);
    q = mix(q, (dot(cL, vec3(0.211, -0.522, 0.3114)) + dot(cR, vec3(0.211, -0.522, 0.3114))) * 0.5, 0.5);

    float fI = i * hue_trig.x - q * hue_trig.y;
    float fQ = i * hue_trig.y + q * hue_trig.x;

    vec3 res;
    res.r = final_y + 0.956 * fI + 0.621 * fQ;
    res.g = final_y - 0.272 * fI - 0.647 * fQ;
    res.b = final_y - 1.106 * fI + 1.703 * fQ;
    res = clamp(res * res, 0.0, 1.0); // Linearize

    // --- [D] Color Profiles (Pro-E) ---
    if (CLU_PROFILE > 1.5 && CLU_PROFILE < 2.5) { 
        res = clamp(res * mat3(0.95, 0.05, 0.0, 0.02, 0.98, 0.0, 0.0, 0.05, 0.95), 0.0, 1.0); 
    } 
    else if (CLU_PROFILE > 2.5) { 
        res = clamp(res * mat3(0.9, 0.1, 0.0, 0.05, 0.9, 0.05, 0.0, 0.1, 1.1), 0.0, 1.0); 
    }

    // --- [E] CRT Adjustments ---
    res = (res - 0.5) * CLU_CONTRAST + 0.5;
    float luma = dot(res, vec3(0.299, 0.587, 0.114));
    res = mix(vec3(luma), res, CLU_SATURATION);
    res *= (1.0 - CLU_BLK_D * (1.0 - luma));

    // High-Luma Glow
    vec3 glow_mask = pow(max(res, 0.0), vec3(4.0));
    res += glow_mask * (CLU_GLOW + glow_mask * CLU_HALATION);

    // --- [F] Smart Effects ---
    if (SCAN_STR > 0.0) {
        float scanline = sin((gl_FragCoord.y / max(SCAN_DENS, 0.1)) * 3.14159) * 0.5 + 0.5;
        res = mix(res, res * scanline, SCAN_STR);
    }

    if (MASK_STR > 0.0) {
        vec3 mcol = vec3(1.0);
        float mw = floor(max(MASK_W, 1.0)), mh = floor(max(MASK_H, 1.0));
        if (MASK_TYPE < 0.5) {
            float pos = mod(gl_FragCoord.x, mw);
            if (mw <= 3.5) mcol = (pos < 1.0) ? vec3(1.4, 0.6, 0.6) : (pos < 2.0) ? vec3(0.6, 1.4, 0.6) : vec3(0.6, 0.6, 1.4);
            else {
                float r = pos / mw;
                mcol = vec3(clamp(abs(r*6.0-3.0)-1.0, 0.0, 1.0), clamp(2.0-abs(r*6.0-2.0), 0.0, 1.0), clamp(2.0-abs(r*6.0-4.0), 0.0, 1.0)) * 1.6;
            }
        } else mcol = texture2D(SamplerMask1, gl_FragCoord.xy / vec2(mw, mh)).rgb * 1.5;
        res = mix(res, res * mcol, MASK_STR);
    }

    res *= clamp(1.0 - (dot(d_uv, d_uv) * v_amount), 0.0, 1.0); // Vignette
    res *= CLU_BRIGHT * BRIGHT_BOOST;

    gl_FragColor = vec4(sqrt(max(res, 0.0)), 1.0);
}
#endif