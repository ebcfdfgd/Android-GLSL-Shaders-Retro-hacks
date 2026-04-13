#version 110

/* ULTIMATE-MASTER-HYBRID (CHROMA & BLEED FIXED)
    - Fixed: Chroma Bleeding and De-dither integration.
    - Feature: Proper YIQ sampling for smoother color transitions.
*/

// --- 1. NTSC & Signal Parameters ---
#pragma parameter ntsc_res "NTSC: Resolution" 0.0 -1.0 1.0 0.05
#pragma parameter ntsc_sharp "NTSC: Sharpness" 0.1 -1.0 1.0 0.05
#pragma parameter fring "NTSC: Fringing" 0.0 0.0 1.0 0.05
#pragma parameter afacts "NTSC: Artifacts" 0.0 0.0 1.0 0.05
#pragma parameter ntsc_hue "NTSC: Color Hue" 0.0 -3.14 3.14 0.05
#pragma parameter COL_BLEED "NTSC: Chroma Bleed" 1.0 0.0 5.0 0.05
#pragma parameter rb_power "NTSC: Rainbow Strength" 0.15 0.0 2.0 0.01
#pragma parameter rb_size "NTSC: Rainbow Width" 3.0 0.5 10.0 0.1
#pragma parameter rb_detect "NTSC: Rainbow Detect" 0.30 0.0 1.0 0.01
#pragma parameter rb_speed "NTSC: Rainbow Speed" 0.5 0.0 2.0 0.05
#pragma parameter rb_tilt "NTSC: Rainbow Tilt" 0.5 -2.0 2.0 0.1
#pragma parameter de_dither "MD: De-Dither Intensity" 1.0 0.0 2.0 0.1
#pragma parameter ntsc_grain "MD: Signal Grain (RF)" 0.01 0.0 0.20 0.01
#pragma parameter tv_mist "MD: TV Signal Mist" 0.1 0.0 1.5 0.05

// --- 2. Color & Glow Parameters ---
#pragma parameter CLU_R_GAIN "Color: Red Gain" 1.0 0.0 2.0 0.02
#pragma parameter CLU_G_GAIN "Color: Green Gain" 1.0 0.0 2.0 0.02
#pragma parameter CLU_B_GAIN "Color: Blue Gain" 1.0 0.0 2.0 0.02
#pragma parameter CLU_CONTRAST "Color: Contrast" 1.10 0.5 2.0 0.05
#pragma parameter CLU_SATURATION "Color: Saturation" 1.3 0.0 2.0 0.05
#pragma parameter CLU_BRIGHT "Color: Brightness" 1.1 1.0 2.0 0.05
#pragma parameter CLU_GLOW "Color: Glow Strength" 0.15 0.0 1.5 0.05
#pragma parameter CLU_HALATION "Color: Halation" 0.15 0.0 1.0 0.02
#pragma parameter CLU_BLK_D "Color: Black Depth" 0.20 0.0 1.0 0.05

// --- 3. Geometry & Mask Parameters ---
#pragma parameter BARREL_DISTORTION "CRT: Toshiba Curve" 0.12 0.0 0.5 0.01
#pragma parameter BRIGHT_BOOST "CRT: Bright Boost" 1.2 1.0 2.5 0.05
#pragma parameter v_amount "CRT: Vignette" 0.25 0.0 2.5 0.01
#pragma parameter MASK_TYPE "Mask: 0:RGB, 1:PNG" 0.0 0.0 1.0 1.0
#pragma parameter MASK_STR "Mask: Intensity" 0.45 0.0 1.0 0.05
#pragma parameter MASK_W "Mask: Width" 3.0 1.0 15.0 1.0
#pragma parameter MASK_H "Mask: Height" 3.0 1.0 15.0 1.0
#pragma parameter SCAN_STR "Scan: Intensity" 0.40 0.0 1.0 0.05
#pragma parameter SCAN_DENS "Scan: Density" 1.0 0.2 10.0 0.1

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 TEX0;
varying vec2 hue_trig; 
uniform mat4 MVPMatrix;
#ifdef PARAMETER_UNIFORM
uniform float ntsc_hue;
#endif

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    TEX0 = TexCoord;
    hue_trig = vec2(cos(ntsc_hue), sin(ntsc_hue));
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 TEX0;
varying vec2 hue_trig;

uniform sampler2D Texture, SamplerMask1;
uniform vec2 TextureSize, InputSize;
uniform int FrameCount;

#ifdef PARAMETER_UNIFORM
uniform float ntsc_res, ntsc_sharp, fring, afacts, ntsc_hue, COL_BLEED, rb_power, rb_size, rb_detect, rb_speed, rb_tilt, de_dither, ntsc_grain, tv_mist;
uniform float CLU_R_GAIN, CLU_G_GAIN, CLU_B_GAIN, CLU_CONTRAST, CLU_SATURATION, CLU_BRIGHT, CLU_GLOW, CLU_HALATION, CLU_BLK_D;
uniform float BARREL_DISTORTION, BRIGHT_BOOST, v_amount, MASK_TYPE, MASK_STR, MASK_W, MASK_H, SCAN_STR, SCAN_DENS;
#endif

