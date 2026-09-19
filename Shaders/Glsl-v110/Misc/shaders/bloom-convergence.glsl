// Convergence and Integrated Bloom - Optimized to 3 Fetches
// #version 110
// license: public domain

#pragma parameter CONV_STR "Convergence Strength" 0.05 -1.0 1.0 0.01
#pragma parameter BLOOM_STR "Bloom Intensity" 0.3 0.0 1.0 0.05
#pragma parameter BLOOM_THR "Bloom Threshold" 0.6 0.0 1.0 0.05

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

uniform float CONV_STR;
uniform float BLOOM_STR;
uniform float BLOOM_THR;

void main() {

    // 1. Horizontal Convergence
    vec2 conv = vec2(0.01 * CONV_STR, 0.0);

    // 2. Three Texture Fetches
    vec3 colR = texture2D(Texture, uv + conv).rgb;
    vec3 colG = texture2D(Texture, uv).rgb;
    vec3 colB = texture2D(Texture, uv - conv).rgb;

    // 3. Base color
    vec3 base = vec3(
        colR.r,
        colG.g,
        colB.b
    );

    // 4. Integrated Bloom
    vec3 bloom_source =
        (colR + colG + colB) / 3.0;

    vec3 bloom_final =
        max(bloom_source - BLOOM_THR, 0.0) *
        BLOOM_STR;

    // 5. Final
    gl_FragColor =
        vec4(base + bloom_final, 1.0);
}

#endif