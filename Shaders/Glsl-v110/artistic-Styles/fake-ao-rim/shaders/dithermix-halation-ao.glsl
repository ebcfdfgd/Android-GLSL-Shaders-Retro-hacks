#version 110

// ===== Parameters =====
#pragma parameter bloom_str         "Bloom Intensity"           0.4     0.0  2.0  0.05
#pragma parameter bloom_thr         "Bloom Threshold"           0.6     0.0  1.0  0.05
#pragma parameter fake_ao           "Fake AO Strength"          0.4     0.0  1.0  0.05
#pragma parameter ao_threshold      "AO Threshold"              0.1     0.0  1.0  0.05
#pragma parameter de_dither         "Dither Blend"              0.0     0.0  1.0  0.05
#pragma parameter SAMPLE_RADIUS     "Bloom Sample Radius"       1.0     0.1  10.0 0.1

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
uniform float bloom_str, bloom_thr;
uniform float fake_ao;
uniform float ao_threshold;
uniform float de_dither;
uniform float SAMPLE_RADIUS;
#else
#define bloom_str           0.4
#define bloom_thr           0.6
#define fake_ao             0.4
#define ao_threshold        0.1
#define de_dither           0.0
#define SAMPLE_RADIUS       1.0
#endif

float luma(vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
}

void main() {
    vec2 base_px = 1.0 / TextureSize;
    vec2 bloom_px = base_px * SAMPLE_RADIUS;

    // --- Center Fetch ---
    vec3 C = texture2D(Texture, uv).rgb;

    // --- 1. Mix / Dither System (2 Fetches: Left and Right - Fixed 1-pixel) ---
    vec3 mix_L = texture2D(Texture, uv - vec2(base_px.x, 0.0)).rgb;
    vec3 mix_R = texture2D(Texture, uv + vec2(base_px.x, 0.0)).rgb;
    vec3 cleaned_c = mix(C, (mix_L + mix_R) * 0.5, de_dither);
    vec3 base = cleaned_c;

    // --- 2. Bloom System (2 Fetches: Left and Right - Controlled by SAMPLE_RADIUS) ---
    vec3 bloom_L = texture2D(Texture, uv - vec2(bloom_px.x, 0.0)).rgb;
    vec3 bloom_R = texture2D(Texture, uv + vec2(bloom_px.x, 0.0)).rgb;
    vec3 bloom_src = (bloom_L + bloom_R) * 0.5;
    vec3 bloom_final = max(bloom_src - bloom_thr, 0.0) * bloom_str;
    vec3 res = base + bloom_final;

    // --- 3. Fake AO System (2 Fetches: Up and Right - Fixed 1-pixel) ---
    vec3 ao_U = texture2D(Texture, uv + vec2(0.0, base_px.y)).rgb;
    vec3 ao_R = texture2D(Texture, uv + vec2(base_px.x, 0.0)).rgb;
    float y_m = luma(res);
    float ao_dist = abs(luma(C) - luma(ao_U)) + abs(luma(C) - luma(ao_R));
    float ao_mask = smoothstep(ao_threshold, ao_threshold + 0.2, ao_dist);
    res -= ao_mask * fake_ao * clamp(1.0 - y_m, 0.0, 1.0);

    res = clamp(res, 0.0, 1.0);

    gl_FragColor = vec4(res, 1.0);
}
#endif