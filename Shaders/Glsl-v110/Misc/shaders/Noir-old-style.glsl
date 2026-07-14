/* RetroArch Noir Enhanced - Grain, Contrast, Saturation, Sepia, Bloom, Vignette */
#version 110

// RetroArch Parameters
#pragma parameter contrast "Contrast" 1.6 1.0 3.0 0.1
#pragma parameter saturation "Color Saturation" 0.0 0.0 3.0 0.1
#pragma parameter grain_strength "Film Grain Intensity" 0.05 0.0 0.2 0.01
#pragma parameter brightness "Base Brightness" 0.03 -0.5 0.5 0.02
#pragma parameter sepia "Sepia Tone Amount" 0.3 0.0 1.0 0.1
#pragma parameter bloom "Highlight Glow" 0.2 0.0 1.0 0.05
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
uniform vec2 InputSize; // Required for precise Vignette centering
uniform int FrameCount;

uniform float contrast;
uniform float saturation;
uniform float grain_strength;
uniform float brightness;
uniform float sepia;
uniform float bloom;
uniform float VIGNETTE_STR;

float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    // 1. Texture Fetch
    vec3 color = texture2D(Texture, uv).rgb;

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

    // 5. Highlight Glow (Bloom) - Linear Math
    vec3 safe_color = max(color, 0.0);
    color += (safe_color * safe_color * safe_color) * bloom;

    // 6. Contrast
    color = (color - 0.5) * contrast + 0.5;

    // 7. Film Grain
    float noise = (rand(uv) - 0.5) * grain_strength;
    color += noise;

    // 8. Sepia Tone Blending
    float final_luma = dot(color, vec3(0.299, 0.587, 0.114));
    vec3 sepiaColor = vec3(final_luma) * vec3(1.2, 1.1, 0.9);
    
    vec3 finalColor = mix(color, sepiaColor, sepia);

    gl_FragColor = vec4(clamp(finalColor, 0.0, 1.0), 1.0);
}
#endif