// Film Grain + Fast Halation - 3 Fetches Optimized
// No Chromatic Aberration / No Bloom
// #version 110
// license: public domain

#pragma parameter BOGUS_FILM_NOISE "-------------------FILM NOISE/HALATION-------------------" 0.0 0.0 0.0 0.0
#pragma parameter grain_str "Grain Strength" 0.1 0.0 2.0 0.05
#pragma parameter HALATION_STR "Halation Intensity" 0.4 0.0 2.0 0.05
#pragma parameter HALATION_THR "Halation Threshold" 0.6 0.0 1.0 0.05

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

varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform int FrameCount;

uniform float grain_str;
uniform float HALATION_STR;
uniform float HALATION_THR;

float luma(vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
}

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

    // 1. Base image
    vec3 col0 = texture2D(Texture, uv).rgb;

    // 2. Nearby samples for halation
    vec2 px = 1.0 / TextureSize;

    vec3 col1 = texture2D(Texture, uv + px).rgb;
    vec3 col2 = texture2D(Texture, uv - px).rgb;

    // 3. Clean base image
    vec3 film = col0;

    // 4. Fast Halation
    vec3 halo_sample = (col1 + col2) * 0.5;

    float haloLuma = luma(halo_sample);

    float haloMask = smoothstep(
        HALATION_THR - 0.1,
        HALATION_THR + 0.1,
        haloLuma
    );

    // Warm reddish-orange film halation
    vec3 halo_color =
        halo_sample *
        vec3(1.3, 0.8, 0.5) *
        haloMask;

    film += halo_color * HALATION_STR;

    // 5. Film Grain
    film += filmGrain(
        uv,
        grain_str,
        float(FrameCount)
    );

    gl_FragColor = vec4(film, 1.0);
}

#endif