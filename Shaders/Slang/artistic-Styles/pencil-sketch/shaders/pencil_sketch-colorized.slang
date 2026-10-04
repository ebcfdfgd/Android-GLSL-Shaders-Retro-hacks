#version 450

#pragma parameter PS_BLUR          "Blur Radius (px)"        2.0   0.5 8.0   0.1
#pragma parameter PS_STRENGTH      "Strength"                80.0 0.0 100.0 5.0
#pragma parameter PS_BRIGHTNESS    "Pencil Brightness"       0.0  -1.0 1.0   0.05
#pragma parameter PS_SATURATION    "Color Saturation"        1.0   1.0 2.0   0.05


// ============================================================================
// Push Constants
// ============================================================================

layout(push_constant) uniform Push
{
    float PS_BLUR;
    float PS_STRENGTH;
    float PS_BRIGHTNESS;
    float PS_SATURATION;
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
// Main
// ============================================================================

void main()
{
    vec2 texel =
        params.PS_BLUR /
        global.SourceSize.xy;


    // ========================================================================
    // [1] Base original texture sample
    // ========================================================================

    vec3 srcColor =
        texture(
            Source,
            uv
        ).rgb;


    // Apply color saturation adjustment
    float gray =
        dot(
            srcColor,
            Y
        );

    vec3 baseColor =
        mix(
            vec3(gray),
            srcColor,
            params.PS_SATURATION
        );


    // ========================================================================
    // [2] 4-tap cross blur on inverted RGB channels
    //     using direct texture sampling
    // ========================================================================

    vec3 sum =
        vec3(1.0) -
        baseColor;

    sum +=
        vec3(1.0) -
        texture(
            Source,
            uv +
            texel *
            vec2(
                1.0,
                0.0
            )
        ).rgb;

    sum +=
        vec3(1.0) -
        texture(
            Source,
            uv +
            texel *
            vec2(
                -1.0,
                0.0
            )
        ).rgb;

    sum +=
        vec3(1.0) -
        texture(
            Source,
            uv +
            texel *
            vec2(
                0.0,
                1.0
            )
        ).rgb;

    sum +=
        vec3(1.0) -
        texture(
            Source,
            uv +
            texel *
            vec2(
                0.0,
                -1.0
            )
        ).rgb;

    vec3 blurredInv =
        sum /
        5.0;


    // ========================================================================
    // [3] RGB Per-Channel Color Dodge Effect (Color Pencil)
    // ========================================================================

    vec3 sketch =
        baseColor /
        max(
            vec3(1.0) -
            blurredInv,
            vec3(0.004)
        );

    sketch =
        clamp(
            sketch,
            0.0,
            1.0
        );


    // ========================================================================
    // [4] Apply Brightness
    // ========================================================================

    sketch =
        clamp(
            sketch +
            vec3(params.PS_BRIGHTNESS),
            0.0,
            1.0
        );


    // ========================================================================
    // [5] Mix full base color with colored pencil sketch
    // ========================================================================

    float amount =
        clamp(
            params.PS_STRENGTH /
            100.0,
            0.0,
            1.0
        );

    vec3 finalColor =
        mix(
            baseColor,
            sketch,
            amount
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