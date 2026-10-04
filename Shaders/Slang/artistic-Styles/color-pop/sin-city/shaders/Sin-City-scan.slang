#version 450

// ============================================================================
// Sin City Tone & Threshold Controls
// ============================================================================

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

// Scanlines
#pragma parameter scanline_amount "Scanline Amount" 0.12 0.0 0.5 0.02
#pragma parameter scanline_scale "Scanline Density" 1.0 1.0 4.0 0.5


// ============================================================================
// RetroArch Parameters
// ============================================================================

layout(push_constant) uniform Push
{
    float SC_BW_THRESHOLD;
    float SC_WHITE_THRESHOLD;

    float SC_OUTLINE_STRENGTH;
    float SC_OUTLINE_THRESH;

    float SC_ACCENT_ENABLE;
    float SC_ACCENT_R;
    float SC_ACCENT_G;
    float SC_ACCENT_B;
    float SC_ACCENT_TOLERANCE;

    float scanline_amount;
    float scanline_scale;
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
// Constants
// ============================================================================

const vec3 Y =
    vec3(
        0.299,
        0.587,
        0.114
    );


// ============================================================================
// Scanline Pattern
// ============================================================================

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


// ============================================================================
// Fragment Main
// ============================================================================

void main()
{
    // ========================================================================
    // 1. Texel Size
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
    // 3. Sin City B&W Engine
    // ========================================================================

    float lum =
        dot(
            C,
            Y
        );


    float sc_bw =
        smoothstep(
            params.SC_BW_THRESHOLD,
            params.SC_WHITE_THRESHOLD,
            lum
        );


    // ========================================================================
    // 4. Edge Detection / Comic Ink
    // ========================================================================

    vec3 diffL =
        C - L;

    vec3 diffR =
        C - R;

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
    // 5. HUD / White Protection
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
    // 6. Accent Color Pass
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
        // Normalize source pixel
        // --------------------------------------------------------------------

        float color_len =
            length(
                C
            );


        vec3 norm_pixel;

        if (color_len > 0.001)
        {
            norm_pixel =
                C /
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
        // Color distance
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
                C.r,
                max(
                    C.g,
                    C.b
                )
            );


        float min_c =
            min(
                C.r,
                min(
                    C.g,
                    C.b
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
        // Preserve selected original accent colors
        // --------------------------------------------------------------------

        base_sincity =
            mix(
                base_sincity,
                C,
                accent_mask
            );
    }


    // ========================================================================
    // 7. Scanlines
    // ========================================================================

    float scan =
        scanlinePattern(
            vTexCoord *
            global.SourceSize.xy,

            params.scanline_scale
        );


    base_sincity *=
        mix(
            1.0,
            scan,
            params.scanline_amount
        );


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