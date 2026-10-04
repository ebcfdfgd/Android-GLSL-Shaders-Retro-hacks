#version 450

/* RetroArch Gothic Crypt Enhanced
   No Dither, Halation with Radius, Black Lift,
   Animated Film Grain, Scanlines
*/

// ============================================================================
// RetroArch Parameters
// ============================================================================

#pragma parameter contrast "Contrast" 1.8 1.0 3.0 0.1
#pragma parameter saturation "Color Saturation" 0.9 0.0 3.0 0.1
#pragma parameter grain_str "Grain Strength" 16.0 0.0 32.0 1.0
#pragma parameter brightness "Base Brightness" -0.02 -0.5 0.5 0.02
#pragma parameter gothic_tint "Gothic Cold Tint Amount" 0.5 0.0 1.0 0.1
#pragma parameter halation "Film Halation Bleed" 0.3 0.0 1.0 0.05
#pragma parameter halation_threshold "Halation Threshold" 0.7 0.0 1.0 0.05
#pragma parameter halation_radius "Halation Radius" 1.5 0.5 5.0 0.25
#pragma parameter black_lift "Black Lift (Shadow Floor)" 0.03 0.0 0.15 0.01
#pragma parameter VIGNETTE_STR "Vignette Strength" 0.6 0.0 1.5 0.05

// Scanlines
#pragma parameter scanline_amount "Scanline Amount" 0.12 0.0 0.5 0.02
#pragma parameter scanline_scale "Scanline Density" 1.0 1.0 4.0 0.5


// ============================================================================
// RetroArch Push Constants
// ============================================================================

layout(push_constant) uniform Push
{
    float contrast;
    float saturation;
    float grain_str;
    float brightness;
    float gothic_tint;

    float halation;
    float halation_threshold;
    float halation_radius;

    float black_lift;
    float VIGNETTE_STR;

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
// Exact Animated Film Noise
// ============================================================================

float filmGrain(
    vec2 uv,
    float strength,
    float timer
)
{
    float x =
        (uv.x + 4.0) *
        (uv.y + 4.0) *
        (
            (
                mod(timer, 800.0) +
                10.0
            )
            *
            10.0
        );

    return
        (
            mod(
                (
                    mod(x, 13.0) +
                    1.0
                )
                *
                (
                    mod(x, 123.0) +
                    1.0
                ),
                0.01
            )
            -
            0.005
        )
        *
        strength;
}


// ============================================================================
// Scanline Pattern
// No Texture Fetch
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

    return
        line *
        0.5 +
        0.5;
}


// ============================================================================
// Fragment Main
// ============================================================================

void main()
{
    // ========================================================================
    // 1. Direct Texture Fetch
    // ========================================================================

    vec2 texelSize =
        1.0 /
        global.SourceSize.xy;


    vec3 color =
        texture(
            Source,
            vTexCoord
        ).rgb;


    // ========================================================================
    // 2. Base Brightness
    // ========================================================================

    color +=
        params.brightness;


    // ========================================================================
    // 3. Heavy Gothic Vignette
    // ========================================================================

    vec2 frame_scale =
        global.SourceSize.xy /
        global.OriginalSize.xy;


    vec2 norm_uv =
        vTexCoord *
        frame_scale;


    vec2 cc =
        norm_uv -
        0.5;


    float dist =
        dot(
            cc,
            cc
        );


    float vignette =
        1.0 -
        dist *
        params.VIGNETTE_STR;


    color *=
        vignette;


    // ========================================================================
    // 4. Saturation Adjustment
    // ========================================================================

    float luma =
        dot(
            color,
            vec3(
                0.299,
                0.587,
                0.114
            )
        );


    color =
        mix(
            vec3(luma),
            color,
            params.saturation
        );


    // ========================================================================
    // 5. Film Halation with Radius
    // ========================================================================

    vec3 bright_pass =
        max(
            color -
            params.halation_threshold,
            vec3(0.0)
        );


    vec2 halo_px =
        texelSize *
        params.halation_radius;


    vec3 halation_bleed =
        (
            texture(
                Source,
                vTexCoord +
                halo_px
            ).rgb

            +

            texture(
                Source,
                vTexCoord -
                halo_px
            ).rgb
        )
        *
        0.5;


    color +=
        max(
            halation_bleed,
            vec3(0.0)
        )
        *
        bright_pass
        *
        params.halation;


    // ========================================================================
    // 6. High Contrast & Black Lift
    // ========================================================================

    color =
        (
            color -
            0.5
        )
        *
        params.contrast
        +
        0.5;


    color =
        max(
            color,
            vec3(
                params.black_lift
            )
        );


    // ========================================================================
    // 7. Animated Film Grain
    // ========================================================================

    float noise =
        filmGrain(
            vTexCoord,
            params.grain_str,
            float(global.FrameCount)
        );


    color +=
        noise;


    // ========================================================================
    // 8. Gothic Cold Moonlight / Crypt Tint
    // ========================================================================

    float final_luma =
        dot(
            color,
            vec3(
                0.299,
                0.587,
                0.114
            )
        );


    vec3 gothicColor =
        vec3(
            final_luma
        )
        *
        vec3(
            0.8,
            0.9,
            1.25
        );


    vec3 finalColor =
        mix(
            color,
            gothicColor,
            params.gothic_tint
        );


    // ========================================================================
    // 9. Scanlines
    // No Additional Texture Fetch
    // ========================================================================

    float scan =
        scanlinePattern(
            vTexCoord *
            global.SourceSize.xy,

            params.scanline_scale
        );


    finalColor *=
        mix(
            1.0,
            scan,
            params.scanline_amount
        );


    // ========================================================================
    // 10. Final Output
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