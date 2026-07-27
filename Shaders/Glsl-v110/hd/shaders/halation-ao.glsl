#version 110

// ===== Parameters =====
#pragma parameter halation_str      "Halation Intensity"    0.4   0.0  2.0  0.05
#pragma parameter halation_thr      "Halation Threshold"    0.6   0.0  1.0  0.05
#pragma parameter fake_ao           "Fake AO Strength"      0.4   0.0  1.0  0.05

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
#else
#define halation_str      0.4
#define halation_thr      0.6
#define fake_ao           0.4
#endif

float luma(vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
}

void main() {
    vec2 px = 1.0 / TextureSize;

    // --- Texture Fetches ---
    vec3 C = texture2D(Texture, uv).rgb;
    vec3 L = texture2D(Texture, uv - vec2(px.x, 0.0)).rgb;
    vec3 R = texture2D(Texture, uv + vec2(px.x, 0.0)).rgb;
    vec3 colHalo = texture2D(Texture, uv + px).rgb;
    vec3 colU_ao = texture2D(Texture, uv + vec2(0.0, px.y)).rgb;

    // --- Base Color (Dither Cleanup bypassed) ---
    vec3 cleaned_c = C;

    // --- Merge Dither with Halation ---
    vec3 halo_cleaned = colHalo;

    // --- Base Color ---
    vec3 base = cleaned_c;

    // --- Halation Calculation ---
    float haloLuma = luma(halo_cleaned);
    float haloMask = smoothstep(halation_thr - 0.1, halation_thr + 0.1, haloLuma);
    vec3 halo_color = halo_cleaned * vec3(1.3, 0.8, 0.5) * haloMask;
    vec3 res = base + halo_color * halation_str;

    // --- Fake AO (Ambient Occlusion) Calculation ---
    float y_m = luma(res);
    float ao_dist = abs(luma(R) - luma(colU_ao)) * 2.0;
    res -= ao_dist * fake_ao * clamp(1.0 - y_m, 0.0, 1.0);

    res = clamp(res, 0.0, 1.0);

    gl_FragColor = vec4(res, 1.0);
}
#endif