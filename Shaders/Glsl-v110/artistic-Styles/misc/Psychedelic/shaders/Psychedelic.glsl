#version 110

/* 
    PSYCHEDELIC SHADER (STANDARD)
    - Effect: Pop Art Studio Psychedelic Wave / Inversion Filter
    - Detail Preservation: keeps the original brightness so game details survive
*/

#pragma parameter PSY_AMOUNT "Amount" 100.0 0.0 100.0 1.0
#pragma parameter PSY_FREQ "Frequency" 3.0 0.5 30.0 0.5
#pragma parameter PSY_DETAIL "Detail Preservation" 1.0 0.0 1.0 0.05

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

uniform sampler2D Texture;
varying vec2 uv;

#ifdef PARAMETER_UNIFORM
uniform float PSY_AMOUNT;
uniform float PSY_FREQ;
uniform float PSY_DETAIL;
#else
#define PSY_AMOUNT 100.0
#define PSY_FREQ 3.0
#define PSY_DETAIL 1.0
#endif

const vec3 Y = vec3(0.299, 0.587, 0.114);

void main() {
    // 1. Read Original Pixel Color
    vec3 col = texture2D(Texture, uv).rgb;

    // 2. Psychedelic Color Wave (Trigonometric Inversion)
    float amt = PSY_AMOUNT / 100.0;
    vec3 psy = 0.5 + 0.5 * sin((vec3(1.0) - col) * PSY_FREQ * 3.14159265);

    // 3. Detail Preservation: keep ORIGINAL brightness, take only new colors
    float lumOrig = dot(col, Y);
    float lumPsy  = dot(psy, Y);
    vec3 psyKeep  = clamp(psy + (lumOrig - lumPsy), 0.0, 1.0);
    psy = mix(psy, psyKeep, PSY_DETAIL);

    // 4. Blend Original Color with Psychedelic Effect
    vec3 final_col = mix(col, psy, amt);

    // 5. Output Final Color
    gl_FragColor = vec4(clamp(final_col, 0.0, 1.0), 1.0);
}
#endif
