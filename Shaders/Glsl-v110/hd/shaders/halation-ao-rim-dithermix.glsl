#version 110

/* ULTIMATE SONIC 2026 - HALATION + ADVANCED POST-PROCESSING */
#pragma parameter halation_str      "Halation Intensity" 0.4 0.0 2.0 0.05
#pragma parameter halation_thr      "Halation Threshold" 0.6 0.0 1.0 0.05
#pragma parameter OUTLINE_STR       "Detail: Outline Power" 0.7 0.0 1.0 0.05
#pragma parameter MICRO_AO          "Depth: Micro-AO" 0.7 0.0 1.0 0.05
#pragma parameter AO_SKIN_PROT      "Depth: AO Skin Protect" 0.60 0.0 1.0 0.05
#pragma parameter RIM_LIGHT         "Light: Rim Strength" 1.5 0.0 2.0 0.05
#pragma parameter RIM_MASK_POWER    "Rim Mask Threshold" 0.8 0.0 3.0 0.1
#pragma parameter VIBRANCE          "Color: Vibrance" 1.1 -1.0 2.0 0.10
#pragma parameter de_dither         "Dither Blend (Center/Right)" 0.0 0.0 1.0 0.05

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
precision mediump float;
varying vec2 texCoord; 
uniform sampler2D Texture; 
uniform vec2 TextureSize;

#ifdef PARAMETER_UNIFORM
uniform float halation_str, halation_thr, OUTLINE_STR, MICRO_AO, AO_SKIN_PROT, RIM_LIGHT, RIM_MASK_POWER, VIBRANCE, de_dither;
#else
#define halation_str      0.4
#define halation_thr      0.6
#define OUTLINE_STR       0.7
#define MICRO_AO          0.7
#define AO_SKIN_PROT      0.60
#define RIM_LIGHT         1.5
#define RIM_MASK_POWER    0.8
#define VIBRANCE          1.1
#define de_dither         0.0
#endif

const vec3 lumaWeight = vec3(0.299, 0.587, 0.114);

void main() {
    vec2 px = 1.0 / TextureSize;
    
    // [1] EXACTLY 5 TEXTURE FETCHES (Center, Left, Right, Up, Down)
    vec3 C = texture2D(Texture, texCoord).rgb;
    vec3 L = texture2D(Texture, texCoord - vec2(px.x, 0.0)).rgb;
    vec3 R = texture2D(Texture, texCoord + vec2(px.x, 0.0)).rgb;
    vec3 U = texture2D(Texture, texCoord + vec2(0.0, px.y)).rgb;
    vec3 D = texture2D(Texture, texCoord - vec2(0.0, px.y)).rgb;
    
    // [2] BASE COLOR WITH DITHER CLEANUP (Center & Right blend)
    vec3 cleaned_c = mix(C, (C + R) * 0.5, de_dither);
    vec3 res = cleaned_c;

    // [3] HALATION CALCULATION (Using all 4 surrounding fetches)
    vec3 halo_cleaned = (L + R + U + D) * 0.25;
    float haloLuma = dot(halo_cleaned, lumaWeight);
    float haloMask = smoothstep(halation_thr - 0.1, halation_thr + 0.1, haloLuma);
    vec3 halo_color = halo_cleaned * vec3(1.3, 0.8, 0.5) * haloMask;
    res += halo_color * halation_str;

    // [4] OUTLINE & EDGE (Using all 4 directions: L, R, U, D)
    float y_m = dot(res, lumaWeight);
    vec3 diffSum = abs(res - L) + abs(res - R) + abs(res - U) + abs(res - D);
    float edge = dot(diffSum, vec3(0.333)) * 0.5;
    res *= (1.0 - (edge * OUTLINE_STR * clamp(1.1 - y_m, 0.0, 1.0)));

    // [5] LIGHTING & AO (Using 4 directions: L vs R and U vs D)
    float dist = (abs(dot(L, lumaWeight) - dot(R, lumaWeight)) + abs(dot(U, lumaWeight) - dot(D, lumaWeight)));
    float rimMask = clamp(1.0 - (y_m * RIM_MASK_POWER), 0.0, 1.0); 
    
    // AO
    res -= (dist * MICRO_AO * clamp(1.0 - y_m, 0.0, 1.0)) * step(y_m, AO_SKIN_PROT);
    
    // Rim Light
    res += (edge * RIM_LIGHT * 0.7 * rimMask);
    
    // Vibrance
    res = mix(vec3(y_m), res, VIBRANCE);
    
    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif