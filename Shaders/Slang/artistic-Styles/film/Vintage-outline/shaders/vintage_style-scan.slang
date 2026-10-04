#version 450

// ===== Vintage - Faded Base Tone =====
#pragma parameter vt_black_level        "Vintage - Black Lift (Fade)"       0.10 0.0 0.3  0.01
#pragma parameter vt_contrast           "Vintage - Soft Contrast"           0.90 0.5 1.8  0.02
#pragma parameter vt_brightness         "Vintage - Brightness"              1.05 0.5 1.5  0.02
#pragma parameter vt_saturation         "Vintage - Faded Saturation"        0.70 0.0 1.5  0.02

// ===== Vintage - Master Color Theme =====
#pragma parameter vt_theme_hue          "Vintage - Master Color Hue"        0.08 0.0 1.0  0.01

// ===== Vintage - Light Leak =====
#pragma parameter vt_leak_amount        "Vintage - Light Leak Amount"       0.18 0.0 0.6  0.02
#pragma parameter vt_leak_threshold     "Vintage - Light Leak Threshold"    0.55 0.0 1.0  0.02

// ===== Vintage - Split Tone Intensity =====
#pragma parameter vt_tint_strength      "Vintage - Color Tint Strength"     0.30 -1.0 1.0  0.05
#pragma parameter vt_tone_balance       "Vintage - Tone Balance"            0.50 0.2 0.8  0.02

// ===== Vintage - Grain =====
#pragma parameter grain_str             "Grain Strength"                    2.5  0.0 16.0 0.5

// ===== Scanlines =====
#pragma parameter scanline_amount       "Scanline Amount"                   0.12 0.0 0.5 0.02
#pragma parameter scanline_scale        "Scanline Density"                  2.0  1.0 4.0 0.5

// ===== Vintage - Vignette =====
#pragma parameter vt_vignette_strength  "Vintage - Vignette Strength"       0.35 0.0 1.5  0.02

// ===== Line Art & Outline =====
#pragma parameter WHITE_PROTECT         "White Protection Threshold"        0.80 0.5 1.0  0.01
#pragma parameter LINE_THRESHOLD         "Line Art Threshold"                0.15 0.0 1.0  0.01
#pragma parameter OUTLINE_STRENGTH       "Outline Strength"                  1.0  0.0 3.0  0.05

layout(push_constant) uniform Push
{
    float vt_black_level;
    float vt_contrast;
    float vt_brightness;
    float vt_saturation;

    float vt_theme_hue;
    float vt_leak_amount;
    float vt_leak_threshold;

    float vt_tint_strength;
    float vt_tone_balance;

    float grain_str;

    float scanline_amount;
    float scanline_scale;

    float vt_vignette_strength;

    float WHITE_PROTECT;
    float LINE_THRESHOLD;
    float OUTLINE_STRENGTH;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
} global;

#pragma stage vertex

layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;

layout(location = 0) out vec2 uv;

void main()
{
    uv = TexCoord;
    gl_Position = global.MVP * Position;
}

#pragma stage fragment

layout(location = 0) in vec2 uv;
layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 2) uniform sampler2D Source;

const vec3 Y = vec3(0.299, 0.587, 0.114);

float luma(vec3 c)
{
    return dot(c, Y);
}

// Convert Hue (0.0 - 1.0) directly to RGB
vec3 hue2rgb(float h)
{
    float r = clamp(abs(h * 6.0 - 3.0) - 1.0, 0.0, 1.0);
    float g = clamp(2.0 - abs(h * 6.0 - 2.0), 0.0, 1.0);
    float b = clamp(2.0 - abs(h * 6.0 - 4.0), 0.0, 1.0);

    return vec3(r, g, b);
}

float filmGrain(vec2 coord, float strength, float timer)
{
    float x = (coord.x + 4.0) *
              (coord.y + 4.0) *
              ((mod(timer, 800.0) + 10.0) * 10.0);

    return
        (
            mod(
                (mod(x, 13.0) + 1.0) *
                (mod(x, 123.0) + 1.0),
                0.01
            ) - 0.005
        ) * strength;
}

vec3 vtVignette(vec3 c, vec2 texCoord)
{
    vec2 frame_scale =
        global.SourceSize.xy /
        global.OriginalSize.xy;

    vec2 norm_uv =
        texCoord * frame_scale;

    vec2 cc =
        norm_uv - 0.5;

    float dist =
        dot(cc, cc);

    float vignette =
        1.0 - dist * params.vt_vignette_strength;

    return c * vignette;
}

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

