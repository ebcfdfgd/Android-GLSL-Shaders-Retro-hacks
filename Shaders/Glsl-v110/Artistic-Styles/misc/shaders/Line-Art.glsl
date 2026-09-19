#version 110

#pragma parameter ENABLE_MONO "Monochrome / B&W Mode (0=Off, 1=On)" 0.0 0.0 1.0 1.0
#pragma parameter COLOR_SATURATION "Color Saturation (Cartoon Pop)" 1.5 0.0 3.0 0.05
#pragma parameter LINE_THRESHOLD "Line Art Threshold" 0.15 0.0 1.0 0.01
#pragma parameter WHITE_PROTECT "White Protection Threshold" 0.80 0.5 1.0 0.01
#pragma parameter LINE_SMOOTHNESS "Line Smoothness (Vector Anti-aliasing)" 0.05 0.0 1.0 0.05
#pragma parameter EDGE_CONTRAST "Edge Contrast Multiplier" 1.0 0.5 2.0 0.1
#pragma parameter OUTLINE_STRENGTH "Outline Strength" 1.0 0.0 3.0 0.05
#pragma parameter COLOR_LEVELS "Color Reduction Levels (0 = Off)" 0.0 0.0 32.0 1.0

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
precision mediump float;
#endif

varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize;

uniform float ENABLE_MONO;
uniform float COLOR_SATURATION;
uniform float LINE_THRESHOLD;
uniform float WHITE_PROTECT;
uniform float LINE_SMOOTHNESS;
uniform float EDGE_CONTRAST;
uniform float OUTLINE_STRENGTH;
uniform float COLOR_LEVELS;

const vec3 Y = vec3(0.299, 0.587, 0.114);

void main() {
    vec2 dx = vec2(1.0 / TextureSize.x, 0.0);
    vec2 dy = vec2(0.0, 1.0 / TextureSize.y);

    // [1] Fetch center pixel
    vec3 C = texture2D(Texture, uv).rgb;

    // [2] Optional Monochrome / B&W Pass & Saturation Boost
    vec3 color;
    if (ENABLE_MONO > 0.5) {
        color = vec3(dot(C, Y));
    } else {
        float lumaVal = dot(C, Y);
        color = mix(vec3(lumaVal), C, COLOR_SATURATION);
    }

    // [3] White Protection (Evaluated on converted color to prevent RGB leaks in Mono mode)
    float maxChannel = max(color.r, max(color.g, color.b));
    if (maxChannel >= WHITE_PROTECT) {
        gl_FragColor = vec4(color, 1.0);
        return;
    }

    // [4] Fetch surrounding pixels (Delayed for early exit optimization)
    vec3 L = texture2D(Texture, uv - dx).rgb;
    vec3 R = texture2D(Texture, uv + dx).rgb;
    vec3 U = texture2D(Texture, uv - dy).rgb;
    vec3 D = texture2D(Texture, uv + dy).rgb;

    // [5] Color Reduction (Posterization)
    if (COLOR_LEVELS > 1.0) {
        color = floor(color * COLOR_LEVELS + 0.5) / COLOR_LEVELS;
    }

    // [6] Line Art Edge Detection
    float lumaL = dot(L, Y);
    float lumaR = dot(R, Y);
    float lumaU = dot(U, Y);
    float lumaD = dot(D, Y);
    
    // Edge Contrast Scaling
    float edge = (abs(lumaL - lumaR) + abs(lumaU - lumaD)) * EDGE_CONTRAST;
    
    // Vector-like Line Smoothness
    float line = smoothstep(LINE_THRESHOLD - LINE_SMOOTHNESS, LINE_THRESHOLD + LINE_SMOOTHNESS, edge);

    // Apply Outline Strength Control
    line = clamp(line * OUTLINE_STRENGTH, 0.0, 1.0);

    // [7] Final Compositing
    vec3 finalColor = mix(color, vec3(0.0), line);

    gl_FragColor = vec4(finalColor, 1.0);
}
#endif