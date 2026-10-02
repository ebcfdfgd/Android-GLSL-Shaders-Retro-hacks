#version 110

// ===== Parameters =====
#pragma parameter bloom_str         "Bloom Intensity"           0.4     0.0  2.0  0.05
#pragma parameter bloom_thr         "Bloom Threshold"           0.6     0.0  1.0  0.05
#pragma parameter bloom_radius      "Bloom Radius"              1.0     0.5  5.0  0.25
#pragma parameter fake_ao           "Fake AO Strength"          0.4     0.0  1.0  0.05
#pragma parameter ao_threshold      "AO Threshold"              0.1     0.0  1.0  0.05

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
uniform float bloom_str, bloom_thr, bloom_radius;
uniform float fake_ao;
uniform float ao_threshold;
#else
#define bloom_str           0.4
#define bloom_thr           0.6
#define bloom_radius        1.0
#define fake_ao             0.4
#define ao_threshold        0.1
#endif

float luma(vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
}

void main() {
    vec2 px = 1.0 / TextureSize;
    vec2 halo_px = px * bloom_radius;

    // --- Center Fetch ---
    vec3 C = texture2D(Texture, uv).rgb;

    // --- Up / Down Fetches (Shared for AO and Bloom) ---
    vec3 ao_U = texture2D(Texture, uv + vec2(0.0, px.y)).rgb;
    vec3 ao_D = texture2D(Texture, uv - vec2(0.0, px.y)).rgb;

    // --- Left / Right Fetches for AO (Fixed 1-pixel) ---
    vec3 ao_L = texture2D(Texture, uv - vec2(px.x, 0.0)).rgb;
    vec3 ao_R = texture2D(Texture, uv + vec2(px.x, 0.0)).rgb;

    // --- Left / Right Fetches for Bloom (Using Bloom Radius) ---
    vec3 bloom_L = texture2D(Texture, uv - vec2(halo_px.x, 0.0)).rgb;
    vec3 bloom_R = texture2D(Texture, uv + vec2(halo_px.x, 0.0)).rgb;

    // --- Bloom Calculation (L/R with radius + shared Up/Down) ---
    vec3 bloom_src = (bloom_L + bloom_R + ao_U + ao_D) * 0.25;
    vec3 bloom_final = max(bloom_src - bloom_thr, 0.0) * bloom_str;
    vec3 res = C + bloom_final;

    // --- Fake AO Calculation (4 Directions: Up, Down, Left, Right) ---
    float y_m = luma(res);
    float ao_dist = abs(luma(C) - luma(ao_U)) + 
                    abs(luma(C) - luma(ao_D)) + 
                    abs(luma(C) - luma(ao_L)) + 
                    abs(luma(C) - luma(ao_R));
    float ao_mask = smoothstep(ao_threshold, ao_threshold + 0.2, ao_dist * 0.5);
    res -= ao_mask * fake_ao * clamp(1.0 - y_m, 0.0, 1.0);

    res = clamp(res, 0.0, 1.0);

    gl_FragColor = vec4(res, 1.0);
}
#endif