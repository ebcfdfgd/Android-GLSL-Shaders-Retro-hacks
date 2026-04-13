/* Blargg Ultra-Lite (131-Genesis Precision Build + Red Persistence)
    - Feature: Fully Autonomous Dither & Rainbow Detection
    - Optimization: Full Bypass on Zero Settings
    - Logic 1010: Directional Red Persistence Smear
*/

#version 110

#pragma parameter ntsc_hue "NTSC Phase Shift" 0.0 -3.14 3.14 0.05
#pragma parameter ntsc_res "Resolution" 0.0 -1.0 1.0 0.05
#pragma parameter ntsc_sharp "Sharpness" 0.1 -1.0 1.0 0.05
#pragma parameter fring "Fringing" 0.0 0.0 1.0 0.05
#pragma parameter afacts "Artifacts" 0.0 0.0 1.0 0.05
#pragma parameter COL_BLEED "Chroma Bleed Strength" 1.2 0.0 5.0 0.05
#pragma parameter red_persistence "Red Persistence (Right Smear)" 1.0 0.0 2.5 0.05
#pragma parameter rb_power "Rainbow Strength" 0.35 0.0 2.0 0.01
#pragma parameter dot_crawl "Dot Crawl Intensity" 0.25 0.0 1.0 0.01
#pragma parameter de_dither "Dither Blending Strength" 0.50 0.0 1.0 0.01
#pragma parameter pi_mod "Subcarrier Phase Angle" 131.5 0.0 360.0 0.1
#pragma parameter vert_scal "Vertical Phase Scale" 0.5 0.0 2.0 0.01

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord;
varying vec2 hue_trig; 

uniform mat4 MVPMatrix;

#ifdef PARAMETER_UNIFORM
uniform float ntsc_hue;
#else
#define ntsc_hue 0.0
#endif

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord;
    hue_trig = vec2(cos(ntsc_hue), sin(ntsc_hue));
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform int FrameCount;
varying vec2 vTexCoord;
varying vec2 hue_trig;

#ifdef PARAMETER_UNIFORM
uniform float ntsc_hue, ntsc_res, ntsc_sharp, fring, afacts, COL_BLEED, red_persistence, rb_power, dot_crawl, de_dither, pi_mod, vert_scal;
#else
#define COL_BLEED 1.2
#define red_persistence 1.0
#define rb_power 0.35
#endif

#define PI 3.14159265

void main() {
    vec2 ps = 1.0 / TextureSize;
    float time = float(FrameCount);
    
    // --- 1. PRIMARY FETCH ---
    vec3 col_m = texture2D(Texture, vTexCoord).rgb;
    float y_m = dot(col_m, vec3(0.299, 0.587, 0.114));
    
    float final_y = y_m;
    float rb_mask = 0.0;

    // --- 2. CONDITIONAL SMART FETCHES ---
    if (de_dither > 0.0 || rb_power > 0.0 || dot_crawl > 0.0) {
        vec3 col_l = texture2D(Texture, vTexCoord - vec2(ps.x, 0.0)).rgb;
        vec3 col_r = texture2D(Texture, vTexCoord + vec2(ps.x, 0.0)).rgb;
        float y_l = dot(col_l, vec3(0.299, 0.587, 0.114));
        float y_r = dot(col_r, vec3(0.299, 0.587, 0.114));

        float diff = abs(y_l - y_r);
        float edge = abs(y_l - y_m) + abs(y_r - y_m);
        float auto_detect = clamp(edge - diff, 0.0, 1.0);
        rb_mask = smoothstep(0.02, 0.15, auto_detect);

        float luma_avg = (y_l * 0.25 + y_m * 0.5 + y_r * 0.25);
        float fog_mix = clamp(de_dither - ntsc_res, 0.0, 1.0);
        final_y = mix(y_m, luma_avg, fog_mix * rb_mask);
    }

    // --- 3. BLARGG ACCURATE PHASE ---
    float x_coord = floor(vTexCoord.x * TextureSize.x);
    float y_coord = floor(vTexCoord.y * TextureSize.y);
    float p_angle = pi_mod * 0.01745329; 
    float phase = (x_coord * p_angle) + (y_coord * vert_scal * PI) + (mod(time, 2.0) * PI);

    // --- 4. INTERFERENCE ---
    float art_mod = 1.0 + afacts; 
    final_y += sin(phase) * dot_crawl * rb_mask * art_mod;

    float i = dot(col_m, vec3(0.596, -0.274, -0.322)) + sin(phase) * rb_power * rb_mask * art_mod;
    float q = dot(col_m, vec3(0.211, -0.523, 0.311)) + cos(phase) * rb_power * rb_mask * art_mod;

    // --- 5. BLEED & PERSISTENCE ---
    float bleed_off = ps.x * (COL_BLEED + fring * 2.0);
    vec3 cL = texture2D(Texture, vTexCoord - vec2(bleed_off, 0.0)).rgb;
    vec3 cR = texture2D(Texture, vTexCoord + vec2(bleed_off, 0.0)).rgb;
    
    float i_l = dot(cL, vec3(0.596, -0.274, -0.3216));
    float i_r = dot(cR, vec3(0.596, -0.274, -0.3216));

    // دمج الكروما العام (Bleed)
    i = mix(i, (i_l + i_r) * 0.5, 0.5);
    q = mix(q, (dot(cL, vec3(0.211, -0.522, 0.3114)) + dot(cR, vec3(0.211, -0.522, 0.3114))) * 0.5, 0.5);

    // تطبيق سيلان الأحمر (Red Persistence Smear)
    if (red_persistence > 0.0) {
        float smear = mix(i, i_l, 0.4 * red_persistence);
        i = mix(i, smear, 0.6);
    }

    float fI = i * hue_trig.x - q * hue_trig.y;
    float fQ = i * hue_trig.y + q * hue_trig.x;

    vec3 rgb;
    rgb.r = final_y + 0.956 * fI + 0.621 * fQ;
    rgb.g = final_y - 0.272 * fI - 0.647 * fQ;
    rgb.b = final_y - 1.106 * fI + 1.703 * fQ;
    
    gl_FragColor = vec4(clamp(rgb, 0.0, 1.0), 1.0);
}
#endif