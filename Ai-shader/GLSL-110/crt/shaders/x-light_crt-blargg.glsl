#version 110

/* CRT-ULTIMATE-OMNI-PROJECT (Merged Edition - Backported to 110)
    - Integrated: Blargg NTSC Precision (Dithering & Rainbows)
    - Integrated: Pro-E Color Profiles (EU, US, JP) & Glow/Halation
    - Integrated: X-Light Geometry, Scanlines, and Balanced RGB Mask
    - Performance: Exactly 5 Texture Samples for optimized balance.
*/

// --- 1. Blargg NTSC Parameters ---
#pragma parameter ntsc_hue "NTSC Phase Shift" 0.0 -3.14 3.14 0.05
#pragma parameter ntsc_res "NTSC Resolution" 0.0 -1.0 1.0 0.05
#pragma parameter ntsc_sharp "NTSC Sharpness" 0.1 -1.0 1.0 0.05
#pragma parameter fring "NTSC Fringing" 0.0 0.0 1.0 0.05
#pragma parameter afacts "NTSC Artifacts" 0.0 0.0 1.0 0.05
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
#pragma parameter CLU_BLK_D "CRT Black Depth" 0.20 0.0 1.0 0.05
#pragma parameter CLU_GLOW "CRT Glow Strength" 0.15 0.0 1.5 0.05
#pragma parameter CLU_HALATION "CRT Halation Strength" 0.15 0.0 1.0 0.02

// --- 3. X-Light Geometry & CRT Effects ---
#pragma parameter BARREL_DISTORTION "Screen Curve" 0.15 0.0 0.3 0.01
#pragma parameter BRIGHT_BOOST "X-Light Brightness" 1.05 1.0 2.5 0.05
#pragma parameter VIG_STR "Vignette Intensity" 0.15 0.0 2.0 0.05
#pragma parameter SCAN_STR "Scanline Intensity" 0.35 0.0 1.0 0.05
#pragma parameter SCAN_SIZE "Scanline Size (Zoom)" 5.0 1.0 10.0 0.5
#pragma parameter MASK_STR "Mask Strength" 0.15 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width" 3.0 1.0 10.0 1.0

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
varying vec2 hue_trig;
uniform mat4 MVPMatrix;
uniform float ntsc_hue;

