// Convergence + Halation + Film Grain - Optimized to 3 Fetches
// No Bloom
// #version 110
// license: public domain

#pragma parameter BOGUS_FILM_NOISE "-------------------CONVERG./HALATION/FILM NOISE-------------------" 0.0 0.0 0.0 0.0
#pragma parameter CONV_STR "Convergence Strength" 0.05 -1.0 1.0 0.01
#pragma parameter grain_str "Grain Strength" 0.1 0.0 2.0 0.05
#pragma parameter HALATION_STR "Halation Intensity" 0.4 0.0 2.0 0.05
#pragma parameter HALATION_THR "Halation Threshold" 0.6 0.0 1.0 0.05

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

// Convergence
uniform float CONV_STR;

// Film Grain
uniform float grain_str;

// Halation
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

    // 1. Horizontal Convergence
    vec2 conv = vec2(0.01 * CONV_STR, 0.0);

    vec2 red_coord   = uv + conv;
    vec2 green_coord = uv;
    vec2 blue_coord  = uv - conv;

    // 2. Three texture fetches
    vec3 colR = texture2D(Texture, red_coord).rgb;
    vec3 colG = texture2D(Texture, green_coord).rgb;
    vec3 colB = texture2D(Texture, blue_coord).rgb;

    // 3. Convergence / Chromatic Aberration
    vec3 film = vec3(
        colR.r,
        colG.g,
        colB.b
    );

    // 4. Fast Halation using the same three fetched samples
    vec3 halo_sample =
        (colR + colG + colB) / 3.0;

    float haloLuma = luma(halo_sample);

    float haloMask = smoothstep(
        HALATION_THR - 0.1,
        HALATION_THR + 0.1,
        haloLuma
    );

    // Warm reddish-orange / golden film halation
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