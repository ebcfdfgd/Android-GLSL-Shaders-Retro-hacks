// Convergence + Bloom + Film Grain + Vignette
// Optimized Convergence Parameters
// #version 110
// license: public domain

#pragma parameter BOGUS_FILM_NOISE "-------------------CONVERG./FILM NOISE/BLOOM/VIGNETTE-------------------" 0.0 0.0 0.0 0.0
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

    // 1. Horizontal Convergence
    vec2 conv = vec2(0.01 * CONV_STR, 0.0);

    // 2. Three Texture Fetches
    vec3 colR = texture2D(Texture, uv + conv).rgb;
    vec3 colG = texture2D(Texture, uv).rgb;
    vec3 colB = texture2D(Texture, uv - conv).rgb;

    // 3. Convergence
    vec3 film = vec3(
        colR.r,
        colG.g,
        colB.b
    );

    // 4. Bloom
    vec3 bloom_src =
        (colR + colG + colB) / 3.0;

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