void main() {
    uv = TexCoord;
    hue_trig = vec2(cos(ntsc_hue), sin(ntsc_hue));
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 uv;
varying vec2 hue_trig;

uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;
uniform int FrameCount;

#ifdef PARAMETER_UNIFORM
uniform float ntsc_hue, ntsc_res, ntsc_sharp, fring, afacts, COL_BLEED, rb_power, dot_crawl, rb_detect, de_dither, pi_mod, vert_scal;
uniform float CLU_PROFILE, CLU_CONTRAST, CLU_SATURATION, CLU_BRIGHT, CLU_BLK_D, CLU_GLOW, CLU_HALATION;
uniform float BARREL_DISTORTION, BRIGHT_BOOST, VIG_STR, SCAN_STR, SCAN_SIZE, MASK_STR, MASK_W;
#endif

#define PI 3.14159265

void main() {
    vec2 sc = TextureSize / InputSize;
    vec2 p = (uv * sc) - 0.5;

    // --- 1. Geometry (X-Light) ---
    float ky = BARREL_DISTORTION * 0.8; 
    vec2 p_curved;
    p_curved.x = p.x * (1.0 + (p.y * p.y) * (BARREL_DISTORTION * 0.2));
    p_curved.y = p.y * (1.0 + (p.x * p.x) * ky);
    p_curved *= (1.0 - 0.1 * BARREL_DISTORTION);

    if (abs(p_curved.x) > 0.5 || abs(p_curved.y) > 0.5) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0); 
        return;
    }
    
    vec2 final_uv = (p_curved + 0.5) / sc;
    vec2 ps = 1.0 / TextureSize;
    float time = float(FrameCount);

    // --- 2. Optimized 5-Tap Sampling (Combined Blargg + Bleed) ---
    vec3 col_m = texture2D(Texture, final_uv).rgb;
    vec3 col_l = texture2D(Texture, final_uv - vec2(ps.x, 0.0)).rgb;
    vec3 col_r = texture2D(Texture, final_uv + vec2(ps.x, 0.0)).rgb;
    
    float bleed_off = ps.x * (COL_BLEED + fring * 2.0);
    vec3 cL = texture2D(Texture, final_uv - vec2(bleed_off, 0.0)).rgb;
    vec3 cR = texture2D(Texture, final_uv + vec2(bleed_off, 0.0)).rgb;

    // --- 3. NTSC Processing (Blargg) ---
    float y_m = dot(col_m, vec3(0.299, 0.587, 0.114));
    float y_l = dot(col_l, vec3(0.299, 0.587, 0.114));
    float y_r = dot(col_r, vec3(0.299, 0.587, 0.114));
    
    float dither_diff = abs((y_m - y_l) + (y_m - y_r));
    float rb_mask = clamp(dither_diff / rb_detect, 0.0, 1.0);
    float fog_mix = clamp(de_dither - ntsc_res - ntsc_sharp, 0.0, 1.0);
    float final_y = mix(y_m, (y_l + y_m + y_r) * 0.3333, fog_mix * rb_mask);

    float phase = (floor(final_uv.x * TextureSize.x) * pi_mod * 0.01745) + (floor(final_uv.y * TextureSize.y) * vert_scal * PI) + (mod(time, 2.0) * PI);
    float art_mod = 1.0 + afacts;
    final_y += sin(phase) * dot_crawl * rb_mask * art_mod;

    float i = dot(col_m, vec3(0.596, -0.274, -0.322)) + sin(phase) * rb_power * rb_mask * art_mod;
    float q = dot(col_m, vec3(0.211, -0.523, 0.311)) + cos(phase) * rb_power * rb_mask * art_mod;

    i = mix(i, (dot(cL, vec3(0.596, -0.274, -0.321)) + dot(cR, vec3(0.596, -0.274, -0.321))) * 0.5, 0.5);
    q = mix(q, (dot(cL, vec3(0.211, -0.522, 0.311)) + dot(cR, vec3(0.211, -0.522, 0.311))) * 0.5, 0.5);

    float fI = i * hue_trig.x - q * hue_trig.y;
    float fQ = i * hue_trig.y + q * hue_trig.x;

    vec3 res;
    res.r = final_y + 0.956 * fI + 0.621 * fQ;
    res.g = final_y - 0.272 * fI - 0.647 * fQ;
    res.b = final_y - 1.106 * fI + 1.703 * fQ;
    res = clamp(res * res, 0.0, 1.0); // Linearize

    // --- 4. Color Profiles (Pro-E) ---
    if (CLU_PROFILE > 1.5 && CLU_PROFILE < 2.5) { 
        res = clamp(res * mat3(0.95, 0.05, 0.0, 0.02, 0.98, 0.0, 0.0, 0.05, 0.95), 0.0, 1.0); 
    } 
    else if (CLU_PROFILE > 2.5) { 
        res = clamp(res * mat3(0.9, 0.1, 0.0, 0.05, 0.9, 0.05, 0.0, 0.1, 1.1), 0.0, 1.0); 
    }

    // --- 5. Final CRT Adjustments ---
    res = (res - 0.5) * CLU_CONTRAST + 0.5;
    float luma = dot(res, vec3(0.299, 0.587, 0.114));
    res = mix(vec3(luma), res, CLU_SATURATION);
    res *= (1.0 - CLU_BLK_D * (1.0 - luma));

    // Vignette
    res *= (1.0 - dot(p_curved, p_curved) * VIG_STR);

    // Scanlines & Mask
    float scanline = sin(gl_FragCoord.y * (6.28318 / SCAN_SIZE)) * 0.5 + 0.5;
    res *= mix(1.0, scanline, SCAN_STR);

    float pos = mod(gl_FragCoord.x, floor(MASK_W));
    float W = floor(MASK_W);
    vec3 mcol = clamp(2.0 - abs((pos / W) * 6.0 - vec3(1.0, 3.0, 5.0)), 0.6, 1.6);
    res = mix(res, res * mcol, MASK_STR);

    // Glow & Halation
    vec3 glow_mask = pow(max(res, 0.0), vec3(4.0));
    res += glow_mask * (CLU_GLOW + glow_mask * CLU_HALATION);
    
    res *= CLU_BRIGHT * BRIGHT_BOOST;

    gl_FragColor = vec4(sqrt(max(res, 0.0)), 1.0);
}
#endif