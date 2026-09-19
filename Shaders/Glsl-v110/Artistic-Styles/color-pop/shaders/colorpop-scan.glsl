#version 110

// RetroArch Color Pop Shader + Scanlines
// Isolates a specific target color and desaturates the rest.

// ============================================================
// COLOR POP PARAMETERS
// ============================================================

#pragma parameter COLOR_POP_HUE "Color Pop Target Hue" 0.0 0.0 360.0 1.0
#pragma parameter COLOR_POP_TOLERANCE "Color Pop Tolerance" 1.0 1.0 100.0 1.0
#pragma parameter COLOR_POP_DESAT_LEVEL "Color Pop Background Darkness" 1.0 0.0 1.0 0.01
#pragma parameter COLOR_POP_SAT_BOOST "Color Pop Boost (Keep Color)" 1.2 1.0 2.0 0.05

// ============================================================
// SCANLINE PARAMETERS
// ============================================================

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

uniform float scanline_amount;
uniform float scanline_scale;

#else

#define COLOR_POP_HUE             0.0
#define COLOR_POP_TOLERANCE      15.0
#define COLOR_POP_DESAT_LEVEL     0.9
#define COLOR_POP_SAT_BOOST       1.2

#define scanline_amount            0.12
#define scanline_scale             2.0

#endif

// ============================================================
// Hue calculation
// ============================================================

float getHue(vec3 c)
{
    float minVal = min(c.r, min(c.g, c.b));
    float maxVal = max(c.r, max(c.g, c.b));
    float d = maxVal - minVal;

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
    float line = sin(
        fragCoord.y / scale * 3.14159
    );

    return line * 0.5 + 0.5;
}

void main()
{
    // ========================================================
    // Original Color Pop
    // ========================================================

    vec3 res = texture2D(
        Texture,
        uv
    ).rgb;

    float targetHue =
        COLOR_POP_HUE / 360.0;

    float pixelHue =
        getHue(res);

    // Shortest hue distance
    float dist =
        abs(pixelHue - targetHue);

    if (dist > 0.5)
        dist = 1.0 - dist;

    float normTolerance =
        COLOR_POP_TOLERANCE / 180.0;

    float popMask =
        step(normTolerance, dist);

    popMask =
        1.0 - popMask;

    // Grayscale
    float grayVal =
        dot(
            res,
            vec3(0.299, 0.587, 0.114)
        );

    vec3 grayscale =
        vec3(grayVal);

    // Boost isolated color
    vec3 boostedColor =
        res * COLOR_POP_SAT_BOOST;

    // Desaturate background
    vec3 desatBase =
        mix(
            res,
            grayscale,
            COLOR_POP_DESAT_LEVEL
        );

    // Final Color Pop
    vec3 finalRes =
        mix(
            desatBase,
            boostedColor,
            popMask
        );

    // ========================================================
    // Scanlines
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