#version 110

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
#pragma parameter LINE_THRESHOLD        "Line Art Threshold"                0.15 0.0 1.0  0.01
#pragma parameter OUTLINE_STRENGTH      "Outline Strength"                  1.0  0.0 3.0  0.05

#if defined(VERTEX)

attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
uniform mat4 MVPMatrix;

void main() {
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

uniform float vt_black_level;
uniform float vt_contrast;
uniform float vt_brightness;
uniform float vt_saturation;

uniform float vt_theme_hue;
uniform float vt_leak_amount;
uniform float vt_leak_threshold;

uniform float vt_tint_strength;
uniform float vt_tone_balance;

uniform float grain_str;

uniform float scanline_amount;
uniform float scanline_scale;

uniform float vt_vignette_strength;

uniform float WHITE_PROTECT;
uniform float LINE_THRESHOLD;
uniform float OUTLINE_STRENGTH;

const vec3 Y = vec3(0.299, 0.587, 0.114);

float luma(vec3 c) {
    return dot(c, Y);
}

// Convert Hue (0.0 - 1.0) directly to RGB
vec3 hue2rgb(float h) {
    float r = clamp(abs(h * 6.0 - 3.0) - 1.0, 0.0, 1.0);
    float g = clamp(2.0 - abs(h * 6.0 - 2.0), 0.0, 1.0);
    float b = clamp(2.0 - abs(h * 6.0 - 4.0), 0.0, 1.0);
    return vec3(r, g, b);
}

float filmGrain(vec2 uv, float strength, float timer) {
    float x = (uv.x + 4.0) *
              (uv.y + 4.0) *
              ((mod(timer, 800.0) + 10.0) * 10.0);

    return (mod(
        (mod(x, 13.0) + 1.0) *
        (mod(x, 123.0) + 1.0),
        0.01
    ) - 0.005) * strength;
}

vec3 vtVignette(vec3 c, vec2 texCoord) {
    vec2 frame_scale = TextureSize / InputSize;
    vec2 norm_uv = texCoord * frame_scale;
    vec2 cc = norm_uv - 0.5;
    float dist = dot(cc, cc);
    float vignette = 1.0 - dist * vt_vignette_strength;
    return c * vignette;
}

float scanlinePattern(vec2 fragCoord, float scale) {
    float line = sin(
        fragCoord.y / scale * 3.14159
    );

    return line * 0.5 + 0.5;
}

void main() {
    vec2 dx = vec2(1.0 / TextureSize.x, 0.0);
    vec2 dy = vec2(0.0, 1.0 / TextureSize.y);

    // Base texture fetch
    vec3 C = texture2D(Texture, uv).rgb;
    vec3 color = C;

    // ============================================================
    // Faded Base Tone
    // ============================================================
    vec3 res = clamp(
        (color - vt_black_level) /
        max(1.0 - vt_black_level, 0.001),
        0.0,
        1.0
    );

    res *= vt_brightness;

    res =
        (res - 0.5) *
        vt_contrast +
        0.5;

    res = clamp(
        res,
        0.0,
        1.0
    );

    float lum = luma(res);

    res = mix(
        vec3(lum),
        res,
        vt_saturation
    );

    res = clamp(
        res,
        0.0,
        1.0
    );

    // ============================================================
    // Dynamic Split Tone (Driven by Master Color Hue)
    // ============================================================
    vec3 leakColor = hue2rgb(vt_theme_hue);
    vec3 highlightTint = hue2rgb(fract(vt_theme_hue + 0.05)) * 0.20;
    vec3 shadowTint = hue2rgb(fract(vt_theme_hue + 0.50)) * 0.12;

    float lum2 = luma(res);

    float shadowMask =
        1.0 - smoothstep(
            vt_tone_balance - 0.2,
            vt_tone_balance + 0.2,
            lum2
        );

    float highlightMask =
        1.0 - shadowMask;

    res +=
        shadowTint *
        shadowMask *
        vt_tint_strength;

    res +=
        highlightTint *
        highlightMask *
        vt_tint_strength;

    res = clamp(
        res,
        0.0,
        1.0
    );

    // ============================================================
    // Light Leak
    // ============================================================
    vec2 frame_scale =
        TextureSize / InputSize;

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
            vt_leak_threshold - 0.2,
            vt_leak_threshold + 0.2,
            1.0 - leakLuma
        );

    res +=
        leakColor *
        leakMask *
        leakVisibility *
        vt_leak_amount;

    res = clamp(
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
            grain_str,
            float(FrameCount)
        );

    res += grain;

    // ============================================================
    // Scanlines
    // ============================================================
    float scan =
        scanlinePattern(
            uv * TextureSize,
            scanline_scale
        );

    res *= mix(
        1.0,
        scan,
        scanline_amount
    );

    res = clamp(
        res,
        0.0,
        1.0
    );

    // ============================================================
    // Line Art & Outline Integration
    // ============================================================
    vec3 L = texture2D(Texture, uv - dx).rgb;
    vec3 R = texture2D(Texture, uv + dx).rgb;
    vec3 U = texture2D(Texture, uv - dy).rgb;
    vec3 D = texture2D(Texture, uv + dy).rgb;

    float maxChannel = max(C.r, max(C.g, C.b));

    float lumaL = dot(L, Y);
    float lumaR = dot(R, Y);
    float lumaU = dot(U, Y);
    float lumaD = dot(D, Y);

    float edge = abs(lumaL - lumaR) + abs(lumaU - lumaD);
    float line = smoothstep(LINE_THRESHOLD - 0.05, LINE_THRESHOLD + 0.05, edge);
    line = clamp(line * OUTLINE_STRENGTH, 0.0, 1.0);

    if (maxChannel >= WHITE_PROTECT) {
        line = 0.0;
    }

    vec3 finalColor = mix(res, vec3(0.0), line);

    // ============================================================
    // Output
    // ============================================================
    gl_FragColor =
        vec4(
            clamp(finalColor, 0.0, 1.0),
            1.0
        );
}

#endif