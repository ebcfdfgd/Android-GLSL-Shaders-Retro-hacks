// Bloom + Film Grain - 4 Directions (No Chromatic Aberration)
// #version 110
// license: public domain

#pragma parameter grain_str "Grain Strength" 0.1 0.0 2.0 0.05
#pragma parameter BLOOM_STR "Bloom Intensity" 0.3 0.0 1.0 0.05
#pragma parameter BLOOM_THR "Bloom Threshold" 0.6 0.0 1.0 0.05
#pragma parameter SAMPLE_RADIUS "Sample Radius" 1.0 0.1 10.0 0.1

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

// Uniforms
uniform float grain_str;
uniform float BLOOM_STR, BLOOM_THR;
uniform float SAMPLE_RADIUS;

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

    // 1. 4-Direction Texture Fetches (Center, Right, Left, Up, Down)
    vec2 px = (1.0 / TextureSize) * SAMPLE_RADIUS;
    
    vec3 col0 = texture2D(Texture, uv).rgb;                                // Center
    vec3 col1 = texture2D(Texture, uv + vec2(px.x, 0.0)).rgb; // Right
    vec3 col2 = texture2D(Texture, uv - vec2(px.x, 0.0)).rgb; // Left
    vec3 col3 = texture2D(Texture, uv + vec2(0.0, px.y)).rgb; // Up
    vec3 col4 = texture2D(Texture, uv - vec2(0.0, px.y)).rgb; // Down

    // 2. Clean base image
    vec3 film = col0;

    // 3. Bloom (Average of 4 surrounding directions)
    vec3 bloom_src = (col1 + col2 + col3 + col4) * 0.25;
    vec3 bloom_final = max(bloom_src - BLOOM_THR, 0.0) * BLOOM_STR;
    film += bloom_final;

    // 4. Film Grain
    film += filmGrain(uv, grain_str, float(FrameCount));

    gl_FragColor = vec4(film, 1.0);
}

#endif