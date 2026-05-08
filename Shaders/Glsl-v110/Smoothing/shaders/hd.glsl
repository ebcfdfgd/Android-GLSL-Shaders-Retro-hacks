#version 110

/* ULTIMATE SONIC 2026 - CLEAN GAMMA EDITION (FIXED)
    - Fix: Gamma now increases richness/depth instead of washing out.
    - Optimization: Full Bypass logic preserved.
*/

#pragma parameter NTSC_STR "Dither: Smart Eraser" 0.65 0.0 1.0 0.05
#pragma parameter EDGE_SHINE "Light: Edge Specular" 0.45 0.0 1.0 0.05
#pragma parameter OUTLINE_STR "Detail: Outline Power" 0.20 0.0 1.0 0.05
#pragma parameter MICRO_AO "Depth: Micro-AO" 0.35 0.0 1.0 0.05
#pragma parameter AO_SKIN_PROT "Depth: AO Skin Protect" 0.60 0.0 1.0 0.05
#pragma parameter RIM_LIGHT "Light: Rim Strength" 0.65 0.0 2.0 0.05
#pragma parameter VIBRANCE "Color: Vibrance" 1.40 1.0 2.0 0.10
#pragma parameter WARMTH "Color: Warmth" 0.0 -0.50 0.50 0.05
#pragma parameter GAMMA "Color: Gamma Intensity" 1.0 1.0 2.5 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec4 TexCoord;
varying vec2 texCoord;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    texCoord = TexCoord.xy;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision mediump float;
#endif

varying vec2 texCoord;
uniform sampler2D Texture;
uniform vec2 TextureSize;

#ifdef PARAMETER_UNIFORM
uniform float NTSC_STR, EDGE_SHINE, OUTLINE_STR, MICRO_AO, AO_SKIN_PROT, RIM_LIGHT, VIBRANCE, WARMTH, GAMMA;
#endif

const vec3 lumaWeight = vec3(0.299, 0.587, 0.114);

void main() {
    // [0] FAST FETCH & SMART BYPASS
    vec3 col_m = texture2D(Texture, texCoord).rgb;

    if (NTSC_STR <= 0.0 && EDGE_SHINE <= 0.0 && MICRO_AO <= 0.0) {
        vec3 quick_res = mix(vec3(dot(col_m, lumaWeight)), col_m, VIBRANCE);
        quick_res.rb += vec2(WARMTH, -WARMTH) * 0.05;
        // هنا تم تعديل الجاما ليصبح أس مباشر
        quick_res = pow(max(quick_res, 0.0), vec3(GAMMA));
        gl_FragColor = vec4(quick_res, 1.0);
        return; 
    }

    // [1] FULL FETCHING
    vec2 px = 1.0 / TextureSize;
    vec3 col_l = texture2D(Texture, texCoord - vec2(px.x, 0.0)).rgb;
    vec3 col_r = texture2D(Texture, texCoord + vec2(px.x, 0.0)).rgb;
    vec3 col_u = texture2D(Texture, texCoord + vec2(0.0, px.y)).rgb;

    float y_m = dot(col_m, lumaWeight);
    float y_l = dot(col_l, lumaWeight);
    float y_r = dot(col_r, lumaWeight);
    float y_u = dot(col_u, lumaWeight);

    // [2] SMART DITHER
    float pattern = abs(y_m - y_l) * abs(y_m - y_r);
    float d_mask = clamp(pattern * 50.0, 0.0, 1.0) * clamp(1.0 - abs(y_l - y_r) * 5.0, 0.0, 1.0);
    vec3 res = mix(col_m, (col_l + col_m + col_r) * 0.3333, NTSC_STR * d_mask);

    // [3] OUTLINE & EDGE CALC
    vec3 diff_r = res - col_r;
    vec3 diff_u = res - col_u;
    float edge = dot(abs(diff_r) + abs(diff_u), vec3(0.333));
    res *= (1.0 - (edge * OUTLINE_STR * clamp(1.1 - y_m, 0.0, 1.0)));

    // [4] LIGHTING & AO
    float dist = abs(y_r - y_u) * 2.0;
    float ao_mult = step(y_m, AO_SKIN_PROT);
    res -= (dist * MICRO_AO * clamp(1.0 - y_m, 0.0, 1.0)) * ao_mult;
    
    float spec = clamp((y_r - y_m) + (y_m - y_u), 0.0, 1.0);
    res += (edge * RIM_LIGHT * 0.5) + (dist * EDGE_SHINE * spec);

    // [5] COLOR & GAMMA
    res = mix(vec3(dot(res, lumaWeight)), res, VIBRANCE);
    res.rb += vec2(WARMTH, -WARMTH) * 0.05;
    
    // تصحيح الجاما هنا: GAMMA مباشرة
    res = pow(max(res, 0.0), vec3(GAMMA));

    gl_FragColor = vec4(res, 1.0);
}
#endif