#version 450

#pragma parameter SGPT_BLEND_LEVEL "Blend Level" 1.0 0.0 1.0 0.05

// ===== Thermal - Heat Response =====
#pragma parameter th_black_level        "Thermal - Black Level"            0.02 0.0 0.2  0.01
#pragma parameter th_contrast           "Thermal - Heat Contrast"          1.20 0.5 2.5  0.02
#pragma parameter th_brightness         "Thermal - Sensor Gain"            1.05 0.5 1.5  0.02

// ===== Thermal - Palette Curve =====
#pragma parameter th_palette_stops      "Thermal - Palette Bands"          8.0  3.0 16.0 1.0
#pragma parameter th_palette_smooth     "Thermal - Palette Smoothness"     0.65 0.0 1.0 0.02

// ===== Thermal - Hotspot Bloom =====
#pragma parameter th_bloom_threshold    "Thermal - Hotspot Threshold"      0.70 0.0 1.0 0.02
#pragma parameter th_bloom_intensity    "Thermal - Hotspot Bloom"          0.35 0.0 1.5 0.02

// ===== Thermal - Sensor Noise =====
#pragma parameter grain_str             "Grain Strength"                   5.0 0.0 16.0 0.5

// ===== Thermal - Scanline =====
#pragma parameter th_scanline_amount    "Thermal - Scanline Amount"        0.12 0.0 0.5 0.02
#pragma parameter th_scanline_scale     "Thermal - Scanline Density"       2.0 1.0 4.0 0.5

// ===== Thermal - Edge Detection =====
#pragma parameter th_edge_sensitivity   "Thermal - Edge Sensitivity"       0.10 0.0 0.6 0.01
#pragma parameter th_edge_strength      "Thermal - Edge Strength"          0.20 0.0 1.0 0.02

// ===== Thermal - White Threshold =====
#pragma parameter th_edge_white_threshold "Thermal - Edge White Cutoff"    0.85 0.5 1.0 0.02

// ===== Thermal - Vignette =====
#pragma parameter th_vignette_strength  "Thermal - Vignette Strength"      0.35 0.0 1.5 0.02


// ============================================================================
// Push Constants
// ============================================================================

