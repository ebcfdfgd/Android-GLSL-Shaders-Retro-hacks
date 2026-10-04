#version 450

#pragma parameter SGPT_BLEND_LEVEL "SGPT Blend Strength" 1.0 0.0 1.0 0.05

// Sin City Tone & Threshold Controls
#pragma parameter SC_BW_THRESHOLD "Black Threshold (Cutoff)" 0.05 0.0 1.0 0.01
#pragma parameter SC_WHITE_THRESHOLD "HUD/White Threshold (Outline Protection)" 0.80 0.0 1.0 0.01

// Outline / Comic Ink Controls
#pragma parameter SC_OUTLINE_STRENGTH "Outline Intensity" 1.5 0.0 4.0 0.1
#pragma parameter SC_OUTLINE_THRESH "Outline Sensitivity" 0.12 0.01 0.50 0.01

// Sin City Accent Color Pass
#pragma parameter SC_ACCENT_ENABLE "Accent Color Pass (0=Off, 1=On)" 1.0 0.0 1.0 1.0
#pragma parameter SC_ACCENT_R "Accent Color Red" 0.95 0.0 1.0 0.01
#pragma parameter SC_ACCENT_G "Accent Color Green" 0.05 0.0 1.0 0.01
#pragma parameter SC_ACCENT_B "Accent Color Blue" 0.05 0.0 1.0 0.01
#pragma parameter SC_ACCENT_TOLERANCE "Accent Color Sensitivity" 0.40 0.05 1.0 0.01


// ============================================================================
// RetroArch Parameters
// ============================================================================

layout(push_constant) uniform Push
{
    float SGPT_BLEND_LEVEL;

    float SC_BW_THRESHOLD;
    float SC_WHITE_THRESHOLD;

    float SC_OUTLINE_STRENGTH;
    float SC_OUTLINE_THRESH;

    float SC_ACCENT_ENABLE;
    float SC_ACCENT_R;
    float SC_ACCENT_G;
    float SC_ACCENT_B;

    float SC_ACCENT_TOLERANCE;
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

layout(location = 0) out vec2 vTexCoord;

void main()
{
    vTexCoord = TexCoord;

    gl_Position =
        global.MVP *
        Position;
}


// ============================================================================
// Fragment Stage
// ============================================================================

#pragma stage fragment

layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 2) uniform sampler2D Source;


// ============================================================================
// Luminance Coefficients
// ============================================================================

const vec3 Y =
    vec3(
        0.299,
        0.587,
        0.114
    );


// ============================================================================
// Fragment Main
// ============================================================================

void main()
{
    // ========================================================================
    // 1. Texture Coordinates / Texel Size
    // ========================================================================

    vec2 dx =
        vec2(
            1.0 / global.SourceSize.x,
            0.0
        );

    vec2 dy =
        vec2(
            0.0,
            1.0 / global.SourceSize.y
        );


    // ========================================================================
    // 2. Texture Fetches
    // ========================================================================

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

    vec3 U =
        texture(
            Source,
            vTexCoord + dy
        ).rgb;

    vec3 D =
        texture(
            Source,
            vTexCoord - dy
        ).rgb;


    // ========================================================================
    // 3. SGPT Edge-Smoothing
    // ========================================================================

    vec3 diffL =
        C - L;

    vec3 diffR =
        C - R;


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


    vec3 blended_color;

    if (wR < wL)
    {
        blended_color =
            C -
            0.5 *
            params.SGPT_BLEND_LEVEL *
            diffR;
    }
    else
    {
        blended_color =
            C -
            0.5 *
            params.SGPT_BLEND_LEVEL *
            diffL;
    }


    blended_color =
        clamp(
            blended_color,

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
    // 4. Sin City B&W Engine
    // ========================================================================

    float lum =
        dot(
            blended_color,
            Y
        );


    float sc_bw =
        smoothstep(
            params.SC_BW_THRESHOLD,
            params.SC_WHITE_THRESHOLD,
            lum
        );


    // ========================================================================
    // 5. Edge Detection / Comic Ink
    // ========================================================================

    vec3 diffU =
        C - U;

    vec3 diffD =
        C - D;


    float edge_mag =
        (
            length(diffL) +
            length(diffR) +
            length(diffU) +
            length(diffD)
        )
        *
        0.25;


    float is_outline =
        smoothstep(
            params.SC_OUTLINE_THRESH,

            params.SC_OUTLINE_THRESH +
            0.08,

            edge_mag *
            params.SC_OUTLINE_STRENGTH
        );


    // ========================================================================
    // 6. HUD / White Protection
    // ========================================================================

    float hud_protection =
        1.0 -
        smoothstep(
            params.SC_WHITE_THRESHOLD - 0.05,
            params.SC_WHITE_THRESHOLD,
            lum
        );


    is_outline *=
        hud_protection;


    sc_bw *=
        1.0 -
        is_outline;


    vec3 base_sincity =
        vec3(
            sc_bw
        );


    // ========================================================================
    // 7. Accent Color Pass
    // ========================================================================

    if (params.SC_ACCENT_ENABLE > 0.5)
    {
        vec3 target_color =
            vec3(
                params.SC_ACCENT_R,
                params.SC_ACCENT_G,
                params.SC_ACCENT_B
            );


        // --------------------------------------------------------------------
        // Normalize blended source pixel
        // --------------------------------------------------------------------

        float color_len =
            length(
                blended_color
            );


        vec3 norm_pixel;

        if (color_len > 0.001)
        {
            norm_pixel =
                blended_color /
                color_len;
        }
        else
        {
            norm_pixel =
                vec3(0.0);
        }


        // --------------------------------------------------------------------
        // Normalize target accent
        // --------------------------------------------------------------------

        vec3 norm_target =
            normalize(
                target_color
            );


        // --------------------------------------------------------------------
        // Distance from target accent
        // --------------------------------------------------------------------

        float dist =
            distance(
                norm_pixel,
                norm_target
            );


        float accent_mask =
            1.0 -
            smoothstep(
                0.0,
                params.SC_ACCENT_TOLERANCE,
                dist
            );


        // --------------------------------------------------------------------
        // Saturation protection
        // --------------------------------------------------------------------

        float max_c =
            max(
                blended_color.r,
                max(
                    blended_color.g,
                    blended_color.b
                )
            );


        float min_c =
            min(
                blended_color.r,
                min(
                    blended_color.g,
                    blended_color.b
                )
            );


        float sat =
            max_c -
            min_c;


        accent_mask *=
            smoothstep(
                0.05,
                0.20,
                sat
            );


        // --------------------------------------------------------------------
        // Preserve selected color regions
        // --------------------------------------------------------------------

        base_sincity =
            mix(
                base_sincity,
                blended_color,
                accent_mask
            );
    }


    // ========================================================================
    // 8. Final Output
    // ========================================================================

    FragColor =
        vec4(
            clamp(
                base_sincity,
                0.0,
                1.0
            ),
            1.0
        );
}