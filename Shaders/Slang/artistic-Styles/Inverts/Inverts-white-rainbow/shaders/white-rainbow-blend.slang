#version 450

/*
    SGPT + Rainbow Accent Combined Shader
    - PURPOSE: Combines SGPT edge-preserving smoothing and rainbow highlights
      without color inversion.
*/

// ============================================================================
// RetroArch Parameters
// ============================================================================

#pragma parameter SGPT_BLEND_LEVEL     "SGPT Blend Level"             1.0    0.0 1.0    0.05
#pragma parameter UNI_ACCENT_THRESHOLD "Rainbow Highlight Threshold"  0.8    0.0 0.98 0.01
#pragma parameter UNI_ACCENT_STRENGTH  "Rainbow Accent Strength"      0.7    0.0 1.0  0.05
#pragma parameter UNI_RAINBOW_SCALE    "Rainbow Spatial Scale"        1.0    0.1 4.0  0.1
#pragma parameter UNI_RAINBOW_SPEED    "Rainbow Shimmer Speed"        0.15   0.0 1.0  0.01


// ============================================================================
// Push Constants
// ============================================================================

layout(push_constant) uniform Push
{
    float SGPT_BLEND_LEVEL;
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

layout(location = 0) out vec2 uv;

void main()
{
    uv =
        TexCoord;

    gl_Position =
        global.MVP *
        Position;
}


// ============================================================================
// Fragment Stage
// ============================================================================

#pragma stage fragment

layout(location = 0) in vec2 uv;
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
    // [1] Read pixels (3 samples) for SGPT
    vec2 dx =
        vec2(
            1.0 / global.SourceSize.x,
            0.0
        );

    vec3 C =
        texture(
            Source,
            uv
        ).rgb;

    vec3 L =
        texture(
            Source,
            uv - dx
        ).rgb;

    vec3 R =
        texture(
            Source,
            uv + dx
        ).rgb;


    // [2] Calculate differences
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


    // [3] Direct Blend - SGPT
    vec3 sgptColor;

    if (wR < wL)
    {
        sgptColor =
            C -
            0.5 *
            params.SGPT_BLEND_LEVEL *
            diffR;
    }
    else
    {
        sgptColor =
            C -
            0.5 *
            params.SGPT_BLEND_LEVEL *
            diffL;
    }


    // Clamp SGPT color to avoid overshooting
    sgptColor =
        clamp(
            sgptColor,
            min(
                C,
                min(L, R)
            ),
            max(
                C,
                max(L, R)
            )
        );


    // [4] Calculate luminance for rainbow highlights
    //     based on the processed SGPT color.
    float lum =
        clamp(
            dot(
                sgptColor,
                Y
            ),
            0.0,
            1.0
        );


    // [5] Rainbow Accent on highlights directly over
    //     the SGPT processed color.
    vec2 gamePixel =
        floor(
            uv *
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


    // Apply rainbow over the SGPT image
    vec3 result =
        mix(
            sgptColor,
            accent,
            rainbowMask *
            params.UNI_ACCENT_STRENGTH
        );


    // [6] Final Output
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