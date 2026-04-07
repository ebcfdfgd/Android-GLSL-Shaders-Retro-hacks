#version 110

/*
    ULTIMATE HYBRID SHADER (AIO - Version 110)
    - 1. NTSC Blargg: Dithering, Rainbow & Chroma Bleed [cite: 66, 81, 85]
    - 2. Toshiba V3XEL: Cylindrical Curve, Soft Vignette & Dual Overlays [cite: 94, 103, 110]
    - 3. Pro-E Color: RGB Gain, Luma-Focused Glow & Halation [cite: 116, 128]
    - Optimized for Maximum Speed and Full Feature Set.
*/

// --- PARAMETERS ---
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

#pragma parameter CLU_R_GAIN "Red Gain" 1.0 0.0 2.0 0.02
#pragma parameter CLU_G_GAIN "Green Gain" 1.0 0.0 2.0 0.02
#pragma parameter CLU_B_GAIN "Blue Gain" 1.0 0.0 2.0 0.02
#pragma parameter CLU_CONTRAST "CRT Contrast" 1.10 0.5 2.0 0.05
#pragma parameter CLU_SATURATION "CRT Saturation" 1.3 0.0 2.0 0.05
#pragma parameter CLU_BRIGHT "CRT Brightness" 1.1 1.0 2.0 0.05
#pragma parameter CLU_GLOW "CRT Glow Strength" 0.15 0.0 1.5 0.05
#pragma parameter CLU_HALATION "CRT Halation Strength" 0.15 0.0 1.0 0.02
#pragma parameter CLU_BLK_D "CRT Black Depth" 0.20 0.0 1.0 0.05

#pragma parameter BARREL_DISTORTION "Toshiba Curve Strength" 0.12 0.0 0.5 0.01
#pragma parameter ZOOM "Zoom Amount" 1.0 0.5 2.0 0.01
#pragma parameter v_amount "Soft Vignette Intensity" 0.25 0.0 2.5 0.01
#pragma parameter OverlayMix "L1 Intensity (Overlay)" 1.0 0.0 1.0 0.05
#pragma parameter LUTWidth "L1 Width" 6.0 1.0 1024.0 1.0
#pragma parameter LUTHeight "L1 Height" 4.0 1.0 1024.0 1.0
#pragma parameter OverlayMix2 "L2 Intensity (Multiply)" 0.0 0.0 1.0 0.05
#pragma parameter LUTWidth2 "L2 Width" 6.0 1.0 1024.0 1.0
#pragma parameter LUTHeight2 "L2 Height" 4.0 1.0 1024.0 1.0

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord;
varying vec2 hue_trig; 
uniform mat4 MVPMatrix;

#ifdef PARAMETER_UNIFORM
uniform float ntsc_hue;
#endif

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord;
    hue_trig = vec2(cos(ntsc_hue), sin(ntsc_hue)); // [cite: 69]
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D Texture, overlay, overlay2;
uniform vec2 TextureSize, InputSize, OutputSize;
uniform int FrameCount;
varying vec2 vTexCoord;
varying vec2 hue_trig;

#ifdef PARAMETER_UNIFORM
uniform float ntsc_hue, ntsc_res, ntsc_sharp, fring, afacts, COL_BLEED, rb_power, dot_crawl, rb_detect, de_dither, pi_mod, vert_scal;
uniform float CLU_R_GAIN, CLU_G_GAIN, CLU_B_GAIN, CLU_CONTRAST, CLU_SATURATION, CLU_BRIGHT, CLU_GLOW, CLU_HALATION, CLU_BLK_D;
uniform float BARREL_DISTORTION, ZOOM, v_amount, OverlayMix, LUTWidth, LUTHeight, OverlayMix2, LUTWidth2, LUTHeight2;
#endif

#define PI 3.14159265
float overlay_f(float a, float b) { return a < 0.5 ? (2.0 * a * b) : (1.0 - 2.0 * (1.0 - a) * (1.0 - b)); } // [cite: 101]