void main()
{
    vec2 dx =
        vec2(
            1.0 / global.SourceSize.x,
            0.0
        );

    vec2 dy =
        vec2(
            0.0,
            1.0 / global.SourceSize.y
        );

    // Base texture fetch
    vec3 C =
        texture(Source, uv).rgb;

    vec3 color = C;

    // ============================================================
    // Faded Base Tone
    // ============================================================
    vec3 res =
        clamp(
            (color - params.vt_black_level) /
            max(1.0 - params.vt_black_level, 0.001),
            0.0,
            1.0
        );

    res *= params.vt_brightness;

    res =
        (res - 0.5) *
        params.vt_contrast +
        0.5;

    res =
        clamp(
            res,
            0.0,
            1.0
        );

    float lum =
        luma(res);

    res =
        mix(
            vec3(lum),
            res,
            params.vt_saturation
        );

    res =
        clamp(
            res,
            0.0,
            1.0
        );

    // ============================================================
    // Dynamic Split Tone (Driven by Master Color Hue)
    // ============================================================
    vec3 leakColor =
        hue2rgb(params.vt_theme_hue);

    vec3 highlightTint =
        hue2rgb(
            fract(params.vt_theme_hue + 0.05)
        ) * 0.20;

    vec3 shadowTint =
        hue2rgb(
            fract(params.vt_theme_hue + 0.50)
        ) * 0.12;

    float lum2 =
        luma(res);

    float shadowMask =
        1.0 -
        smoothstep(
            params.vt_tone_balance - 0.2,
            params.vt_tone_balance + 0.2,
            lum2
        );

    float highlightMask =
        1.0 - shadowMask;

    res +=
        shadowTint *
        shadowMask *
        params.vt_tint_strength;

    res +=
        highlightTint *
        highlightMask *
        params.vt_tint_strength;

    res =
        clamp(
            res,
            0.0,
            1.0
        );

    // ============================================================
    // Light Leak
    // ============================================================
    vec2 frame_scale =
        global.SourceSize.xy /
        global.OriginalSize.xy;

    vec2 norm_uv =
        uv * frame_scale;

    float leakDist =
        distance(
            norm_uv,
            vec2(0.85, 0.15)
        );

    float leakMask =
        1.0 -
        smoothstep(
            0.0,
            0.7,
            leakDist
        );

    float leakLuma =
        luma(res);

    float leakVisibility =
        smoothstep(
            params.vt_leak_threshold - 0.2,
            params.vt_leak_threshold + 0.2,
            1.0 - leakLuma
        );

    res +=
        leakColor *
        leakMask *
        leakVisibility *
        params.vt_leak_amount;

    res =
        clamp(
            res,
            0.0,
            1.0
        );

    // ============================================================
    // Vignette
    // ============================================================
    res =
        vtVignette(
            res,
            uv
        );

    // ============================================================
    // Grain
    // ============================================================
    float grain =
        filmGrain(
            uv,
            params.grain_str,
            float(global.FrameCount)
        );

    res += grain;

    // ============================================================
    // Scanlines
    // ============================================================
    float scan =
        scanlinePattern(
            uv * global.SourceSize.xy,
            params.scanline_scale
        );

    res *=
        mix(
            1.0,
            scan,
            params.scanline_amount
        );

    res =
        clamp(
            res,
            0.0,
            1.0
        );

    // ============================================================
    // Line Art & Outline Integration
    // ============================================================
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

    float maxChannel =
        max(
            C.r,
            max(C.g, C.b)
        );

    float lumaL =
        dot(L, Y);

    float lumaR =
        dot(R, Y);

    float lumaU =
        dot(U, Y);

    float lumaD =
        dot(D, Y);

    float edge =
        abs(lumaL - lumaR) +
        abs(lumaU - lumaD);

    float line =
        smoothstep(
            params.LINE_THRESHOLD - 0.05,
            params.LINE_THRESHOLD + 0.05,
            edge
        );

    line =
        clamp(
            line * params.OUTLINE_STRENGTH,
            0.0,
            1.0
        );

    if (maxChannel >= params.WHITE_PROTECT)
    {
        line = 0.0;
    }

    vec3 finalColor =
        mix(
            res,
            vec3(0.0),
            line
        );

    // ============================================================
    // Final Output
    // ============================================================
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