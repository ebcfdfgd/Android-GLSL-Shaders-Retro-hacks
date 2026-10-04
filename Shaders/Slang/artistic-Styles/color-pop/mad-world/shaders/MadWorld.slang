#version 450

// ============================================================
// RetroArch Monochrome Ink + Red Isolation
// Converted from GLSL 110 to Slang 450
// ============================================================


// ============================================================
// Push Constants
// RetroArch Parameters
// ============================================================

layout(push_constant) uniform Push
{
    float MW_OUTLINE_STR;
    float MW_EDGE_SENS;
    float MW_WHITE_PROTECT;
    float MW_CONTRAST;
    float MW_THRESHOLD;
    float MW_RED_SENS;
} params;


// ============================================================
// RetroArch Menu Parameters
// ============================================================

#pragma parameter MW_OUTLINE_STR "Ink Outline Strength" 0.2 0.0 3.0 0.1
#pragma parameter MW_EDGE_SENS "Edge Detection Sensitivity" 1.0 0.1 5.0 0.1
#pragma parameter MW_WHITE_PROTECT "White Protection Threshold" 0.75 0.5 1.0 0.02
#pragma parameter MW_CONTRAST "Monochrome Contrast" 1.2 0.5 3.0 0.1
#pragma parameter MW_THRESHOLD "B&W Threshold" 0.4 0.1 0.9 0.05
#pragma parameter MW_RED_SENS "Red Detection Threshold" 0.5 0.1 0.8 0.05


// ============================================================
// RetroArch Global UBO
// ============================================================

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;

    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;

    uint FrameCount;
} global;


// ============================================================
// Vertex Stage
// ============================================================

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
        TexCoord;
}


// ============================================================
// Fragment Stage
// ============================================================

#pragma stage fragment

layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 2) uniform sampler2D Source;


// ============================================================
// Luminance
// ============================================================

const vec3 Y =
    vec3(
        0.299,
        0.587,
        0.114
    );


float getLuma(vec3 col)
{
    return dot(
        col,
        Y
    );
}


// ============================================================
// Optimized 4-Neighbor Edge Detection
// 4 neighbor fetches + 1 main fetch = 5 total fetches
// ============================================================

float detectSobelEdge(
    vec2 coords,
    vec2 px
)
{
    float top =
        getLuma(
            texture(
                Source,
                coords +
                px * vec2(
                    0.0,
                    -1.0
                )
            ).rgb
        );


    float left =
        getLuma(
            texture(
                Source,
                coords +
                px * vec2(
                    -1.0,
                    0.0
                )
            ).rgb
        );


    float right =
        getLuma(
            texture(
                Source,
                coords +
                px * vec2(
                    1.0,
                    0.0
                )
            ).rgb
        );


    float bottom =
        getLuma(
            texture(
                Source,
                coords +
                px * vec2(
                    0.0,
                    1.0
                )
            ).rgb
        );


    float gx =
        2.0 *
        (
            right -
            left
        );


    float gy =
        2.0 *
        (
            bottom -
            top
        );


    return sqrt(
        gx * gx +
        gy * gy
    );
}


// ============================================================
// Red Isolation Heuristic
// ============================================================

float isolateRed(vec3 col)
{
    float maxOther =
        max(
            col.g,
            col.b
        );


    float redDiff =
        col.r -
        maxOther;


    float isRed =
        smoothstep(
            params.MW_RED_SENS - 0.1,
            params.MW_RED_SENS + 0.1,
            redDiff
        );


    float maxC =
        max(
            col.r,
            maxOther
        );


    float minC =
        min(
            col.r,
            min(
                col.g,
                col.b
            )
        );


    float sat =
        (
            maxC > 0.0
        )
        ?
        (
            maxC - minC
        )
        /
        maxC
        :
        0.0;


    return
        isRed *
        smoothstep(
            0.25,
            0.5,
            sat
        );
}


// ============================================================
// Fragment Main
// ============================================================

void main()
{
    // ========================================================
    // Pixel Size
    // ========================================================

    vec2 px =
        1.0 /
        global.SourceSize.xy;


    // ========================================================
    // Main Scene Fetch
    // ========================================================

    vec3 scene =
        texture(
            Source,
            vTexCoord
        ).rgb;


    float luma =
        getLuma(
            scene
        );


    // ========================================================
    // 1. Raw Edge Calculation with Sensitivity
    // ========================================================

    float rawEdge =
        detectSobelEdge(
            vTexCoord,
            px
        )
        *
        params.MW_OUTLINE_STR
        *
        params.MW_EDGE_SENS;


    // ========================================================
    // 2. White Details Protection Mask
    // Suppresses black ink lines over pure/near-white pixels
    // ========================================================

    float whiteMask =
        smoothstep(
            params.MW_WHITE_PROTECT - 0.1,
            params.MW_WHITE_PROTECT + 0.05,
            luma
        );


    float protectedEdge =
        rawEdge *
        (
            1.0 -
            whiteMask
        );


    protectedEdge =
        clamp(
            protectedEdge,
            0.0,
            1.0
        );


    // ========================================================
    // 3. High-Contrast B&W Scene
    // ========================================================

    float bw =
        smoothstep(
            params.MW_THRESHOLD -
            (
                0.5 /
                params.MW_CONTRAST
            ),

            params.MW_THRESHOLD +
            (
                0.5 /
                params.MW_CONTRAST
            ),

            luma
        );


    vec3 bwColor =
        vec3(
            bw
        );


    // ========================================================
    // 4. Apply Protected Outline
    // ========================================================

    vec3 inkedBW =
        mix(
            bwColor,
            vec3(
                0.0
            ),
            protectedEdge
        );


    // ========================================================
    // Force strict clean white
    // for elements exceeding white protection threshold
    // ========================================================

    if (
        luma >=
        params.MW_WHITE_PROTECT
    )
    {
        inkedBW =
            vec3(
                1.0
            );
    }


    // ========================================================
    // 5. Isolated Red Pass
    // ========================================================

    float redMask =
        isolateRed(
            scene
        );


    vec3 pureRed =
        vec3(
            scene.r * 1.3,
            scene.g * 0.05,
            scene.b * 0.05
        );


    // ========================================================
    // Final Color
    // ========================================================

    vec3 finalColor =
        mix(
            inkedBW,
            pureRed,
            redMask
        );


    // ========================================================
    // Output
    // ========================================================

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