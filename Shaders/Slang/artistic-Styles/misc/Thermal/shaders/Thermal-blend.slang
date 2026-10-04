#version 450

#pragma parameter thermal_strength "Thermal Strength" 1.0 0.0 1.0 0.05
#pragma parameter thermal_contrast "Thermal Contrast" 1.15 0.5 2.0 0.05
#pragma parameter thermal_brightness "Thermal Brightness" 0.0 -0.3 0.3 0.02
#pragma parameter thermal_midpoint "Thermal Midpoint" 0.50 0.0 1.0 0.01
#pragma parameter thermal_range "Thermal Range" 1.00 0.1 2.0 0.05
#pragma parameter thermal_noise "Thermal Noise" 0.08 0.0 0.5 0.01
#pragma parameter thermal_random "Thermal Randomness" 0.20 0.0 1.0 0.01
#pragma parameter thermal_edge "Thermal Edge Detail" 0.10 0.0 1.0 0.01
#pragma parameter SGPT_BLEND_LEVEL "Blend Level" 1.0 0.0 1.0 0.05


// ============================================================================
// Push Constants
// ============================================================================

layout(push_constant) uniform Push
{
    float thermal_strength;
    float thermal_contrast;
    float thermal_brightness;
    float thermal_midpoint;
    float thermal_range;
    float thermal_noise;
    float thermal_random;
    float thermal_edge;
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


// ============================================================================
// Hash
// ============================================================================

float hash(vec2 p, float f)
{
    return fract(
        sin(
            dot(
                p + f,
                vec2(12.9898, 78.233)
            )
        ) *
        43758.5453
    );
}


// ============================================================================
// Thermal Palette
// ============================================================================

vec3 thermalPalette(float t)
{
    t = clamp(t, 0.0, 1.0);

    vec3 c0 = vec3(0.02, 0.0, 0.08);
    vec3 c1 = vec3(0.0, 0.20, 1.0);
    vec3 c2 = vec3(0.0, 1.0, 1.0);
    vec3 c3 = vec3(0.10, 1.0, 0.05);
    vec3 c4 = vec3(1.0, 0.90, 0.0);
    vec3 c5 = vec3(1.0, 0.18, 0.0);
    vec3 c6 = vec3(1.0);

    if (t < 0.16)
    {
        return mix(
            c0,
            c1,
            t / 0.16
        );
    }

    if (t < 0.34)
    {
        return mix(
            c1,
            c2,
            (t - 0.16) / 0.18
        );
    }

    if (t < 0.52)
    {
        return mix(
            c2,
            c3,
            (t - 0.34) / 0.18
        );
    }

    if (t < 0.70)
    {
        return mix(
            c3,
            c4,
            (t - 0.52) / 0.18
        );
    }

    if (t < 0.86)
    {
        return mix(
            c4,
            c5,
            (t - 0.70) / 0.16
        );
    }

    return mix(
        c5,
        c6,
        (t - 0.86) / 0.14
    );
}


// ============================================================================
// Fragment Main
// ============================================================================

void main()
{
    const vec3 Y =
        vec3(
            0.299,
            0.587,
            0.114
        );


    // ========================================================================
    // Base Texture
    // ========================================================================

    vec3 base =
        texture(
            Source,
            uv
        ).rgb;

    vec2 px =
        1.0 /
        global.SourceSize.xy;


    // ========================================================================
    // Reusing the existing 5 texture fetches
    // No extra fetches added
    // ========================================================================

    vec3 L_rgb =
        texture(
            Source,
            uv -
            vec2(
                px.x,
                0.0
            )
        ).rgb;

    vec3 R_rgb =
        texture(
            Source,
            uv +
            vec2(
                px.x,
                0.0
            )
        ).rgb;

    vec3 U_rgb =
        texture(
            Source,
            uv +
            vec2(
                0.0,
                px.y
            )
        ).rgb;

    vec3 D_rgb =
        texture(
            Source,
            uv -
            vec2(
                0.0,
                px.y
            )
        ).rgb;


    // ========================================================================
    // SGPT Blend Processing
    // ========================================================================

    vec3 diffL =
        base -
        L_rgb;

    vec3 diffR =
        base -
        R_rgb;

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

    vec3 base_processed;

    if (wR < wL)
    {
        base_processed =
            base -
            0.5 *
            params.SGPT_BLEND_LEVEL *
            diffR;
    }
    else
    {
        base_processed =
            base -
            0.5 *
            params.SGPT_BLEND_LEVEL *
            diffL;
    }

    base_processed =
        clamp(
            base_processed,
            min(
                base,
                min(
                    L_rgb,
                    R_rgb
                )
            ),
            max(
                base,
                max(
                    L_rgb,
                    R_rgb
                )
            )
        );


    // ========================================================================
    // Thermal Response
    // ========================================================================

    float lum =
        dot(
            base_processed,
            Y
        );

    float t =
        clamp(
            (
                lum -
                params.thermal_midpoint
            ) *
            params.thermal_range +
            params.thermal_midpoint,

            0.0,
            1.0
        );

    t =
        clamp(
            (
                t -
                0.5
            ) *
            params.thermal_contrast +
            0.5 +
            params.thermal_brightness,

            0.0,
            1.0
        );


    // ========================================================================
    // Edge Detail
    // ========================================================================

    float l =
        dot(
            L_rgb,
            Y
        );

    float r =
        dot(
            R_rgb,
            Y
        );

    float u =
        dot(
            U_rgb,
            Y
        );

    float d =
        dot(
            D_rgb,
            Y
        );

    float edge =
        clamp(
            abs(l - r) +
            abs(u - d),

            0.0,
            1.0
        ) *
        params.thermal_edge;

    t =
        clamp(
            t +
            edge *
            (0.5 - t),

            0.0,
            1.0
        );


    // ========================================================================
    // Thermal Noise
    // ========================================================================

    float n =
        hash(
            floor(
                uv *
                global.SourceSize.xy /
                2.0
            ),
            float(global.FrameCount)
        ) -
        0.5;

    float rn =
        hash(
            vec2(
                float(global.FrameCount) *
                0.013,
                7.31
            ),
            float(global.FrameCount)
        ) -
        0.5;

    t =
        clamp(
            t +
            n *
            params.thermal_noise +
            rn *
            params.thermal_random *
            0.035,

            0.0,
            1.0
        );


    // ========================================================================
    // Thermal Color
    // ========================================================================

    vec3 thermal =
        thermalPalette(t);

    vec3 color =
        mix(
            base_processed,
            thermal,
            params.thermal_strength
        );


    // ========================================================================
    // Final Output
    // ========================================================================

    FragColor =
        vec4(
            clamp(
                color,
                0.0,
                1.0
            ),
            1.0
        );
}