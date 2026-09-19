```glsl
#version 110

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

#if defined(VERTEX)

attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
uniform mat4 MVPMatrix;

void main()
{
    uv = TexCoord;
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)

#ifdef GL_ES
precision highp float;
#endif

varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform vec2 InputSize;
uniform int FrameCount;

uniform float th_black_level;
uniform float th_contrast;
uniform float th_brightness;

uniform float th_palette_stops;
uniform float th_palette_smooth;

uniform float th_bloom_threshold;
uniform float th_bloom_intensity;

uniform float grain_str;

uniform float th_scanline_amount;
uniform float th_scanline_scale;

uniform float th_edge_sensitivity;
uniform float th_edge_strength;

uniform float th_edge_white_threshold;

uniform float th_vignette_strength;

const vec3 Y = vec3(0.299, 0.587, 0.114);

float luma(vec3 c)
{
    return dot(c, Y);
}

// ============================================================
// Film Grain / Sensor Noise
// ============================================================
float filmGrain(vec2 uv, float strength, float timer)
{
    float x =
        (uv.x + 4.0) *
        (uv.y + 4.0) *
        ((mod(timer, 800.0) + 10.0) * 10.0);

    return (
        mod(
            (mod(x, 13.0) + 1.0) *
            (mod(x, 123.0) + 1.0),
            0.01
        ) - 0.005
    ) * strength;
}

// ============================================================
// Vignette
// ============================================================
vec3 thVignette(vec3 c, vec2 texCoord)
{
    vec2 frame_scale =
        TextureSize / InputSize;

    vec2 norm_uv =
        texCoord * frame_scale;

    vec2 cc =
        norm_uv - 0.5;

    float dist =
        dot(cc, cc);

    float vignette =
        1.0 -
        dist * th_vignette_strength;

    return c * vignette;
}

// ============================================================
// Scanline
// ============================================================
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

// ============================================================
// Thermal Ramp
// ============================================================
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
        clamp(t, 0.0, 1.0) *
        float(N - 1);

    int idx =
        int(floor(scaled));

    float frac =
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
        frac
    );
}

void main()
{
    // ========================================================
    // Texture Samples
    // ========================================================

    vec2 dx =
        vec2(
            1.0 / TextureSize.x,
            0.0
        );

    vec2 dy =
        vec2(
            0.0,
            1.0 / TextureSize.y
        );

    vec3 C =
        texture2D(
            Texture,
            uv
        ).rgb;

    vec3 L =
        texture2D(
            Texture,
            uv - dx
        ).rgb;

    vec3 R =
        texture2D(
            Texture,
            uv + dx
        ).rgb;

    vec3 U =
        texture2D(
            Texture,
            uv + dy
        ).rgb;

    vec3 D =
        texture2D(
            Texture,
            uv - dy
        ).rgb;

    vec3 color =
        C;

    // ========================================================
    // 1. Heat Response
    // ========================================================

    float heat =
        clamp(
            (
                luma(color) -
                th_black_level
            ) /
            max(
                1.0 -
                th_black_level,
                0.001
            ),
            0.0,
            1.0
        );

    heat *=
        th_brightness;

    heat =
        (
            heat - 0.5
        ) *
        th_contrast +
        0.5;

    heat =
        clamp(
            heat,
            0.0,
            1.0
        );

    // ========================================================
    // 2. Palette Bands
    // ========================================================

    float bandedHeat =
        floor(
            heat *
            th_palette_stops +
            0.5
        ) /
        th_palette_stops;

    heat =
        mix(
            bandedHeat,
            heat,
            th_palette_smooth
        );

    // ========================================================
    // 3. Thermal Ramp
    // ========================================================

    vec3 res =
        thermalRamp(
            heat
        );

    // ========================================================
    // 4. Hotspot Bloom
    // ========================================================

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
        ) * 0.25;

    float bloomMask =
        smoothstep(
            th_bloom_threshold - 0.1,
            th_bloom_threshold + 0.1,
            avgHeat
        );

    res +=
        vec3(
            1.0,
            0.6,
            0.2
        ) *
        bloomMask *
        th_bloom_intensity;

    res =
        clamp(
            res,
            0.0,
            1.0
        );

    // ========================================================
    // 5. Edge Detection
    // Single Sensitivity Parameter
    // ========================================================

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
                th_edge_sensitivity,
                0.001
            ),
            edgeDetect
        );

    // ========================================================
    // 6. White Protection
    // Single White Cutoff
    // ========================================================

    float srcLuma =
        luma(C);

    float whiteFade =
        1.0 -
        smoothstep(
            th_edge_white_threshold - 0.05,
            th_edge_white_threshold + 0.05,
            srcLuma
        );

    edgeMask *=
        whiteFade;

    res *=
        (
            1.0 -
            edgeMask *
            th_edge_strength
        );

    // ========================================================
    // 7. Scanlines
    // ========================================================

    float scan =
        scanlinePattern(
            uv * TextureSize,
            th_scanline_scale
        );

    res *=
        mix(
            1.0,
            scan,
            th_scanline_amount
        );

    // ========================================================
    // 8. Vignette
    // ========================================================

    res =
        thVignette(
            res,
            uv
        );

    // ========================================================
    // 9. Sensor Noise
    // ========================================================

    float grain =
        filmGrain(
            uv,
            grain_str,
            float(FrameCount)
        );

    res +=
        grain;

    // ========================================================
    // 10. Final Output
    // ========================================================

    res =
        clamp(
            res,
            0.0,
            1.0
        );

    gl_FragColor =
        vec4(
            res,
            1.0
        );
}

#endif