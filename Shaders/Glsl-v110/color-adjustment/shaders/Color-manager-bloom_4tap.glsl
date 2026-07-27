#version 110

/* 777-CRT-ANALOG-MASTER (4-TAP HIGH QUALITY: BLOOM + HALATION)
    - 4 FETCHES TOTAL: 1 Main Pixel + 3 Surrounding Samples.
    - INCLUDES: Smooth Central Bloom & Warm Red CRT Halation.
    - OPTIMIZED: Balanced for smooth quality and fast performance.
*/

// --- BLOOM & HALATION PARAMETERS ---
#pragma parameter GLOW_STR "Central Bloom Intensity" 0.30 0.0 1.0 0.05
#pragma parameter HALATION_STR "Red Halation Intensity" 0.35 0.0 1.0 0.05
#pragma parameter BLOOM_RADIUS "Glow Spread Radius" 2.5 0.5 10.0 0.5
#pragma parameter BLOOM_THRESH "Glow Threshold" 0.45 0.0 1.0 0.05

// Global Color Parameters
#pragma parameter CLR_SAT "Saturation" 1.0 0.0 2.0 0.05
#pragma parameter CLR_CONT "Contrast" 1.0 0.0 2.0 0.05
#pragma parameter CLR_BRIGHT "Brightness" 0.0 -0.5 0.5 0.01
#pragma parameter CLR_BLK_LVL "Black Level" 0.0 -0.5 0.5 0.01
#pragma parameter CLR_GAMMA "Gamma Correction" 1.0 0.1 3.0 0.1

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
varying vec2 p_pos;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    uv = TexCoord;
    p_pos = TexCoord - 0.5;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D Texture;
uniform vec2 TextureSize;
varying vec2 uv, p_pos;

#ifdef PARAMETER_UNIFORM
uniform float GLOW_STR, HALATION_STR, BLOOM_RADIUS, BLOOM_THRESH, CLR_SAT, CLR_CONT, CLR_BRIGHT, CLR_BLK_LVL, CLR_GAMMA;
#else
#define GLOW_STR 0.30
#define HALATION_STR 0.35
#define BLOOM_RADIUS 2.5
#define BLOOM_THRESH 0.45
#define CLR_SAT 1.0
#define CLR_CONT 1.0
#define CLR_BRIGHT 0.0
#define CLR_BLK_LVL 0.0
#define CLR_GAMMA 1.0
#endif

void main() {
    vec3 lum_coeff = vec3(0.299, 0.587, 0.114);

    // 1. Fetch #1: Center Pixel
    vec3 col = texture2D(Texture, uv).rgb;

    // 2. Fetches #2, #3, #4: Triangular Surround Offsets for smooth blur
    vec2 ps = vec2(1.0 / TextureSize.x, 1.0 / TextureSize.y);
    vec2 b_off = ps * BLOOM_RADIUS;

    vec3 b1 = texture2D(Texture, uv + vec2(-b_off.x, -b_off.y)).rgb;
    vec3 b2 = texture2D(Texture, uv + vec2( b_off.x, -b_off.y)).rgb;
    vec3 b3 = texture2D(Texture, uv + vec2( 0.0,      b_off.y)).rgb;

    // Average surrounding samples
    vec3 bloom_col = (b1 + b2 + b3) * 0.3333;

    // 3. Bloom & Halation Calculations
    float r2 = dot(p_pos, p_pos);
    float b_luma = dot(bloom_col, lum_coeff);
    float factor = max(0.0, b_luma - BLOOM_THRESH);
    float radial = max(0.0, 1.0 - r2 * 3.0);

    // White/Natural Bloom
    vec3 bloom = bloom_col * GLOW_STR;

    // Warm Red-Orange Halation Tint
    vec3 halation_tint = vec3(1.2, 0.35, 0.1);
    vec3 halation = halation_tint * b_luma * HALATION_STR;

    // Combine Bloom + Halation
    col += (bloom + halation) * factor * radial;

    // 4. Color Adjustments
    col += CLR_BRIGHT;
    col = (col - 0.5) * CLR_CONT + 0.5;
    col += CLR_BLK_LVL;

    float luma_final = dot(col, lum_coeff);
    col = mix(vec3(luma_final), col, CLR_SAT);
    col = pow(clamp(col, 0.0, 1.0), vec3(CLR_GAMMA));

    gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
#endif