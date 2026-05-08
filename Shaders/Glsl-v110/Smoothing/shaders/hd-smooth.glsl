#version 110

/* ULTIMATE SONIC 2026 - HD VECTOR-SMOOTH EDITION
    - Feature: HD Sub-pixel Interpolation with Sharp Contrast.
    - Light: Optimized Rim & Specular on Smooth Edges.
    - Performance: Smart Bypass for battery saving.
*/

#pragma parameter HD_SMOOTH "HD: Edge Smoothness" 0.60 0.0 1.0 0.05
#pragma parameter SHARP_CONTR "HD: Sharp Contrast" 1.50 1.0 3.0 0.10
#pragma parameter CHROMA_STR "Chroma: Strength" 0.12 0.0 0.50 0.02
#pragma parameter LENS_DIST "Chroma: Lens Distortion" 0.10 0.0 0.50 0.02
#pragma parameter NTSC_STR "Dither: Smart Eraser" 0.65 0.0 1.0 0.05
#pragma parameter EDGE_SHINE "Light: Edge Specular" 0.45 0.0 1.0 0.05
#pragma parameter OUTLINE_STR "Detail: Outline Power" 0.20 0.0 1.0 0.05
#pragma parameter MICRO_AO "Depth: Micro-AO" 0.35 0.0 1.0 0.05
#pragma parameter AO_SKIN_PROT "Depth: AO Skin Protect" 0.60 0.0 1.0 0.05
#pragma parameter RIM_LIGHT "Light: Rim Strength" 0.65 0.0 2.0 0.05
#pragma parameter BLOOM_GLOW "Light: Bloom" 0.35 0.0 1.0 0.05
#pragma parameter VIBRANCE "Color: Vibrance" 1.40 1.0 2.0 0.10
#pragma parameter WARMTH "Color: Warmth" 0.0 -0.50 0.50 0.05
#pragma parameter BLACK_DEPTH "Color: Black Depth" 0.01 -0.10 0.20 0.01

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
uniform float HD_SMOOTH, SHARP_CONTR, CHROMA_STR, LENS_DIST, NTSC_STR, EDGE_SHINE, OUTLINE_STR, MICRO_AO, AO_SKIN_PROT, RIM_LIGHT, BLOOM_GLOW, VIBRANCE, WARMTH, BLACK_DEPTH;
#endif

const vec3 lumaWeight = vec3(0.299, 0.587, 0.114);

void main() {
    // [0] FAST FETCH & SMART BYPASS
    vec3 col_m = texture2D(Texture, texCoord).rgb;

    if (HD_SMOOTH <= 0.0 && CHROMA_STR <= 0.0 && NTSC_STR <= 0.0 && EDGE_SHINE <= 0.0 && MICRO_AO <= 0.0 && BLOOM_GLOW <= 0.0) {
        vec3 quick_res = mix(vec3(dot(col_m, lumaWeight)), col_m, VIBRANCE);
        quick_res.rb += vec2(WARMTH, -WARMTH) * 0.05;
        gl_FragColor = vec4(max(quick_res - BLACK_DEPTH, 0.0), 1.0);
        return; 
    }

    vec2 px = 1.0 / TextureSize;
    
    // [1] HD VECTOR SMOOTHING WITH SHARP CONTRAST
    vec2 f = fract(texCoord * TextureSize);
    vec3 col_l = texture2D(Texture, texCoord - vec2(px.x, 0.0)).rgb;
    vec3 col_r = texture2D(Texture, texCoord + vec2(px.x, 0.0)).rgb;
    vec3 col_u = texture2D(Texture, texCoord + vec2(0.0, px.y)).rgb;
    vec3 col_d = texture2D(Texture, texCoord - vec2(0.0, px.y)).rgb;

    // تطبيق الـ Sharp Contrast على الـ Interpolation
    // هذه العملية تزيد من حدة الانتقال اللوني عند الحواف المنعمة
    vec2 blend = smoothstep(0.5 - HD_SMOOTH * 0.5, 0.5 + HD_SMOOTH * 0.5, f);
    blend = pow(blend, vec2(SHARP_CONTR)); // تقوية التباين في منطقة الدمج
    
    vec3 res_h = mix(col_l, col_r, blend.x);
    vec3 res_v = mix(col_d, col_u, blend.y);
    vec3 res = mix(col_m, (res_h + res_v) * 0.5, HD_SMOOTH);

    // [2] SMART DITHER
    float y_m = dot(res, lumaWeight);
    float y_l = dot(col_l, lumaWeight);
    float y_r = dot(col_r, lumaWeight);

    float pattern = abs(y_m - y_l) * abs(y_m - y_r);
    float d_mask = clamp(pattern * 50.0, 0.0, 1.0) * clamp(1.0 - abs(y_l - y_r) * 5.0, 0.0, 1.0);
    res = mix(res, (col_l + res + col_r) * 0.3333, NTSC_STR * d_mask);

    // [3] FAST CHROMA
    vec2 lensShift = (texCoord - 0.5) * LENS_DIST * 0.1 * CHROMA_STR;
    res.r = mix(res.r, texture2D(Texture, texCoord - lensShift).r, step(0.001, CHROMA_STR));
    res.b = mix(res.b, texture2D(Texture, texCoord + lensShift).b, step(0.001, CHROMA_STR));

    // [4] OUTLINE & HD EDGE CALC
    vec3 diff_r = res - col_r;
    vec3 diff_u = res - col_u;
    float edge = dot(abs(diff_r) + abs(diff_u), vec3(0.333));
    res *= (1.0 - (edge * OUTLINE_STR * clamp(1.1 - y_m, 0.0, 1.0)));

    // [5] LIGHTING & AO
    float dist = abs(dot(col_r, lumaWeight) - dot(col_u, lumaWeight)) * 2.0;
    float ao_mult = step(y_m, AO_SKIN_PROT);
    res -= (dist * MICRO_AO * clamp(1.0 - y_m, 0.0, 1.0)) * ao_mult;
    
    float spec = clamp((y_r - y_m) + (y_m - dot(col_u, lumaWeight)), 0.0, 1.0);
    res += (edge * RIM_LIGHT * 0.7) + (dist * EDGE_SHINE * spec);

    // [6] COLOR & POST-PROCESS
    res = mix(res, col_r, BLOOM_GLOW * 0.2);
    res = mix(vec3(dot(res, lumaWeight)), res, VIBRANCE);
    res.rb += vec2(WARMTH, -WARMTH) * 0.05;

    // [7] FINAL OUTPUT
    res = max(res - BLACK_DEPTH, 0.0);
    gl_FragColor = vec4(res, 1.0);
}
#endif