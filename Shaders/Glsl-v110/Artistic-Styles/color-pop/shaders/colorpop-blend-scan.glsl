#version 110

// RetroArch Color Pop + SGPT Blend + Scanlines (GLSL)
// Description: Isolates a specific target color, desaturates the background,
// applies horizontal edge blending, and adds configurable scanlines.

#pragma parameter COLOR_POP_HUE "Color Pop Target Hue" 0.0 0.0 360.0 1.0
#pragma parameter COLOR_POP_TOLERANCE "Color Pop Tolerance" 1.0 1.0 100.0 1.0
#pragma parameter COLOR_POP_DESAT_LEVEL "Color Pop Background Darkness" 1.0 0.0 1.0 0.01
#pragma parameter COLOR_POP_SAT_BOOST "Color Pop Boost (Keep Color)" 1.2 1.0 2.0 0.05

#pragma parameter SGPT_BLEND_LEVEL "SGPT Blend Level" 1.0 0.0 1.0 0.05

// ===== Scanlines =====
#pragma parameter scanline_amount "Scanline Amount" 0.12 0.0 0.5 0.02
#pragma parameter scanline_scale "Scanline Density" 1.0 1.0 4.0 0.5

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

uniform float scanline_amount;
uniform float scanline_scale;

#else

#define COLOR_POP_HUE             0.0
#define COLOR_POP_TOLERANCE      15.0
#define COLOR_POP_DESAT_LEVEL     0.9
#define COLOR_POP_SAT_BOOST       1.2

#define SGPT_BLEND_LEVEL           1.0

#define scanline_amount            0.12
#define scanline_scale             2.0

#endif

const vec3 Y_LUM =
    vec3(0.299, 0.587, 0.114);

// ============================================================
// Hue
// ============================================================
float getHue(vec3 c)
{
    float minVal =
        min(c.r, min(c.g, c.b));

    float maxVal =
        max(c.r, max(c.g, c.b));

    float d =
        maxVal - minVal;

    if (d < 0.0001)
        return 0.0;

    float h = 0.0;

    if (c.r == maxVal)
        h = (c.g - c.b) / d;
    else if (c.g == maxVal)
        h = 2.0 + (c.b - c.r) / d;
    else
        h = 4.0 + (c.r - c.g) / d;

    h /= 6.0;

    if (h < 0.0)
        h += 1.0;

    return h;
}

// ============================================================
// Scanline
// No texture fetch
// ============================================================
float scanlinePattern(vec2 fragCoord, float scale)
{
    float line =
        sin(
            fragCoord.y / scale *
            3.14159
        );

    return line * 0.5 + 0.5;
}

void main()
{
    // ========================================================
    // [1] SGPT Horizontal Blend
    // ========================================================

    vec2 dx =
        vec2(
            1.0 / TextureSize.x,
            0.0
        );

    vec3 C =
        texture2D(Texture, uv).rgb;

    vec3 L =
        texture2D(Texture, uv - dx).rgb;

    vec3 R =
        texture2D(Texture, uv + dx).rgb;

    vec3 diffL =
        C - L;

    vec3 diffR =
        C - R;

    float wL =
        dot(
            abs(diffL),
            Y_LUM
        );

    float wR =
        dot(
            abs(diffR),
            Y_LUM
        );

    vec3 blendedColor =
        (wR < wL)
        ? (C - 0.5 * SGPT_BLEND_LEVEL * diffR)
        : (C - 0.5 * SGPT_BLEND_LEVEL * diffL);

    vec3 res =
        clamp(
            blendedColor,
            min(C, min(L, R)),
            max(C, max(L, R))
        );

    // ========================================================
    // [2] Color Pop
    // ========================================================

    float targetHue =
        COLOR_POP_HUE / 360.0;

    float pixelHue =
        getHue(res);

    float dist =
        abs(pixelHue - targetHue);

    if (dist > 0.5)
        dist = 1.0 - dist;

    float normTolerance =
        COLOR_POP_TOLERANCE / 180.0;

    float popMask =
        step(
            normTolerance,
            dist
        );

    popMask =
        1.0 - popMask;

    float grayVal =
        dot(
            res,
            Y_LUM
        );

    vec3 grayscale =
        vec3(grayVal);

    vec3 boostedColor =
        res * COLOR_POP_SAT_BOOST;

    vec3 desatBase =
        mix(
            res,
            grayscale,
            COLOR_POP_DESAT_LEVEL
        );

    vec3 finalRes =
        mix(
            desatBase,
            boostedColor,
            popMask
        );

    // ========================================================
    // [3] Scanlines
    // No additional texture fetch
    // ========================================================

    float scan =
        scanlinePattern(
            uv * TextureSize,
            scanline_scale
        );

    finalRes *= mix(
        1.0,
        scan,
        scanline_amount
    );

    // ========================================================
    // Output
    // ========================================================

    gl_FragColor =
        vec4(
            clamp(finalRes, 0.0, 1.0),
            1.0
        );
}

#endif