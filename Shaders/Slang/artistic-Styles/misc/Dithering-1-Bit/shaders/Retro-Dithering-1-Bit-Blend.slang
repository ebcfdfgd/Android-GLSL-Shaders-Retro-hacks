#version 450

#pragma parameter sep_c0       "--- [ Color 0 (Darkest) ] ---" 0.0 0.0 0.0 1.0
#pragma parameter c0_r         "Red"                           0.06 0.0 1.0 0.01
#pragma parameter c0_g         "Green"                         0.22 0.0 1.0 0.01
#pragma parameter c0_b         "Blue"                          0.06 0.0 1.0 0.01

#pragma parameter sep_c1       "--- [ Color 1 ] ---"           0.0 0.0 0.0 1.0
#pragma parameter c1_r         "Red"                           0.18 0.0 1.0 0.01
#pragma parameter c1_g         "Green"                         0.38 0.0 1.0 0.01
#pragma parameter c1_b         "Blue"                          0.18 0.0 1.0 0.01

#pragma parameter sep_c2       "--- [ Color 2 ] ---"           0.0 0.0 0.0 1.0
#pragma parameter c2_r         "Red"                           0.54 0.0 1.0 0.01
#pragma parameter c2_g         "Green"                         0.75 0.0 1.0 0.01
#pragma parameter c2_b         "Blue"                          0.22 0.0 1.0 0.01

#pragma parameter sep_c3       "--- [ Color 3 (Brightest) ] ---" 0.0 0.0 0.0 1.0
#pragma parameter c3_r         "Red"                           0.85 0.0 1.0 0.01
#pragma parameter c3_g         "Green"                         0.93 0.0 1.0 0.01
#pragma parameter c3_b         "Blue"                          0.60 0.0 1.0 0.01

#pragma parameter gb_dither_strength "Bayer Intensity"         0.35 0.0 1.0 0.05
#pragma parameter gb_pixel_size      "Pixel Scale"             1.0  1.0 4.0 1.0
#pragma parameter SGPT_BLEND_LEVEL   "Blend Level"             1.0  0.0 1.0 0.05


// ============================================================================
// Push Constants
// ============================================================================

layout(push_constant) uniform Push
{
    float sep_c0;
    float c0_r;
    float c0_g;
    float c0_b;

    float sep_c1;
    float c1_r;
    float c1_g;
    float c1_b;

    float sep_c2;
    float c2_r;
    float c2_g;
    float c2_b;

    float sep_c3;
    float c3_r;
    float c3_g;
    float c3_b;

    float gb_dither_strength;
    float gb_pixel_size;
    float SGPT_BLEND_LEVEL;
} params;


// ============================================================================
// RetroArch Global UBO
// ============================================================================

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
} global;


// ============================================================================
// Vertex Stage
// ============================================================================

#pragma stage vertex

layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;

layout(location = 0) out vec2 uv;

void main()
{
    uv = TexCoord;
    gl_Position = global.MVP * Position;
}


// ============================================================================
// Fragment Stage
// ============================================================================

#pragma stage fragment

layout(location = 0) in vec2 uv;
layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 2) uniform sampler2D Source;


const vec3 Y =
    vec3(
        0.299,
        0.587,
        0.114
    );


// ============================================================================
// Luma
// ============================================================================

float luma(vec3 c)
{
    return dot(c, Y);
}


// ============================================================================
// 4x4 Bayer Matrix
// ============================================================================

float bayer4(vec2 p)
{
    vec2 pos =
        mod(
            p,
            4.0
        );

    int ix =
        int(pos.x);

    int iy =
        int(pos.y);

    float m = 0.0;


    if (iy == 0)
    {
        if (ix == 0)
        {
            m = 0.0;
        }
        else if (ix == 1)
        {
            m = 8.0;
        }
        else if (ix == 2)
        {
            m = 2.0;
        }
        else
        {
            m = 10.0;
        }
    }
    else if (iy == 1)
    {
        if (ix == 0)
        {
            m = 12.0;
        }
        else if (ix == 1)
        {
            m = 4.0;
        }
        else if (ix == 2)
        {
            m = 14.0;
        }
        else
        {
            m = 6.0;
        }
    }
    else if (iy == 2)
    {
        if (ix == 0)
        {
            m = 3.0;
        }
        else if (ix == 1)
        {
            m = 11.0;
        }
        else if (ix == 2)
        {
            m = 1.0;
        }
        else
        {
            m = 9.0;
        }
    }
    else
    {
        if (ix == 0)
        {
            m = 15.0;
        }
        else if (ix == 1)
        {
            m = 7.0;
        }
        else if (ix == 2)
        {
            m = 13.0;
        }
        else
        {
            m = 5.0;
        }
    }

    return m / 16.0;
}


// ============================================================================
// Palette
// ============================================================================

vec3 getPaletteColor(float val)
{
    vec3 c0 =
        vec3(
            params.c0_r,
            params.c0_g,
            params.c0_b
        );

    vec3 c1 =
        vec3(
            params.c1_r,
            params.c1_g,
            params.c1_b
        );

    vec3 c2 =
        vec3(
            params.c2_r,
            params.c2_g,
            params.c2_b
        );

    vec3 c3 =
        vec3(
            params.c3_r,
            params.c3_g,
            params.c3_b
        );


    if (val < 0.25)
    {
        return c0;
    }

    if (val < 0.50)
    {
        return c1;
    }

    if (val < 0.75)
    {
        return c2;
    }

    return c3;
}


// ============================================================================
// Main
// ============================================================================

void main()
{
    // ========================================================================
    // Pixel-Scaled Coordinates
    // ========================================================================

    vec2 gamePixelCoord =
        floor(
            uv *
            global.SourceSize.xy /
            params.gb_pixel_size
        );

    vec2 coord =
        (
            gamePixelCoord *
            params.gb_pixel_size +
            params.gb_pixel_size * 0.5
        ) /
        global.SourceSize.xy;

    vec2 dx =
        vec2(
            1.0 /
            global.SourceSize.x,
            0.0
        );


    // ========================================================================
    // SGPT Horizontal Sampling
    // ========================================================================

    vec3 C =
        texture(
            Source,
            coord
        ).rgb;

    vec3 L =
        texture(
            Source,
            coord - dx
        ).rgb;

    vec3 R =
        texture(
            Source,
            coord + dx
        ).rgb;


    vec3 diffL =
        C -
        L;

    vec3 diffR =
        C -
        R;

    float wL =
        dot(
            abs(diffL),
            Y
        );

    float wR =
        dot(
            abs(diffR),
            Y
        );


    // ========================================================================
    // SGPT Blend
    // ========================================================================

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

    blendedColor =
        clamp(
            blendedColor,
            min(
                C,
                min(L, R)
            ),
            max(
                C,
                max(L, R)
            )
        );


    // ========================================================================
    // Luminance + Bayer Dithering
    // ========================================================================

    float lum =
        luma(blendedColor);

    float dither =
        bayer4(gamePixelCoord);

    float adjustedLum =
        clamp(
            lum +
            (
                dither -
                0.5
            ) *
            params.gb_dither_strength,
            0.0,
            1.0
        );


    // ========================================================================
    // Palette Mapping
    // ========================================================================

    vec3 finalColor =
        getPaletteColor(
            adjustedLum
        );


    // ========================================================================
    // Final Output
    // ========================================================================

    FragColor =
        vec4(
            finalColor,
            1.0
        );
}