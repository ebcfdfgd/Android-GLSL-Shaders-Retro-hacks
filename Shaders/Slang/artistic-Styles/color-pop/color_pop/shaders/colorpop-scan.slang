#version 450

// ============================================================
// RetroArch Color Pop + Scanlines
// Converted from GLSL 110 to Slang 450
// ============================================================


// ============================================================
// Push Constants
// User Parameters
// ============================================================

layout(push_constant) uniform Push
{
    float COLOR_POP_HUE;
    float COLOR_POP_TOLERANCE;
    float COLOR_POP_DESAT_LEVEL;
    float COLOR_POP_SAT_BOOST;

    float scanline_amount;
    float scanline_scale;
} params;


// ============================================================
// RetroArch Parameters
// ============================================================

#pragma parameter COLOR_POP_HUE "Color Pop Target Hue" 0.0 0.0 360.0 1.0
#pragma parameter COLOR_POP_TOLERANCE "Color Pop Tolerance" 1.0 1.0 100.0 1.0
#pragma parameter COLOR_POP_DESAT_LEVEL "Color Pop Background Darkness" 1.0 0.0 1.0 0.01
#pragma parameter COLOR_POP_SAT_BOOST "Color Pop Boost (Keep Color)" 1.2 1.0 2.0 0.05

#pragma parameter scanline_amount "Scanline Amount" 0.12 0.0 0.5 0.02
#pragma parameter scanline_scale "Scanline Density" 1.0 1.0 4.0 0.5


// ============================================================
// RetroArch Global UBO
// ============================================================

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;

    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;

    uint FrameCount;
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
    gl_Position =
        global.MVP *
        Position;

    vTexCoord =
        TexCoord;
}


// ============================================================
// Fragment Stage
// ============================================================

#pragma stage fragment

layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 2) uniform sampler2D Source;


// ============================================================
// Hue Calculation
// Returns hue in range 0.0 - 1.0
// ============================================================

float getHue(vec3 c)
{
    float minVal =
        min(
            c.r,
            min(c.g, c.b)
        );

    float maxVal =
        max(
            c.r,
            max(c.g, c.b)
        );

    float d =
        maxVal - minVal;

    if (d < 0.0001)
        return 0.0;

    float h = 0.0;

    if (c.r == maxVal)
    {
        h =
            (c.g - c.b) /
            d;
    }
    else if (c.g == maxVal)
    {
        h =
            2.0 +
            (c.b - c.r) /
            d;
    }
    else
    {
        h =
            4.0 +
            (c.r - c.g) /
            d;
    }

    h /= 6.0;

    if (h < 0.0)
        h += 1.0;

    return h;
}


// ============================================================
// Scanline
// No texture fetch
// ============================================================

float scanlinePattern(
    vec2 fragCoord,
    float scale
)
{
    float line =
        sin(
            fragCoord.y /
            scale *
            3.14159
        );

    return line * 0.5 + 0.5;
}


// ============================================================
// Fragment Main
// ============================================================

void main()
{
    // ========================================================
    // [1] Original Color Pop
    // ========================================================

    vec3 res =
        texture(
            Source,
            vTexCoord
        ).rgb;


    // --------------------------------------------------------
    // Target Hue
    // --------------------------------------------------------

    float targetHue =
        params.COLOR_POP_HUE /
        360.0;


    // --------------------------------------------------------
    // Pixel Hue
    // --------------------------------------------------------

    float pixelHue =
        getHue(res);


    // --------------------------------------------------------
    // Shortest hue distance
    // --------------------------------------------------------

    float dist =
        abs(
            pixelHue -
            targetHue
        );

    if (dist > 0.5)
        dist =
            1.0 - dist;


    // --------------------------------------------------------
    // Normalize tolerance
    // --------------------------------------------------------

    float normTolerance =
        params.COLOR_POP_TOLERANCE /
        180.0;


    // --------------------------------------------------------
    // Color Pop Mask
    // --------------------------------------------------------

    float popMask =
        step(
            normTolerance,
            dist
        );

    popMask =
        1.0 -
        popMask;


    // --------------------------------------------------------
    // Grayscale
    // --------------------------------------------------------

    float grayVal =
        dot(
            res,
            vec3(
                0.299,
                0.587,
                0.114
            )
        );

    vec3 grayscale =
        vec3(
            grayVal
        );


    // --------------------------------------------------------
    // Boost isolated color
    // --------------------------------------------------------

    vec3 boostedColor =
        res *
        params.COLOR_POP_SAT_BOOST;


    // --------------------------------------------------------
    // Desaturate background
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


    // ========================================================
    // [2] Scanlines
    // No additional texture fetch
    // ========================================================

    float scan =
        scanlinePattern(
            vTexCoord *
            global.SourceSize.xy,
            params.scanline_scale
        );


    finalRes *=
        mix(
            1.0,
            scan,
            params.scanline_amount
        );


    // ========================================================
    // [3] Output
    // ========================================================

    FragColor =
        vec4(
            clamp(
                finalRes,
                0.0,
                1.0
            ),
            1.0
        );
}