#version 450

#pragma parameter SGPT_BLEND_LEVEL "Blend Level" 1.0 0.0 1.0 0.05
#pragma parameter ENABLE_MONO "Monochrome / B&W Mode (0=Off, 1=On)" 0.0 0.0 1.0 1.0
#pragma parameter COLOR_SATURATION "Color Saturation (Cartoon Pop)" 1.5 0.0 3.0 0.05
#pragma parameter LINE_THRESHOLD "Line Art Threshold" 0.15 0.0 1.0 0.01
#pragma parameter WHITE_PROTECT "White Protection Threshold" 0.80 0.5 1.0 0.01
#pragma parameter LINE_SMOOTHNESS "Line Smoothness (Vector Anti-aliasing)" 0.05 0.0 1.0 0.05
#pragma parameter EDGE_CONTRAST "Edge Contrast Multiplier" 1.0 0.5 2.0 0.1
#pragma parameter OUTLINE_STRENGTH "Outline Strength" 1.0 0.0 3.0 0.05
#pragma parameter COLOR_LEVELS "Color Reduction Levels (0 = Off)" 0.0 0.0 32.0 1.0


// ============================================================================
// Push Constants
// ============================================================================

layout(push_constant) uniform Push
{
    float SGPT_BLEND_LEVEL;
    float ENABLE_MONO;
    float COLOR_SATURATION;
    float LINE_THRESHOLD;
    float WHITE_PROTECT;
    float LINE_SMOOTHNESS;
    float EDGE_CONTRAST;
    float OUTLINE_STRENGTH;
    float COLOR_LEVELS;
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
    vec2 dx =
        vec2(
            1.0 /
            global.SourceSize.x,
            0.0
        );

    vec2 dy =
        vec2(
            0.0,
            1.0 /
            global.SourceSize.y
        );


    // ========================================================================
    // [1] Fetch Center Pixel
    // ========================================================================

    vec3 C =
        texture(
            Source,
            uv
        ).rgb;


    // ========================================================================
    // [2] White Protection
    // ========================================================================

    float maxChannel =
        max(
            C.r,
            max(
                C.g,
                C.b
            )
        );

    if (maxChannel >= params.WHITE_PROTECT)
    {
        FragColor =
            vec4(
                C,
                1.0
            );

        return;
    }


    // ========================================================================
    // Fetch Surrounding Pixels
    // ========================================================================

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

    vec3 U =
        texture(
            Source,
            uv - dy
        ).rgb;

    vec3 D =
        texture(
            Source,
            uv + dy
        ).rgb;


    // ========================================================================
    // [3] SGPT Blend Logic
    // ========================================================================

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

    vec3 color;

    if (wR < wL)
    {
        color =
            C -
            0.5 *
            params.SGPT_BLEND_LEVEL *
            diffR;
    }
    else
    {
        color =
            C -
            0.5 *
            params.SGPT_BLEND_LEVEL *
            diffL;
    }

    color =
        clamp(
            color,
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
    // [4] Color Processing
    // ========================================================================

    if (params.ENABLE_MONO > 0.5)
    {
        color =
            vec3(
                dot(color, Y)
            );
    }
    else
    {
        float lumaVal =
            dot(
                color,
                Y
            );

        color =
            mix(
                vec3(lumaVal),
                color,
                params.COLOR_SATURATION
            );
    }


    // ========================================================================
    // [5] Color Reduction / Posterization
    // ========================================================================

    if (params.COLOR_LEVELS > 1.0)
    {
        color =
            floor(
                color *
                params.COLOR_LEVELS +
                0.5
            ) /
            params.COLOR_LEVELS;
    }


    // ========================================================================
    // [6] Advanced Line Art Features
    // ========================================================================

    float lumaL =
        dot(
            L,
            Y
        );

    float lumaR =
        dot(
            R,
            Y
        );

    float lumaU =
        dot(
            U,
            Y
        );

    float lumaD =
        dot(
            D,
            Y
        );


    float edge =
        (
            abs(lumaL - lumaR) +
            abs(lumaU - lumaD)
        ) *
        params.EDGE_CONTRAST;


    float line =
        smoothstep(
            params.LINE_THRESHOLD -
            params.LINE_SMOOTHNESS,

            params.LINE_THRESHOLD +
            params.LINE_SMOOTHNESS,

            edge
        );


    // ========================================================================
    // [7] Apply Outline Strength
    // ========================================================================

    line =
        clamp(
            line *
            params.OUTLINE_STRENGTH,
            0.0,
            1.0
        );


    // ========================================================================
    // [8] Final Compositing
    // ========================================================================

    vec3 finalColor =
        mix(
            color,
            vec3(0.0),
            line
        );


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