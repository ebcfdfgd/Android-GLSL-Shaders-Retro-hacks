#version 110

// RetroArch Color Pop + SGPT Blend Shader (GLSL)
// Description: Isolates a specific target color, desaturates the background, and applies horizontal edge blending.

#pragma parameter COLOR_POP_HUE "Color Pop Target Hue" 0.0 0.0 360.0 1.0
#pragma parameter COLOR_POP_TOLERANCE "Color Pop Tolerance" 1.0 1.0 100.0 1.0
#pragma parameter COLOR_POP_DESAT_LEVEL "Color Pop Background Darkness" 1.0 0.0 1.0 0.01
#pragma parameter COLOR_POP_SAT_BOOST "Color Pop Boost (Keep Color)" 1.2 1.0 2.0 0.05
#pragma parameter SGPT_BLEND_LEVEL "SGPT Blend Level" 1.0 0.0 1.0 0.05

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
uniform vec2 TextureSize, InputSize;

#ifdef PARAMETER_UNIFORM
uniform float COLOR_POP_HUE;
uniform float COLOR_POP_TOLERANCE;
uniform float COLOR_POP_DESAT_LEVEL;
uniform float COLOR_POP_SAT_BOOST;
uniform float SGPT_BLEND_LEVEL;
#else
#define COLOR_POP_HUE 0.0 
#define COLOR_POP_TOLERANCE 15.0
#define COLOR_POP_DESAT_LEVEL 0.9
#define COLOR_POP_SAT_BOOST 1.2
#define SGPT_BLEND_LEVEL 1.0
#endif

const vec3 Y_LUM = vec3(0.299, 0.587, 0.114);

// Helper to calculate hue (0.0 - 1.0)
float getHue(vec3 c) {
    float minVal = min(c.r, min(c.g, c.b));
    float maxVal = max(c.r, max(c.g, c.b));
    float d = maxVal - minVal;
    if (d < 0.0001) return 0.0; // Grayscale has no hue
    float h = 0.0;
    if (c.r == maxVal) h = (c.g - c.b) / d;
    else if (c.g == maxVal) h = 2.0 + (c.b - c.r) / d;
    else h = 4.0 + (c.r - c.g) / d;
    h = h / 6.0;
    if (h < 0.0) h += 1.0;
    return h;
}

void main() {
    // [1] SGPT Horizontal Blend Preprocessing
    vec2 dx = vec2(1.0 / TextureSize.x, 0.0);

    vec3 C = texture2D(Texture, uv).rgb;
    vec3 L = texture2D(Texture, uv - dx).rgb;
    vec3 R = texture2D(Texture, uv + dx).rgb;

    vec3 diffL = C - L;
    vec3 diffR = C - R;
    
    float wL = dot(abs(diffL), Y_LUM);
    float wR = dot(abs(diffR), Y_LUM);

    vec3 blendedColor = (wR < wL) ? (C - 0.5 * SGPT_BLEND_LEVEL * diffR) 
                                : (C - 0.5 * SGPT_BLEND_LEVEL * diffL);
    
    // Clamped base color with SGPT anti-aliasing applied
    vec3 res = clamp(blendedColor, min(C, min(L, R)), max(C, max(L, R)));

    // [2] Color Pop Processing
    float targetHue = COLOR_POP_HUE / 360.0;
    float pixelHue = getHue(res);

    float dist = abs(pixelHue - targetHue);
    if (dist > 0.5) dist = 1.0 - dist;

    float normTolerance = COLOR_POP_TOLERANCE / 180.0;
    float popMask = step(normTolerance, dist); 
    popMask = 1.0 - popMask;

    float grayVal = dot(res, Y_LUM);
    vec3 grayscale = vec3(grayVal);

    vec3 boostedColor = res * COLOR_POP_SAT_BOOST;
    vec3 desatBase = mix(res, grayscale, COLOR_POP_DESAT_LEVEL);
    
    vec3 finalRes = mix(desatBase, boostedColor, popMask);

    gl_FragColor = vec4(finalRes, 1.0);
}
#endif