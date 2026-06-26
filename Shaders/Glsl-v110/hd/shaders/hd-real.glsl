#version 110

/* 777-ULTIMATE SONIC 2026 - REALISTIC PBR-LIGHTING PASS (SAMPLER OPTIMIZED)
    - OPTIMIZED: Eliminated redundant 4th texture lookup by recycling col_r for dither calculations.
    - PERFORMANCE: Reduced bandwidth footprint down to 3 unique texture taps per pixel.
*/

#pragma parameter C_BLK_LVL "Black Level" 0.0 -0.2 0.2 0.01
#pragma parameter C_WHT_LVL "White Level" 1.0 0.0 1.0 0.01
#pragma parameter dither_str "Dither Removal Strength" 1.0 0.0 2.0 0.05
#pragma parameter OUTLINE_STR "Detail: Micro-Cavity Power" 0.35 0.0 2.0 0.05
#pragma parameter MICRO_AO "Depth: Ambient Occlusion" 0.5 0.0 2.0 0.05
#pragma parameter AO_SKIN_PROT "Depth: AO Soft Threshold" 0.70 0.0 1.0 0.05
#pragma parameter RIM_LIGHT "Light: Rim Softness" 0.85 0.0 4.0 0.05
#pragma parameter RIM_MASK_POWER "Rim Mask Threshold" 1.2 0.0 3.0 0.1
#pragma parameter SPEC_STR "Light: Specular Intensity" 0.4 0.0 2.0 0.05
#pragma parameter DIR_BIAS "Light: Dir Bias" 0.1 -1.0 1.0 0.05
#pragma parameter LUMA_ADAPT "Engine: Luma Adaptation" 0.15 0.0 0.5 0.05
#pragma parameter HIGH_COMP "Engine: Highlight Comp" 0.2 0.0 1.0 0.05
#pragma parameter VIBRANCE "Color: Vibrance" 1.0 -1.0 2.0 0.10
#pragma parameter WARMTH "Color: Warmth" 0.0 -0.50 0.50 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord; attribute vec4 TexCoord; varying vec2 texCoord; uniform mat4 MVPMatrix;
void main() { gl_Position = MVPMatrix * VertexCoord; texCoord = TexCoord.xy; }

#elif defined(FRAGMENT)
#ifdef GL_ES
precision mediump float;
#endif

varying vec2 texCoord; uniform sampler2D Texture; uniform vec2 TextureSize;
uniform float C_BLK_LVL, C_WHT_LVL, dither_str, OUTLINE_STR, MICRO_AO, AO_SKIN_PROT, RIM_LIGHT, RIM_MASK_POWER, SPEC_STR, DIR_BIAS, VIBRANCE, WARMTH, HIGH_COMP, LUMA_ADAPT;

const vec3 lumaWeight = vec3(0.299, 0.587, 0.114);
const vec3 LIGHT_COLOR = vec3(1.0, 0.98, 0.95);

void main() {
    vec2 px = 1.0 / TextureSize;
    
    // [1] FETCH ALL UNIQUE SAMPLES FIRST (3 Lookups total)
    vec3 center = texture2D(Texture, texCoord).rgb;
    vec3 col_r  = texture2D(Texture, texCoord + vec2(px.x, 0.0)).rgb;
    vec3 col_u  = texture2D(Texture, texCoord + vec2(0.0, px.y)).rgb;
    
    // [2] TWO-TAP DITHER REMOVAL (Reusing col_r directly)
    vec3 res = mix(center, (center + col_r) * 0.5, dither_str);

    // [3] LUMINANCE & GRADIENTS
    float y_m = dot(res, lumaWeight);
    float y_r = dot(col_r, lumaWeight);
    float y_u = dot(col_u, lumaWeight);

    // [4] REALISTIC MICRO-CAVITY
    float edge = (abs(y_m - y_r) + abs(y_m - y_u)) * 0.5;
    float cavityMask = clamp(1.0 - y_m, 0.1, 1.0);
    res *= (1.0 - (edge * OUTLINE_STR * cavityMask));

    // [5] NATURAL AMBIENT OCCLUSION
    float dist = abs(y_r - y_u) * 2.0;
    float aoFactor = dist * MICRO_AO * clamp(AO_SKIN_PROT - y_m, 0.0, 1.0);
    res *= (1.0 - aoFactor);
    
    // [6] FRESNEL-BASED RIM LIGHTING
    float rimMask = clamp(1.0 - (y_m * RIM_MASK_POWER), 0.0, 1.0); 
    float realisticRim = edge * RIM_LIGHT * rimMask;
    res += (realisticRim * LIGHT_COLOR * res);
    
    // [7] PHYSIO-SPECULAR HIGHLIGHTS
    float specBase = y_m * y_m;
    float spec = specBase * specBase * SPEC_STR;
    res += (spec * LIGHT_COLOR * (1.0 + DIR_BIAS));

    // [8] ENGINE ADAPTATION & TONEMAPPING
    res = mix(res, res + (1.0 - y_m) * LUMA_ADAPT, HIGH_COMP);

    // [9] FINAL COLOR CORRECTION
    res = max(vec3(0.0), res - C_BLK_LVL); 
    res = res * (1.0 / max(0.001, C_WHT_LVL));
    res = mix(vec3(dot(res, lumaWeight)), res, VIBRANCE);
    res.rb += vec2(WARMTH, -WARMTH) * 0.04;
    
    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif