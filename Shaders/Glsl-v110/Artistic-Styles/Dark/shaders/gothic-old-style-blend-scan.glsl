#version 110

/* RetroArch Gothic Crypt Enhanced
   Halation with Threshold, Black Lift, Smooth Texture Fetch,
   Animated Film Grain + Scanlines
*/

// RetroArch Parameters
#pragma parameter contrast "Contrast" 1.8 1.0 3.0 0.1
#pragma parameter saturation "Color Saturation" 0.9 0.0 3.0 0.1
#pragma parameter grain_str "Grain Strength" 16.0 0.0 32.0 1.0
#pragma parameter brightness "Base Brightness" -0.02 -0.5 0.5 0.02
#pragma parameter gothic_tint "Gothic Cold Tint Amount" 0.5 0.0 1.0 0.1
#pragma parameter de_dither "De-Dither Intensity" 1.0 0.0 1.0 0.1
#pragma parameter halation "Film Halation Bleed" 0.2 0.0 1.0 0.05
#pragma parameter halation_threshold "Halation Threshold" 0.7 0.0 1.0 0.05
#pragma parameter black_lift "Black Lift (Shadow Floor)" 0.03 0.0 0.15 0.01
#pragma parameter VIGNETTE_STR "Vignette Strength" 0.6 0.0 1.5 0.05

// ===== Scanlines =====
#pragma parameter scanline_amount "Scanline Amount" 0.12 0.0 0.5 0.02
#pragma parameter scanline_scale "Scanline Density" 1.0 1.0 4.0 0.5

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

uniform float contrast;
uniform float saturation;
uniform float grain_str;
uniform float brightness;
uniform float gothic_tint;
uniform float de_dither;
uniform float halation;
uniform float halation_threshold;
uniform float black_lift;
uniform float VIGNETTE_STR;

uniform float scanline_amount;
uniform float scanline_scale;

// ============================================================
// Exact animated film noise
// ============================================================

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

// ============================================================
// Scanline
// No texture fetch
// ============================================================

float scanlinePattern(vec2 fragCoord, float scale) {
    float line = sin(
        fragCoord.y / scale * 3.14159
    );

    return line * 0.5 + 0.5;
}

void main() {

    // 1. Advanced Multi-Tap Texture Fetch / De-Dither
    vec2 texelSize = 1.0 / TextureSize;

    vec3 col_center =
        texture2D(Texture, uv).rgb;

    vec3 col_left =
        texture2D(
            Texture,
            uv - vec2(texelSize.x, 0.0)
        ).rgb;

    vec3 col_right =
        texture2D(
            Texture,
            uv + vec2(texelSize.x, 0.0)
        ).rgb;

    // Smooth texture blending
    vec3 smoothed_color =
        (col_center * 2.0 +
         col_left +
         col_right) * 0.25;

    vec3 color =
        mix(
            col_center,
            smoothed_color,
            de_dither
        );

    // 2. Base Brightness
    color += brightness;

    // 3. Heavy Gothic Vignette
    vec2 frame_scale =
        TextureSize / InputSize;

    vec2 norm_uv =
        uv * frame_scale;

    vec2 cc =
        norm_uv - 0.5;

    float dist =
        dot(cc, cc);

    float vignette =
        1.0 -
        dist * VIGNETTE_STR;

    color *= vignette;

    // 4. Saturation Adjustment
    float luma =
        dot(
            color,
            vec3(0.299, 0.587, 0.114)
        );

    color =
        mix(
            vec3(luma),
            color,
            saturation
        );

    // 5. Film Halation
    vec3 bright_pass =
        max(
            color -
            halation_threshold,
            0.0
        );

    vec3 halation_bleed =
        (
            texture2D(
                Texture,
                uv + texelSize * 1.5
            ).rgb
            +
            texture2D(
                Texture,
                uv - texelSize * 1.5
            ).rgb
        ) * 0.5;

    color +=
        max(
            halation_bleed,
            0.0
        ) *
        bright_pass *
        halation;

    // 6. High Contrast & Black Lift
    color =
        (color - 0.5) *
        contrast +
        0.5;

    color =
        max(
            color,
            black_lift
        );

    // 7. Animated Film Grain
    float noise =
        filmGrain(
            uv,
            grain_str,
            float(FrameCount)
        );

    color += noise;

    // 8. Gothic Cold Moonlight / Crypt Tint
    float final_luma =
        dot(
            color,
            vec3(0.299, 0.587, 0.114)
        );

    vec3 gothicColor =
        vec3(final_luma) *
        vec3(0.8, 0.9, 1.25);

    vec3 finalColor =
        mix(
            color,
            gothicColor,
            gothic_tint
        );

    // ============================================================
    // 9. Scanlines
    // No additional texture fetch
    // ============================================================

    float scan =
        scanlinePattern(
            uv * TextureSize,
            scanline_scale
        );

    finalColor *= mix(
        1.0,
        scan,
        scanline_amount
    );

    // 10. Output
    gl_FragColor =
        vec4(
            clamp(
                finalColor,
                0.0,
                1.0
            ),
            1.0
        );
}

#endif