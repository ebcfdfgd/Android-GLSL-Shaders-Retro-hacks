#version 450

/*
    PURE-COLOR-INVERTER + RAINBOW HIGHLIGHT
    - PURPOSE: Pure mathematical color inversion (with optional toggle)
      mixed with Rainbow Highlight features.
*/

// ============================================================================
// RetroArch Parameters
// ============================================================================

#pragma parameter INV_ENABLE           "Enable Color Inversion"       1.0  0.0 1.0  1.0
#pragma parameter UNI_ACCENT_THRESHOLD "Rainbow Highlight Threshold"  0.8  0.0 0.98 0.01
#pragma parameter UNI_ACCENT_STRENGTH  "Rainbow Accent Strength"      0.7  0.0 1.0  0.05
#pragma parameter UNI_RAINBOW_SCALE    "Rainbow Spatial Scale"        1.0  0.1 4.0  0.1
#pragma parameter UNI_RAINBOW_SPEED    "Rainbow Shimmer Speed"        0.15 0.0 1.0  0.01


// ============================================================================
// Push Constants
// ============================================================================

layout(push_constant) uniform Push
{
    float INV_ENABLE;
    float UNI_ACCENT_THRESHOLD;
    float UNI_ACCENT_STRENGTH;
    float UNI_RAINBOW_SCALE;
    float UNI_RAINBOW_SPEED;
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
    gl_Position =
        global.MVP *
        Position;

    vTexCoord =
        TexCoord.xy;
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
// Hue → RGB
// ============================================================================

vec3 hueColor(float h)
{
    vec4 K =
        vec4(
            1.0,
            2.0 / 3.0,
            1.0 / 3.0,
            3.0
        );

    vec3 p =
        abs(
            fract(
                h + K.xyz
            ) * 6.0 -
            K.www
        );

    return clamp(
        p - K.xxx,
        0.0,
        1.0
    );
}


// ============================================================================
// Main
// ============================================================================

void main()
{
    // 1. Read core color directly from the source
    vec3 core_col =
        texture(
            Source,
            vTexCoord
        ).rgb;


    // Calculate original luminance to target highlights
    // for the rainbow effect.
    float lum =
        clamp(
            dot(core_col, Y),
            0.0,
            1.0
        );


    // 2. Pure pixel-by-pixel mathematical inversion
    //    with toggle.
    vec3 inverted_col =
        vec3(1.0) -
        core_col;

    vec3 base_col =
        mix(
            core_col,
            inverted_col,
            params.INV_ENABLE
        );


    // 3. Unichrome Touch:
    //    Rainbow only on highest highlights.
    vec2 gamePixel =
        floor(
            vTexCoord *
            global.SourceSize.xy
        );


    float rainbowMask =
        smoothstep(
            params.UNI_ACCENT_THRESHOLD - 0.05,
            params.UNI_ACCENT_THRESHOLD + 0.05,
            lum
        );


    float hue =
        fract(
            (gamePixel.x + gamePixel.y) *
            0.01 *
            params.UNI_RAINBOW_SCALE

            +

            float(global.FrameCount) *
            params.UNI_RAINBOW_SPEED *
            0.005
        );


    vec3 accent =
        hueColor(hue);


    // Apply rainbow over the base image
    vec3 result =
        mix(
            base_col,
            accent,
            rainbowMask *
            params.UNI_ACCENT_STRENGTH
        );


    // 4. Output the final image
    FragColor =
        vec4(
            clamp(
                result,
                0.0,
                1.0
            ),
            1.0
        );
}