#version 450

/*
    VHS Signal & Degradation Shader (RetroArch Slang)
    --------------------------------------------------
    Temperature & Tint Added
*/

// ===== VHS Signal & Distortion =====
#pragma parameter vhs_chroma_ab      "VHS - Chromatic Aberration"        2.5    0.0 8.0  0.25
#pragma parameter vhs_color_bleed    "VHS - Color Bleed (Chroma Blur)"   1.5    0.0 5.0  0.25
#pragma parameter vhs_scanline_str   "VHS - Scanline Strength"         0.25   0.0 1.0  0.05
#pragma parameter vhs_tape_noise     "VHS - Tape Tracking Noise"       0.40   0.0 2.0  0.05
#pragma parameter vhs_jitter_str     "VHS - Horizontal Jitter"         0.80   0.0 3.0  0.10

// ===== Color Adjustments =====
#pragma parameter vhs_black_level    "VHS - Signal Fade (Black Lift)"  0.08   0.0 0.3  0.01
#pragma parameter vhs_contrast       "VHS - Contrast"                  0.95   0.5 1.5  0.02
#pragma parameter vhs_saturation     "VHS - Saturation"                0.80   0.0 2.0  0.05
#pragma parameter vhs_temp           "VHS - Color Temperature"         0.0   -1.0 1.0  0.05
#pragma parameter vhs_tint           "VHS - Color Tint"                0.0   -1.0 1.0  0.05


// ============================================================================
// Push Constants
// ============================================================================

layout(push_constant) uniform Push
{
    float vhs_chroma_ab;
    float vhs_color_bleed;
    float vhs_scanline_str;
    float vhs_tape_noise;
    float vhs_jitter_str;

    float vhs_black_level;
    float vhs_contrast;
    float vhs_saturation;
    float vhs_temp;
    float vhs_tint;
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
// Luminance
// ============================================================================

float luma(vec3 c)
{
    return dot(c, Y);
}


// ============================================================================
// Pseudo-random Number Generator
// ============================================================================

float hash(vec2 p)
{
    p =
        fract(
            p *
            vec2(
                123.34,
                456.21
            )
        );

    p +=
        dot(
            p,
            p + 45.32
        );

    return fract(
        p.x *
        p.y
    );
}


// ============================================================================
// VHS Tape Noise Generator
// Horizontal Bands + Static
// ============================================================================

float tapeNoise(
    vec2 uvCoord,
    float time
)
{
    float line =
        floor(
            uvCoord.y *
            global.SourceSize.y
        );

    float n1 =
        hash(
            vec2(
                line,
                floor(time)
            )
        );

    // Random thick horizontal static bands
    float band =
        smoothstep(
            0.98,
            1.0,
            sin(
                uvCoord.y * 10.0 +
                time * 0.05
            )
        );

    // Fine static noise
    float staticNoise =
        hash(
            uvCoord *
            global.SourceSize.xy +
            vec2(
                time,
                time * 1.5
            )
        );

    return mix(
        staticNoise * 0.15,
        staticNoise * 0.85,
        band
    );
}


// ============================================================================
// Main
// ============================================================================

void main()
{
    float time =
        float(
            global.FrameCount
        );

    vec2 texelSize =
        1.0 /
        global.SourceSize.xy;


    // ========================================================================
    // 1. Horizontal Scanline Jitter & Distortion
    // ========================================================================

    float lineY =
        floor(
            uv.y *
            global.SourceSize.y
        );

    float jitterRand =
        hash(
            vec2(
                lineY,
                floor(time * 0.5)
            )
        );

    // Occasional line offsets (sync loss effect)
    float jitterOffset = 0.0;

    if (jitterRand > 0.92)
    {
        jitterOffset =
            (
                hash(
                    vec2(
                        lineY * 2.0,
                        time
                    )
                ) -
                0.5
            ) *
            0.015 *
            params.vhs_jitter_str;
    }

    vec2 distortedUV =
        uv +
        vec2(
            jitterOffset,
            0.0
        );


    // ========================================================================
    // 2. Chromatic Aberration & Color Bleed
    // YIQ / Composite Style
    // ========================================================================

    vec2 abOffset =
        vec2(
            params.vhs_chroma_ab *
            texelSize.x,
            0.0
        );

    vec2 bleedOffset =
        vec2(
            params.vhs_color_bleed *
            texelSize.x,
            0.0
        );

    // Channel sample with horizontal displacement
    float r =
        texture(
            Source,
            distortedUV +
            abOffset
        ).r;

    float g =
        texture(
            Source,
            distortedUV
        ).g;

    float b =
        texture(
            Source,
            distortedUV -
            abOffset -
            bleedOffset
        ).b;

    vec3 res =
        vec3(
            r,
            g,
            b
        );


    // ========================================================================
    // 3. VHS Signal Degradation
    // Black Level / Contrast / Saturation / Temperature / Tint
    // ========================================================================

    res =
        clamp(
            (
                res -
                params.vhs_black_level
            ) /
            max(
                1.0 -
                params.vhs_black_level,
                0.001
            ),
            0.0,
            1.0
        );

    res =
        (
            res -
            0.5
        ) *
        params.vhs_contrast +
        0.5;

    float lum =
        luma(res);

    res =
        mix(
            vec3(lum),
            res,
            params.vhs_saturation
        );


    // Apply Color Temperature & Tint adjustments
    res.r +=
        params.vhs_temp * 0.15 -
        params.vhs_tint * 0.05;

    res.g +=
        params.vhs_tint * 0.15;

    res.b -=
        params.vhs_temp * 0.15 -
        params.vhs_tint * 0.05;

    res =
        clamp(
            res,
            0.0,
            1.0
        );


    // ========================================================================
    // 4. Tape Tracking Noise & Static Lines
    // ========================================================================

    if (params.vhs_tape_noise > 0.0)
    {
        float noiseVal =
            tapeNoise(
                distortedUV,
                time
            );

        res =
            mix(
                res,
                vec3(noiseVal),
                noiseVal *
                params.vhs_tape_noise *
                0.5
            );
    }


    // ========================================================================
    // 5. CRT Scanline Effect
    // ========================================================================

    if (params.vhs_scanline_str > 0.0)
    {
        float scanline =
            sin(
                distortedUV.y *
                global.SourceSize.y *
                3.14159
            );

        scanline =
            1.0 -
            (
                0.5 *
                (1.0 + scanline) *
                params.vhs_scanline_str
            );

        res *=
            scanline;
    }


    // ========================================================================
    // Final Output
    // ========================================================================

    FragColor =
        vec4(
            clamp(
                res,
                0.0,
                1.0
            ),
            1.0
        );
}