float noise(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    // 1. Geometry (Toshiba)
    vec2 sc = TextureSize / InputSize;
    vec2 uv_c = (TEX0.xy * sc) - 0.5;
    vec2 d_uv;
    d_uv.x = uv_c.x * (1.0 + (uv_c.y * uv_c.y) * BARREL_DISTORTION * 0.2);
    d_uv.y = uv_c.y * (1.0 + (uv_c.x * uv_c.x) * BARREL_DISTORTION * 0.9);
    d_uv *= (1.0 - 0.15 * BARREL_DISTORTION);
    
    if (abs(d_uv.x) > 0.5 || abs(d_uv.y) > 0.5) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }
    vec2 final_uv = (d_uv + 0.5) / sc;

    // 2. Signal Processing (NTSC)
    float res_mod = 1.0 - (ntsc_res * 0.5);
    vec2 ps = vec2(res_mod / TextureSize.x, 1.0 / TextureSize.y);
    float time = float(FrameCount);

    vec3 col_m = texture2D(Texture, final_uv).rgb;
    vec3 col_l = texture2D(Texture, final_uv - vec2(ps.x * de_dither, 0.0)).rgb;
    vec3 col_r = texture2D(Texture, final_uv + vec2(ps.x * de_dither, 0.0)).rgb;

    // Fixed Chroma Bleeding Sampling
    float bleed_step = ps.x * COL_BLEED;
    vec3 col_bl = texture2D(Texture, final_uv - vec2(bleed_step, 0.0)).rgb;
    vec3 col_br = texture2D(Texture, final_uv + vec2(bleed_step, 0.0)).rgb;

    mat3 RGBtoYIQ = mat3(0.2989, 0.5870, 0.1140, 0.5959, -0.2744, -0.3216, 0.2115, -0.5229, 0.3114);

    // YIQ Conversion & Sharpness
    float y_m = dot(col_m, vec3(0.2989, 0.5870, 0.1140));
    float y_l = dot(col_l, vec3(0.2989, 0.5870, 0.1140));
    float y_r = dot(col_r, vec3(0.2989, 0.5870, 0.1140));

    // FIX: Average Chroma for Bleeding Effect
    vec2 iq_m = (col_m * RGBtoYIQ).gb;
    vec2 iq_l = (col_bl * RGBtoYIQ).gb;
    vec2 iq_r = (col_br * RGBtoYIQ).gb;
    vec2 final_iq = mix(iq_m, (iq_l + iq_r) * 0.5, 0.5);

    float final_y = mix(y_m, (y_l + y_r) * 0.5, 0.4);
    final_y += (final_y - (y_l + y_r) * 0.5) * ntsc_sharp;

    float edge = abs(final_y - y_l) + abs(final_y - y_r);
    float rb_mask = smoothstep(rb_detect, rb_detect + 0.2, edge);
    float angle = (final_uv.x * TextureSize.x / rb_size) + (final_uv.y * TextureSize.y * rb_tilt) + (time * rb_speed);
    
    // Chroma artifacts
    float fI = final_iq.x + sin(angle) * (rb_power + afacts*0.5 + fring*0.5) * rb_mask;
    float fQ = final_iq.y + cos(angle) * (rb_power + afacts*0.5 + fring*0.5) * rb_mask;
    
    float hI = fI * hue_trig.x - fQ * hue_trig.y;
    float hQ = fI * hue_trig.y + fQ * hue_trig.x;

    final_y = mix(final_y, (y_l + final_y + y_r) * 0.333, tv_mist);
    final_y += (noise(final_uv + mod(time, 60.0)) - 0.5) * ntsc_grain;
    
    // YIQ to RGB
    vec3 res;
    res.r = final_y + 0.956 * hI + 0.6210 * hQ;
    res.g = final_y - 0.2720 * hI - 0.6474 * hQ;
    res.b = final_y - 1.1060 * hI + 1.7046 * hQ;

    // 3. Pro Color Engine
    res = clamp(res, 0.0, 1.0);
    res = pow(res, vec3(2.2)); // Linearize

    res *= vec3(CLU_R_GAIN, CLU_G_GAIN, CLU_B_GAIN);
    res = (res - 0.5) * CLU_CONTRAST + 0.5;
    
    float luma = dot(res, vec3(0.299, 0.587, 0.114));
    res = mix(vec3(luma), res, CLU_SATURATION);
    res *= (1.0 - CLU_BLK_D * (1.0 - luma));

    vec3 glow = pow(max(res, 0.0), vec3(4.0));
    res += glow * (CLU_GLOW + glow * CLU_HALATION);
    res *= (CLU_BRIGHT * BRIGHT_BOOST);

    // 4. Scanlines & Mask
    if (SCAN_STR > 0.0) {
        float scanline = sin((gl_FragCoord.y / max(SCAN_DENS, 0.1)) * 3.14159) * 0.5 + 0.5;
        res = mix(res, res * scanline, SCAN_STR);
    }

    if (MASK_STR > 0.0) {
        vec3 mcol = vec3(1.0);
        float mw = floor(max(MASK_W, 1.0));
        float mh = floor(max(MASK_H, 1.0));

        if (MASK_TYPE < 0.5) {
            float pos_x = mod(gl_FragCoord.x, mw);
            float pos_y = mod(gl_FragCoord.y, mh);
            
            vec3 rgb_mask = (pos_x < mw/3.0) ? vec3(1.4, 0.6, 0.6) : (pos_x < 2.0*mw/3.0) ? vec3(0.6, 1.4, 0.6) : vec3(0.6, 0.6, 1.4);
            float v_gap = (pos_y < mh * 0.8) ? 1.0 : 0.7;
            mcol = rgb_mask * v_gap;
        } else {
            mcol = texture2D(SamplerMask1, gl_FragCoord.xy / vec2(mw, mh)).rgb * 1.5;
        }
        res = mix(res, res * mcol, MASK_STR);
    }

    // 5. Final Output
    res *= clamp(1.0 - (dot(d_uv, d_uv) * v_amount), 0.0, 1.0);
    gl_FragColor = vec4(pow(max(res, 0.0), vec3(1.0/2.2)), 1.0);
}
#endif