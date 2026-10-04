#version 450

// ============================================================
// RetroArch Color Pop + SGPT Blend Shader
// Converted from GLSL 110 to Slang 450
// ============================================================


// ============================================================
// Push Constants
// ============================================================

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;

    float COLOR_POP_HUE;
    float COLOR_POP_TOLERANCE;
    float COLOR_POP_DESAT_LEVEL;
    float COLOR_POP_SAT_BOOST;

    float SGPT_BLEND_LEVEL;
} params;


// ============================================================
// RetroArch Parameters
// ============================================================

#pragma parameter COLOR_POP_HUE "Color Pop Target Hue" 0.0 0.0 360.0 1.0
#pragma parameter COLOR_POP_TOLERANCE "Color Pop Tolerance" 1.0 1.0 100.0 1.0
#pragma parameter COLOR_POP_DESAT_LEVEL "Color Pop Background Darkness" 1.0 0.0 1.0 0.01
#pragma parameter COLOR_POP_SAT_BOOST "Color Pop Boost (Keep Color)" 1.2 1.0 2.0 0.05
#pragma parameter SGPT_BLEND_LEVEL "SGPT Blend Level" 1.0 0.0 1.0 0.05


// ============================================================
// RetroArch Global UBO
// ============================================================

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;


// ============================================================
// Vertex Stage
// ============================================================

#pragma stage vertex

layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;

layout(location = 0) out vec2 vTexCoord;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
}


// ============================================================
// Fragment Stage
// ============================================================

#pragma stage fragment

layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 2) uniform sampler2D Source;


// ============================================================
// Constants
// ============================================================

const vec3 Y_LUM = vec3(
    0.299,
    0.587,
    0.114
);


// ============================================================
// Hue Calculation
// Returns hue in range 0.0 - 1.0
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
    {
        h = (c.g - c.b) / d;
    }
    else if (c.g == maxVal)
    {
        h = 2.0 + (c.b - c.r) / d;
    }
    else
    {
        h = 4.0 + (c.r - c.g) / d;
    }

    h = h / 6.0;

    if (h < 0.0)
        h += 1.0;

    return h;
}


// ============================================================
// Fragment Main
// ============================================================

void main()
{
    // --------------------------------------------------------
    // [1] SGPT Horizontal Blend Preprocessing
    // --------------------------------------------------------

    vec2 dx = vec2(
        1.0 / params.SourceSize.x,
        0.0
    );


    // Center / Left / Right samples

    vec3 C =
        texture(
            Source,
            vTexCoord
        ).rgb;

    vec3 L =
        texture(
            Source,
            vTexCoord - dx
        ).rgb;

    vec3 R =
        texture(
            Source,
            vTexCoord + dx
        ).rgb;


    // --------------------------------------------------------
    // Differences
    // --------------------------------------------------------

    vec3 diffL =
        C - L;

    vec3 diffR =
        C - R;


    // --------------------------------------------------------
    // Luminance-based edge weights
    // --------------------------------------------------------

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


    // --------------------------------------------------------
    // SGPT blended color
    // --------------------------------------------------------

    vec3 blendedColor;

    if (wR < wL)
    {
        blendedColor =
            C -
            0.5 *
            params.SGPT_BLEND_LEVEL *
            diffR;
    }
    else
    {
        blendedColor =
            C -
            0.5 *
            params.SGPT_BLEND_LEVEL *
            diffL;
    }


    // --------------------------------------------------------
    // Clamp SGPT result between horizontal neighbors
    // --------------------------------------------------------

    vec3 minColor =
        min(
            C,
            min(L, R)
        );

    vec3 maxColor =
        max(
            C,
            max(L, R)
        );

    vec3 res =
        clamp(
            blendedColor,
            minColor,
            maxColor
        );


    // --------------------------------------------------------
    // [2] Color Pop Processing
    // --------------------------------------------------------

    float targetHue =
        params.COLOR_POP_HUE / 360.0;


    float pixelHue =
        getHue(res);


    // --------------------------------------------------------
    // Shortest hue-wheel distance
    // --------------------------------------------------------

    float dist =
        abs(
            pixelHue - targetHue
        );

    if (dist > 0.5)
        dist = 1.0 - dist;


    // --------------------------------------------------------
    // Normalize tolerance
    // --------------------------------------------------------

    float normTolerance =
        params.COLOR_POP_TOLERANCE / 180.0;


    // --------------------------------------------------------
    // Sharp Color Pop mask
    // --------------------------------------------------------

    float popMask =
        step(
            normTolerance,
            dist
        );

    popMask =
        1.0 - popMask;


    // --------------------------------------------------------
    // Grayscale
    // --------------------------------------------------------

    float grayVal =
        dot(
            res,
            Y_LUM
        );

    vec3 grayscale =
        vec3(
            grayVal
        );


    // --------------------------------------------------------
    // Boost target color
    // --------------------------------------------------------

    vec3 boostedColor =
        res *
        params.COLOR_POP_SAT_BOOST;


    // --------------------------------------------------------
    // Desaturated background
    // --------------------------------------------------------

    vec3 desatBase =
        mix(
            res,
            grayscale,
            params.COLOR_POP_DESAT_LEVEL
        );


    // --------------------------------------------------------
    // Final Color Pop
    // --------------------------------------------------------

    vec3 finalRes =
        mix(
            desatBase,
            boostedColor,
            popMask
        );


    // --------------------------------------------------------
    // Output
    // --------------------------------------------------------

    FragColor =
        vec4(
            finalRes,
            1.0
        );
}