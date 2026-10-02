#version 110

// ===== Parameters =====
#pragma parameter convergence       "Convergence Strength"  0.004  0.0  0.02  0.001
#pragma parameter halation_str      "Halation Intensity"    0.4   0.0  2.0  0.05
#pragma parameter halation_thr      "Halation Threshold"    0.6   0.0  1.0  0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
uniform mat4 MVPMatrix;

void main() {
    uv = TexCoord;
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;

#ifdef PARAMETER_UNIFORM
uniform float convergence;
uniform float halation_str, halation_thr;
#else
#define convergence       0.02
#define halation_str      0.4
#define halation_thr      0.6
#endif

float luma(vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
}

void main() {
    vec2 px = 1.0 / TextureSize;

    // --- Convergence (RGB Channel Separation) ---
    vec2 red_coord   = uv + vec2(convergence, 0.0);
    vec2 green_coord = uv;
    vec2 blue_coord  = uv - vec2(convergence, 0.0);

    // --- Texture Fetches ---
    vec3 colR    = texture2D(Texture, red_coord).rgb;
    vec3 colG    = texture2D(Texture, green_coord).rgb;
    vec3 colB    = texture2D(Texture, blue_coord).rgb;
    vec3 colHalo = texture2D(Texture, uv + px).rgb;

    // --- Base Color Assembly ---
    vec3 base = vec3(colR.r, colG.g, colB.b);

    // --- Halation Calculation ---
    float haloLuma = luma(colHalo);
    float haloMask = smoothstep(halation_thr - 0.1, halation_thr + 0.1, haloLuma);
    vec3 halo_color = colHalo * vec3(1.3, 0.8, 0.5) * haloMask;
    vec3 res = base + halo_color * halation_str;

    res = clamp(res, 0.0, 1.0);

    gl_FragColor = vec4(res, 1.0);
}
#endif