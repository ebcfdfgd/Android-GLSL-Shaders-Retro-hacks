// Bloom + Film Grain - 3 Fetches Optimized (No Chromatic Aberration)
// #version 110
// license: public domain

#pragma parameter BOGUS_FILM_NOISE "-------------------FILM NOISE/BLOOM-------------------" 0.0 0.0 0.0 0.0
#pragma parameter grain_str "Grain Strength" 0.1 0.0 2.0 0.05
#pragma parameter BLOOM_STR "Bloom Intensity" 0.3 0.0 1.0 0.05
#pragma parameter BLOOM_THR "Bloom Threshold" 0.6 0.0 1.0 0.05

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

// Uniforms
uniform float grain_str;
uniform float BLOOM_STR, BLOOM_THR;

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

    // 1. 3 Texture Fetches
    vec3 col0 = texture2D(Texture, uv).rgb;
    vec3 col1 = texture2D(Texture, uv + vec2(0.0015, 0.0015)).rgb;
    vec3 col2 = texture2D(Texture, uv - vec2(0.0015, 0.0015)).rgb;

    // 2. Clean base image
    vec3 film = col0;

    // 3. Bloom
    vec3 bloom_src = (col0 + col1 + col2) / 3.0;
    vec3 bloom_final = max(bloom_src - BLOOM_THR, 0.0) * BLOOM_STR;
    film += bloom_final;

    // 4. Film Grain
    film += filmGrain(uv, grain_str, float(FrameCount));

    gl_FragColor = vec4(film, 1.0);
}

#endif