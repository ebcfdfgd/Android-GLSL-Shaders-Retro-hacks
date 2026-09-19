#version 110
// license: public domain

#pragma parameter BOGUS_FILM_NOISE "-------------------CONVERG./FILM NOISE/BLOOM/VIGNETTE-------------------" 0.0 0.0 0.0 0.0
#pragma parameter SGPT_BLEND_LEVEL "Blend Level" 1.0 0.0 1.0 0.05
#pragma parameter CONV_STR "Convergence Strength" 0.05 -1.0 1.0 0.01
#pragma parameter grain_str "Grain Strength" 0.1 0.0 2.0 0.05
#pragma parameter BLOOM_STR "Bloom Intensity" 0.3 0.0 1.0 0.05
#pragma parameter BLOOM_THR "Bloom Threshold" 0.6 0.0 1.0 0.05
#pragma parameter VIGNETTE_STR "Vignette Strength" 1.0 0.0 3.0 0.05

#if defined(VERTEX)

attribute vec4 VertexCoord;
attribute vec4 TexCoord;
varying vec2 uv;

uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    uv = TexCoord.xy;
}

#elif defined(FRAGMENT)

#ifdef GL_ES
precision highp float;
#endif

varying vec2 uv;
uniform sampler2D Texture;
uniform int FrameCount;

uniform vec2 TextureSize;
uniform vec2 InputSize;

// SGPT Blend
uniform float SGPT_BLEND_LEVEL;

// Convergence
uniform float CONV_STR;

// Film Grain
uniform float grain_str;

// Bloom
uniform float BLOOM_STR;
uniform float BLOOM_THR;

// Vignette
uniform float VIGNETTE_STR;

// Fixed Film Grain
float filmGrain(vec2 uv, float strength, float timer) {
    float x = (uv.x + 4.0) * (uv.y + 4.0) *
              ((mod(timer, 800.0) + 10.0) * 10.0);

    float n = fract(
        (mod(x, 13.0) + 1.0) *
        (mod(x, 123.0) + 1.0) *
        100.0
    );

    return (n - 0.5) * strength;
}

void main() {
    vec2 px = 1.0 / TextureSize;
    vec2 dx = vec2(px.x, 0.0);

    // 1. SGPT Blend Fetches (Center, Left, Right)
    vec3 C = texture2D(Texture, uv).rgb;
    vec3 L = texture2D(Texture, uv - dx).rgb;
    vec3 R = texture2D(Texture, uv + dx).rgb;

    vec3 diffL = C - L;
    vec3 diffR = C - R;
    float wL = dot(abs(diffL), vec3(0.299, 0.587, 0.114));
    float wR = dot(abs(diffR), vec3(0.299, 0.587, 0.114));

    vec3 blendedColor = (wR < wL) ? (C - 0.5 * SGPT_BLEND_LEVEL * diffR) 
                                : (C - 0.5 * SGPT_BLEND_LEVEL * diffL);
    vec3 scene = clamp(blendedColor, min(C, min(L, R)), max(C, max(L, R)));

    // 2. Horizontal Convergence
    vec2 conv = vec2(0.01 * CONV_STR, 0.0);

    // 3. Converged Texture Fetches
    vec3 colR = texture2D(Texture, uv + conv).rgb;
    vec3 colB = texture2D(Texture, uv - conv).rgb;

    vec3 film = vec3(
        colR.r,
        scene.g,
        colB.b
    );

    // 4. Bloom
    vec3 bloom_src =
        (colR + scene + colB) / 3.0;

    vec3 bloom_final =
        max(bloom_src - BLOOM_THR, 0.0) *
        BLOOM_STR;

    film += bloom_final;

    // 5. Film Grain
    film += filmGrain(
        uv,
        grain_str,
        float(FrameCount)
    );

    // 6. Vignette
    vec2 frame_scale =
        TextureSize / InputSize;

    vec2 norm_uv =
        uv * frame_scale;

    vec2 cc =
        norm_uv - 0.5;

    float dist =
        dot(cc, cc);

    float vignette =
        1.0 - dist * VIGNETTE_STR;

    film *= vignette;

    gl_FragColor =
        vec4(film, 1.0);
}

#endif