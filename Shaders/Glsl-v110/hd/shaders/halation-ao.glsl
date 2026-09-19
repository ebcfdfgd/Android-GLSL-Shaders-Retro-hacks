#version 110

// ===== Parameters =====
#pragma parameter halation_str      "Halation Intensity"      0.4     0.0  2.0  0.05
#pragma parameter halation_thr      "Halation Threshold"      0.6     0.0  1.0  0.05
#pragma parameter fake_ao           "Fake AO Strength"        0.4     0.0  1.0  0.05
#pragma parameter ao_threshold      "AO Threshold"            0.1     0.0  1.0  0.05

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
uniform vec2 TextureSize;

#ifdef PARAMETER_UNIFORM
uniform float halation_str, halation_thr;
uniform float fake_ao;
uniform float ao_threshold;
#else
#define halation_str      0.4
#define halation_thr      0.6
#define fake_ao           0.4
#define ao_threshold      0.1
#endif

float luma(vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
}

void main() {
    vec2 px = 1.0 / TextureSize;

    // --- Exactly 5 Texture Fetches (Center, Left, Right, Up, Down) ---
    vec3 C = texture2D(Texture, uv).rgb;
    vec3 L = texture2D(Texture, uv - vec2(px.x, 0.0)).rgb;
    vec3 R = texture2D(Texture, uv + vec2(px.x, 0.0)).rgb;
    vec3 U = texture2D(Texture, uv + vec2(0.0, px.y)).rgb;
    vec3 D = texture2D(Texture, uv - vec2(0.0, px.y)).rgb;

    // --- Base Color ---
    vec3 base = C;

    // --- Halation Calculation (Uses the 4 directions: L, R, U, D) ---
    vec3 halo_cleaned = (L + R + U + D) * 0.25;
    float haloLuma = luma(halo_cleaned);
    float haloMask = smoothstep(halation_thr - 0.1, halation_thr + 0.1, haloLuma);
    vec3 halo_color = halo_cleaned * vec3(1.3, 0.8, 0.5) * haloMask;
    vec3 res = base + halo_color * halation_str;

    // --- Fake AO Calculation with Threshold ---
    float y_m = luma(res);
    float ao_dist = abs(luma(L) - luma(R)) + abs(luma(U) - luma(D));
    float ao_mask = smoothstep(ao_threshold, ao_threshold + 0.2, ao_dist);
    res -= ao_mask * fake_ao * clamp(1.0 - y_m, 0.0, 1.0);

    res = clamp(res, 0.0, 1.0);

    gl_FragColor = vec4(res, 1.0);
}
#endif