layout(push_constant) uniform Push
{
    float SGPT_BLEND_LEVEL;

    float th_black_level;
    float th_contrast;
    float th_brightness;

    float th_palette_stops;
    float th_palette_smooth;

    float th_bloom_threshold;
    float th_bloom_intensity;

    float grain_str;

    float th_scanline_amount;
    float th_scanline_scale;

    float th_edge_sensitivity;
    float th_edge_strength;

    float th_edge_white_threshold;

    float th_vignette_strength;
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
// Constants
// ============================================================================

const vec3 Y =
    vec3(
        0.299,
        0.587,
        0.114
    );


// ============================================================================
// Luma
// ============================================================================

float luma(vec3 c)
{
    return dot(c, Y);
}


// ============================================================================
// Film Grain / Sensor Noise
// ============================================================================

float filmGrain(vec2 uvCoord, float strength, float timer)
{
    float x =
        (uvCoord.x + 4.0) *
        (uvCoord.y + 4.0) *
        (
            (
                mod(timer, 800.0) +
                10.0
            ) *
            10.0
        );

    return (
        mod(
            (
                mod(x, 13.0) +
                1.0
            ) *
            (
                mod(x, 123.0) +
                1.0
            ),
            0.01
        ) -
        0.005
    ) *
    strength;
}


// ============================================================================
// Vignette
// ============================================================================

vec3 thVignette(vec3 c, vec2 texCoord)
{
    vec2 frame_scale =
        global.SourceSize.xy /
        global.OriginalSize.xy;

    vec2 norm_uv =
        texCoord *
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
        params.th_vignette_strength;

    return c * vignette;
}


// ============================================================================
// Scanline
// ============================================================================

float scanlinePattern(vec2 fragCoord, float scale)
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
// Thermal Ramp
// ============================================================================

vec3 thermalRamp(float t)
{
    const int N = 7;

    vec3 stops[N];

    stops[0] = vec3(0.00, 0.00, 0.02);
    stops[1] = vec3(0.15, 0.00, 0.35);
    stops[2] = vec3(0.40, 0.00, 0.55);
    stops[3] = vec3(0.85, 0.10, 0.10);
    stops[4] = vec3(1.00, 0.45, 0.00);
    stops[5] = vec3(1.00, 0.85, 0.10);
    stops[6] = vec3(1.00, 1.00, 0.90);

    float scaled =
        clamp(
            t,
            0.0,
            1.0
        ) *
        float(N - 1);

    int idx =
        int(
            floor(scaled)
        );

    float fracValue =
        scaled -
        float(idx);

    vec3 colorA =
        stops[0];

    vec3 colorB =
        stops[1];

    for (int i = 0; i < N - 1; i++)
    {
        if (idx == i)
        {
            colorA = stops[i];
            colorB = stops[i + 1];
        }
    }

    return mix(
        colorA,
        colorB,
        fracValue
    );
}


// ============================================================================
// Main
// ============================================================================

void main()
{
    // ========================================================================
    // 1. Texture Samples
    // ========================================================================

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

    vec3 U =
        texture(
            Source,
            uv + dy
        ).rgb;

    vec3 D =
        texture(
            Source,
            uv - dy
        ).rgb;


    // ========================================================================
    // 2. SGPT Blend
    // ========================================================================

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
    // 3. Heat Response
    // ========================================================================

    float heat =
        clamp(
            (
                luma(color) -
                params.th_black_level
            ) /
            max(
                1.0 -
                params.th_black_level,
                0.001
            ),

            0.0,
            1.0
        );

    heat *=
        params.th_brightness;

    heat =
        (
            heat -
            0.5
        ) *
        params.th_contrast +
        0.5;

    heat =
        clamp(
            heat,
            0.0,
            1.0
        );


    // ========================================================================
    // 4. Palette Bands
    // ========================================================================

    float bandedHeat =
        floor(
            heat *
            params.th_palette_stops +
            0.5
        ) /
        params.th_palette_stops;

    heat =
        mix(
            bandedHeat,
            heat,
            params.th_palette_smooth
        );


    // ========================================================================
    // 5. Thermal Ramp
    // ========================================================================

    vec3 res =
        thermalRamp(
            heat
        );


    // ========================================================================
    // 6. Hotspot Bloom
    // ========================================================================

    float heatL =
        luma(L);

    float heatR =
        luma(R);

    float heatU =
        luma(U);

    float heatD =
        luma(D);

    float avgHeat =
        (
            heatL +
            heatR +
            heatU +
            heatD
        ) *
        0.25;

    float bloomMask =
        smoothstep(
            params.th_bloom_threshold - 0.1,
            params.th_bloom_threshold + 0.1,
            avgHeat
        );

    res +=
        vec3(
            1.0,
            0.6,
            0.2
        ) *
        bloomMask *
        params.th_bloom_intensity;

    res =
        clamp(
            res,
            0.0,
            1.0
        );


    // ========================================================================
    // 7. Edge Detection
    // ========================================================================

    float edgeDetect =
        dot(
            abs(C - L) +
            abs(C - R) +
            abs(C - U) +
            abs(C - D),
            Y
        );

    float edgeMask =
        1.0 -
        smoothstep(
            0.0,
            max(
                params.th_edge_sensitivity,
                0.001
            ),
            edgeDetect
        );


    // ========================================================================
    // 8. White Protection
    // ========================================================================

    float srcLuma =
        luma(C);

    float whiteFade =
        1.0 -
        smoothstep(
            params.th_edge_white_threshold - 0.05,
            params.th_edge_white_threshold + 0.05,
            srcLuma
        );

    edgeMask *=
        whiteFade;

    res *=
        (
            1.0 -
            edgeMask *
            params.th_edge_strength
        );


    // ========================================================================
    // 9. Scanlines
    // ========================================================================

    float scan =
        scanlinePattern(
            uv *
            global.SourceSize.xy,

            params.th_scanline_scale
        );

    res *=
        mix(
            1.0,
            scan,
            params.th_scanline_amount
        );


    // ========================================================================
    // 10. Vignette
    // ========================================================================

    res =
        thVignette(
            res,
            uv
        );


    // ========================================================================
    // 11. Sensor Noise
    // ========================================================================

    float grain =
        filmGrain(
            uv,
            params.grain_str,
            float(global.FrameCount)
        );

    res +=
        grain;


    // ========================================================================
    // 12. Final Output
    // ========================================================================

    res =
        clamp(
            res,
            0.0,
            1.0
        );

    FragColor =
        vec4(
            res,
            1.0
        );
}