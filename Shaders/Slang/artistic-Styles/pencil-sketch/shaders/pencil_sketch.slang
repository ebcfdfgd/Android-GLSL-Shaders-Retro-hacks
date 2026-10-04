#version 450

#pragma parameter PS_BLUR       "Blur Radius (px)"        2.0   0.5 8.0   0.1
#pragma parameter PS_STRENGTH   "Strength"                80.0 0.0 100.0 5.0
#pragma parameter PS_BRIGHTNESS "Pencil Brightness"       0.0  -1.0 1.0   0.05


// ============================================================================
// Push Constants
// ============================================================================

layout(push_constant) uniform Push
{
    float PS_BLUR;
    float PS_STRENGTH;
    float PS_BRIGHTNESS;
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
// Luma Sample
// ============================================================================

float lumaAt(vec2 sampleUv)
{
    return dot(
        texture(
            Source,
            sampleUv
        ).rgb,
        Y
    );
}


// ============================================================================
// Main
// ============================================================================

void main()
{
    vec2 texel =
        params.PS_BLUR /
        global.SourceSize.xy;


    // ========================================================================
    // [1] Sample original color and compute 0-saturation grayscale base
    // ========================================================================

    vec3 original =
        texture(
            Source,
            uv
        ).rgb;

    float gray =
        dot(
            original,
            Y
        );

    vec3 baseGray =
        vec3(gray);


    // ========================================================================
    // [2] 4-tap cross blur + center (5 taps total)
    //     on inverted grayscale
    // ========================================================================

    float invGray =
        1.0 -
        gray;

    float sum =
        invGray;

    sum +=
        1.0 -
        lumaAt(
            uv +
            texel *
            vec2(
                1.0,
                0.0
            )
        );

    sum +=
        1.0 -
        lumaAt(
            uv +
            texel *
            vec2(
                -1.0,
                0.0
            )
        );

    sum +=
        1.0 -
        lumaAt(
            uv +
            texel *
            vec2(
                0.0,
                1.0
            )
        );

    sum +=
        1.0 -
        lumaAt(
            uv +
            texel *
            vec2(
                0.0,
                -1.0
            )
        );

    float blurredInv =
        sum /
        5.0;


    // ========================================================================
    // [3] Color Dodge: base / (1 - blend)
    // ========================================================================

    float sketch =
        gray /
        max(
            1.0 -
            blurredInv,
            0.004
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
            params.PS_BRIGHTNESS,
            0.0,
            1.0
        );

    vec3 sketchColor =
        vec3(sketch);


    // ========================================================================
    // [5] Mix with grayscale base
    //     0 saturation at strength = 0
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
            baseGray,
            sketchColor,
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