#version 110

/* 777-CRT-ANALOG-MASTER (RAW SIGNAL + 4-SIDE HALATION)
    - UPDATED: Halation samples 4 sides (Up, Down, Left, Right) for smoother coverage.
    - INTEGRATED: Fast Film/CRT Halation with smoothstep thresholding.
*/

// --- HALATION PARAMETERS ---
#pragma parameter HALATION_STR "Halation Intensity" 0.4 0.0 2.0 0.05
#pragma parameter HALATION_THR "Halation Threshold" 0.6 0.0 1.0 0.05

// Color Adjustment Parameters (Global Signal Only)
#pragma parameter CLR_SAT "Saturation" 1.0 0.0 2.0 0.05
#pragma parameter CLR_CONT "Contrast" 1.0 0.0 2.0 0.05
#pragma parameter CLR_BRIGHT "Brightness" 0.0 -0.5 0.5 0.01
#pragma parameter CLR_BLK_LVL "Black Level" 0.0 -0.5 0.5 0.01
#pragma parameter CLR_GAMMA "Gamma Correction" 1.0 0.1 3.0 0.1

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    uv = TexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D Texture;
uniform vec2 TextureSize;
varying vec2 uv;

#ifdef PARAMETER_UNIFORM
uniform float HALATION_STR, HALATION_THR, CLR_SAT, CLR_CONT, CLR_BRIGHT, CLR_BLK_LVL, CLR_GAMMA;
#else
#define HALATION_STR 0.4
#define HALATION_THR 0.6
#define CLR_SAT 1.0
#define CLR_CONT 1.0
#define CLR_BRIGHT 0.0
#define CLR_BLK_LVL 0.0
#define CLR_GAMMA 1.0
#endif

float luma(vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
}

void main() {
    vec2 px = 1.0 / TextureSize;
    vec3 base = texture2D(Texture, uv).rgb;

    // 1. Halation Calculation using 4-side nearby samples (Right, Left, Up, Down)
    vec3 h_right = texture2D(Texture, uv + vec2(px.x, 0.0)).rgb;
    vec3 h_left  = texture2D(Texture, uv - vec2(px.x, 0.0)).rgb;
    vec3 h_top   = texture2D(Texture, uv + vec2(0.0, px.y)).rgb;
    vec3 h_bot   = texture2D(Texture, uv - vec2(0.0, px.y)).rgb;

    vec3 halo_sample = (h_right + h_left + h_top + h_bot) * 0.25;

    // 2. Threshold and masking based on luminance
    float haloLuma = luma(halo_sample);
    float haloMask = smoothstep(HALATION_THR - 0.1, HALATION_THR + 0.1, haloLuma);

    // 3. Apply warm reddish-orange/golden tint
    vec3 halo_color = halo_sample * vec3(1.3, 0.8, 0.5) * haloMask;
    vec3 col = base + halo_color * HALATION_STR;

    // 4. Color Adjustments
    col += CLR_BRIGHT;
    col = (col - 0.5) * CLR_CONT + 0.5;
    col += CLR_BLK_LVL;

    // 5. Saturation
    float luma_final = luma(col);
    col = mix(vec3(luma_final), col, CLR_SAT);

    // 6. Gamma Correction
    col = pow(clamp(col, 0.0, 1.0), vec3(CLR_GAMMA));

    // 7. Output
    gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
#endif