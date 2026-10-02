#version 110

#pragma parameter TEXTURE_TAPS "1. Texture Fetches" 0.0 0.0 100.0 1.0
#pragma parameter ITER_POLY "2. Poly Loops" 0.0 0.0 100.0 1.0
#pragma parameter ITER_POW "3. Pow Loops" 0.0 0.0 100.0 1.0
#pragma parameter ITER_SIN "4. Sin Loops" 0.0 0.0 100.0 1.0
#pragma parameter ITER_EXP "5. Exp Loops" 0.0 0.0 100.0 1.0
#pragma parameter ITER_EXP2 "6. Exp2 Loops" 0.0 0.0 100.0 1.0
#pragma parameter ITER_MCOL "7. Mcol Loops" 0.0 0.0 100.0 1.0
#pragma parameter ITER_SMOOTH "8. Smoothstep Loops" 0.0 0.0 100.0 1.0

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

#ifdef PARAMETER_UNIFORM
uniform float TEXTURE_TAPS;
uniform float ITER_POLY;
uniform float ITER_POW;
uniform float ITER_SIN;
uniform float ITER_EXP;
uniform float ITER_EXP2;
uniform float ITER_MCOL;
uniform float ITER_SMOOTH;
#else
#define TEXTURE_TAPS 0.0
#define ITER_POLY 0.0
#define ITER_POW 0.0
#define ITER_SIN 0.0
#define ITER_EXP 0.0
#define ITER_EXP2 0.0
#define ITER_MCOL 0.0
#define ITER_SMOOTH 0.0
#endif

void main() {
    vec3 res = texture2D(Texture, uv).rgb;
    float luma = dot(res, vec3(0.299, 0.587, 0.114));

    // 1. Texture Fetches (Memory Pressure)
    if (TEXTURE_TAPS > 0.5) {
        vec3 acc = vec3(0.0);
        for(int i = 0; i < 100; i++) {
            if (float(i) >= TEXTURE_TAPS) break;
            float seed = float(i) * 12.9898 + dot(uv, vec2(78.233, 151.718));
            vec2 offset = vec2(sin(seed), cos(seed)) * 0.01;
            acc += texture2D(Texture, uv + offset).rgb;
        }
        res = acc / TEXTURE_TAPS;
    }

    // 2. Poly Loops
    for(int i = 0; i < 100; i++) {
        if (float(i) >= ITER_POLY) break;
        res = res * (1.92 - 0.92 * res) + 0.001;
    }

    // 3. Pow Loops
    for(int i = 0; i < 100; i++) {
        if (float(i) >= ITER_POW) break;
        res = pow(res, vec3(2.2)) + 0.001;
    }

    // 4. Sin Loops
    for(int i = 0; i < 100; i++) {
        if (float(i) >= ITER_SIN) break;
        res = sin(res * 1.57) + 0.001;
    }

    // 5. Exp Loops
    for(int i = 0; i < 100; i++) {
        if (float(i) >= ITER_EXP) break;
        res = exp(res * 0.5) * 0.99;
    }

    // 6. Exp2 Loops
    for(int i = 0; i < 100; i++) {
        if (float(i) >= ITER_EXP2) break;
        res = exp2(res * 0.5) * 0.99;
    }

    // 7. Mcol Loops
    for(int i = 0; i < 100; i++) {
        if (float(i) >= ITER_MCOL) break;
        res *= vec3(0.99, 0.98, 0.99); // Gradual color shift
    }

    // 8. Smoothstep Loops
    for(int i = 0; i < 100; i++) {
        if (float(i) >= ITER_SMOOTH) break;
        res = smoothstep(vec3(0.0), vec3(1.0), res);
    }

    gl_FragColor = vec4(res, 1.0);
}
#endif