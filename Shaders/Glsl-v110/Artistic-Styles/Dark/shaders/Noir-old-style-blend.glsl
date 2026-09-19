/* RetroArch Noir Enhanced with De-Dither & Black Lift - Animated Film Grain, Contrast, Saturation, Sepia, De-Dither, Halation, Vignette */
#version 110

// RetroArch Parameters
#pragma parameter contrast "Contrast" 1.6 1.0 3.0 0.1
#pragma parameter saturation "Color Saturation" 0.0 0.0 3.0 0.1
#pragma parameter grain_str "Grain Strength" 16.0 0.0 32.0 1.0
#pragma parameter brightness "Base Brightness" 0.03 -0.5 0.5 0.02
#pragma parameter sepia "Sepia Tone Amount" 0.3 0.0 1.0 0.1
#pragma parameter de_dither "De-Dither Intensity" 1.0 0.0 1.0 0.1
#pragma parameter halation "Film Halation Bleed" 0.3 0.0 1.0 0.05
#pragma parameter halation_threshold "Halation Threshold" 0.7 0.0 1.0 0.05
#pragma parameter black_lift "Black Lift (Shadow Floor)" 0.03 0.0 0.15 0.01
#pragma parameter VIGNETTE_STR "Vignette Strength" 0.35 0.0 1.5 0.05

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
uniform float sepia;
uniform float de_dither;
uniform float halation;
uniform float halation_threshold;
uniform float black_lift;
uniform float VIGNETTE_STR;

// Exact animated film noise
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

void main() {
    // 1. De-Dither Processing
    vec2 texelSize = vec2(1.0 / TextureSize.x, 0.0);
    vec3 color1 = texture2D(Texture, uv).rgb;
    vec3 color2 = texture2D(Texture, uv + texelSize).rgb;
    
    vec3 color = mix(
        color1,
        (color1 + color2) * 0.5,
        de_dither
    );

    // 2. Base Brightness
    color += brightness;

    // 3. Exact Vignette Logic (Flat, No Geometric Curve)
    vec2 frame_scale = TextureSize / InputSize;
    vec2 norm_uv = uv * frame_scale;
    vec2 cc = norm_uv - 0.5;
    float dist = dot(cc, cc);
    float vignette = 1.0 - dist * VIGNETTE_STR;
    color *= vignette;

    // 4. Saturation Adjustment
    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    color = mix(vec3(luma), color, saturation);

    // 5. Film Halation (Organic Highlight Bleed)
    vec3 bright_pass = max(color - halation_threshold, 0.0);
    vec3 halation_bleed =
        texture2D(
            Texture,
            uv + texelSize * 1.5
        ).rgb;

    color +=
        max(halation_bleed, 0.0) *
        bright_pass *
        halation;

    // 6. Contrast & Black Lift Control
    color = (color - 0.5) * contrast + 0.5;
    color = max(color, black_lift);

    // 7. Animated Film Grain
    float noise = filmGrain(
        uv,
        grain_str,
        float(FrameCount)
    );

    color += noise;

    // 8. Sepia Tone Blending
    float final_luma =
        dot(
            color,
            vec3(0.299, 0.587, 0.114)
        );

    vec3 sepiaColor =
        vec3(final_luma) *
        vec3(1.2, 1.1, 0.9);
    
    vec3 finalColor =
        mix(
            color,
            sepiaColor,
            sepia
        );

    gl_FragColor =
        vec4(
            clamp(finalColor, 0.0, 1.0),
            1.0
        );
}
#endif