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

#pragma parameter SGPT_BLEND_LEVEL "Blend Level" 1.0 0.0 1.0 0.05
#pragma parameter DOT_DENSITY "Dot Grid Size (px)" 3.0 3.0 16.0 0.5
#pragma parameter DOT_ANGLE "Dot Grid Angle (deg)" 0.0 0.0 90.0 5.0
#pragma parameter DOT_STRENGTH "Dot Shading Strength" 1.0 0.0 1.0 0.05


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

    float SGPT_BLEND_LEVEL;

    float DOT_DENSITY;
    float DOT_ANGLE;
    float DOT_STRENGTH;
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
// Ben-Day Dot Pattern
// ============================================================================

float benDayDot(
    vec2 fragCoord,
    float density,
    float angleDeg
)
{
    float angle =
        radians(angleDeg);

    vec2 rotated =
        vec2(
            fragCoord.x * cos(angle) -
            fragCoord.y * sin(angle),

            fragCoord.x * sin(angle) +
            fragCoord.y * cos(angle)
        );

    vec2 cell =
        mod(
            rotated,
            density
        ) -
        density * 0.5;

    float radius =
        density * 0.30;

    return
        1.0 -
        smoothstep(
            radius - 0.75,
            radius + 0.75,
            length(cell)
        );
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
    vec2 gamePixelCoord =
        floor(
            uv *
            global.SourceSize.xy
        );

    vec2 coord =
        (
            gamePixelCoord +
            0.5
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


    float wL =
        dot(
            abs(C - L),
            Y
        );

    float wR =
        dot(
            abs(C - R),
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
            (C - R);
    }
    else
    {
        blendedColor =
            C -
            0.5 *
            params.SGPT_BLEND_LEVEL *
            (C - L);
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
    // Palette Mapping
    // ========================================================================

    vec3 finalColor =
        getPaletteColor(
            luma(blendedColor)
        );


    // ========================================================================
    // Ben-Day Dot Shading
    // ========================================================================

    float darkness =
        1.0 -
        luma(finalColor);

    float dotMask =
        benDayDot(
            gamePixelCoord,
            params.DOT_DENSITY,
            params.DOT_ANGLE
        ) *
        darkness *
        params.DOT_STRENGTH;

    finalColor =
        mix(
            finalColor,
            vec3(0.0),
            dotMask * 0.4
        );


    // ========================================================================
    // Final Output
    // ========================================================================

    FragColor =
        vec4(
            clamp(
                finalColor,
                0.0,
                1.0
            ),
            1.0
        );
}