void main() {
    vec2 ps = 1.0 / TextureSize;
    vec2 sc = TextureSize / InputSize;
    
    // --- 1. TOSHIBA CYLINDRICAL CURVE ---
    vec2 uv = (vTexCoord * sc) - 0.5;
    uv /= ZOOM; // [cite: 103]
    float kx = BARREL_DISTORTION * 0.2; // [cite: 103]
    float ky = BARREL_DISTORTION * 0.9; // [cite: 104]
    vec2 d_uv;
    d_uv.x = uv.x * (1.0 + (uv.y * uv.y) * kx); // [cite: 104]
    d_uv.y = uv.y * (1.0 + (uv.x * uv.x) * ky); // [cite: 105]
    d_uv *= (1.0 - 0.15 * BARREL_DISTORTION); // [cite: 105]
    
    // Border Check
    if (abs(d_uv.x) > 0.5 || abs(d_uv.y) > 0.5) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0); // [cite: 106]
        return;
    }
    vec2 gC = (d_uv + 0.5) / sc; // [cite: 107]

    // --- 2. NTSC / BLARGG ENGINE ---
    vec3 col_m = texture2D(Texture, gC).rgb; // [cite: 73]
    vec3 col_l = texture2D(Texture, gC - vec2(ps.x, 0.0)).rgb; // [cite: 74]
    vec3 col_r = texture2D(Texture, gC + vec2(ps.x, 0.0)).rgb; // [cite: 74]
    
    float y_m = dot(col_m, vec3(0.299, 0.587, 0.114)); // [cite: 75]
    float y_l = dot(col_l, vec3(0.299, 0.587, 0.114)); // [cite: 75]
    float y_r = dot(col_r, vec3(0.299, 0.587, 0.114)); // [cite: 76]

    float rb_mask = clamp(abs((y_m - y_l) + (y_m - y_r)) / rb_detect, 0.0, 1.0); // [cite: 77]
    float fog_mix = clamp(de_dither - ntsc_res - ntsc_sharp, 0.0, 1.0); // [cite: 78]
    float final_y = mix(y_m, (y_l + y_m + y_r) * 0.3333, fog_mix * rb_mask); // [cite: 78]

    float phase = (floor(gC.x * TextureSize.x) * pi_mod * 0.01745) + (floor(gC.y * TextureSize.y) * vert_scal * PI) + (mod(float(FrameCount), 2.0) * PI); // [cite: 81]
    float art_mod = 1.0 + afacts; // [cite: 82]
    final_y += sin(phase) * dot_crawl * rb_mask * art_mod; // [cite: 83]

    float i = dot(col_m, vec3(0.596, -0.274, -0.322)) + sin(phase) * rb_power * rb_mask * art_mod; // [cite: 83]
    float q = dot(col_m, vec3(0.211, -0.523, 0.311)) + cos(phase) * rb_power * rb_mask * art_mod; // [cite: 84]

    // Chroma Bleed Integration [cite: 85]
    float bleed_off = ps.x * (COL_BLEED + fring * 2.0); // [cite: 85]
    vec3 cL = texture2D(Texture, gC - vec2(bleed_off, 0.0)).rgb; // [cite: 86]
    vec3 cR = texture2D(Texture, gC + vec2(bleed_off, 0.0)).rgb; // [cite: 86]
    i = mix(i, (dot(cL, vec3(0.596, -0.274, -0.3216)) + dot(cR, vec3(0.596, -0.274, -0.3216))) * 0.5, 0.5); // [cite: 87]
    q = mix(q, (dot(cL, vec3(0.211, -0.522, 0.3114)) + dot(cR, vec3(0.211, -0.522, 0.3114))) * 0.5, 0.5); // [cite: 88]

    float fI = i * hue_trig.x - q * hue_trig.y; // [cite: 89]
    float fQ = i * hue_trig.y + q * hue_trig.x;
    
    vec3 res;
    res.r = final_y + 0.956 * fI + 0.621 * fQ; // [cite: 90]
    res.g = final_y - 0.272 * fI - 0.647 * fQ; // [cite: 91]
    res.b = final_y - 1.106 * fI + 1.703 * fQ; // [cite: 92]
    res = clamp(res, 0.0, 1.0);

    // --- 3. PRO COLOR & GLOW/HALATION ---
    res = res * res; // Linearize [cite: 123]
    res *= vec3(CLU_R_GAIN, CLU_G_GAIN, CLU_B_GAIN); // [cite: 124]
    res = (res - 0.5) * CLU_CONTRAST + 0.5; // [cite: 125]
    
    float luma = dot(res, vec3(0.25, 0.5, 0.25)); // [cite: 126]
    res = mix(vec3(luma), res, CLU_SATURATION); // [cite: 126]
    res *= (1.0 - CLU_BLK_D * (1.0 - luma)); // [cite: 127]
    
    // Focused Glow & Halation [cite: 128, 129]
    vec3 glow_mask = pow(max(res, 0.0), vec3(4.0)); // [cite: 128]
    res += glow_mask * (CLU_GLOW + glow_mask * CLU_HALATION); // [cite: 129]
    res *= CLU_BRIGHT; // [cite: 130]

    // --- 4. SOFT VIGNETTE ---
    float vignette = d_uv.x * d_uv.x + d_uv.y * d_uv.y; // [cite: 108]
    res *= clamp(1.0 - vignette * v_amount, 0.0, 1.0); // [cite: 109]

    // --- 5. DUAL OVERLAYS ---
    vec2 mP = vTexCoord * TextureSize / InputSize; // [cite: 109]
    if (OverlayMix > 0.0) {
        vec3 m1 = texture2D(overlay, vec2(fract(mP.x * OutputSize.x / LUTWidth), fract(mP.y * OutputSize.y / LUTHeight))).rgb; // [cite: 111]
        res = mix(res, clamp(vec3(overlay_f(res.r, m1.r), overlay_f(res.g, m1.g), overlay_f(res.b, m1.b)), 0.0, 1.0), OverlayMix); // [cite: 112]
    }
    if (OverlayMix2 > 0.0) {
        vec3 m2 = texture2D(overlay2, vec2(fract(mP.x * OutputSize.x / LUTWidth2), fract(mP.y * OutputSize.y / LUTHeight2))).rgb; // [cite: 114]
        res = mix(res, res * m2, OverlayMix2); // [cite: 115]
    }

    gl_FragColor = vec4(sqrt(max(res, 0.0)), 1.0); // Final Gamma [cite: 130]
}
#endif