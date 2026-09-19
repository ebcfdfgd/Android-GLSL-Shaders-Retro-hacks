/* RetroArch Gothic Crypt Enhanced - No Dither, Halation, Black Lift, Animated Film Grain */
#version 110

// RetroArch Parameters
#pragma parameter contrast "Contrast" 1.8 1.0 3.0 0.1
#pragma parameter saturation "Color Saturation" 0.9 0.0 3.0 0.1
#pragma parameter grain_str "Grain Strength" 16.0 0.0 32.0 1.0
#pragma parameter brightness "Base Brightness" -0.02 -0.5 0.5 0.02
#pragma parameter gothic_tint "Gothic Cold Tint Amount" 0.5 0.0 1.0 0.1
#pragma parameter halation "Film Halation Bleed" 0.3 0.0 1.0 0.05
#pragma parameter halation_threshold "Halation Threshold" 0.7 0.0 1.0 0.05
#pragma parameter black_lift "Black Lift (Shadow Floor)" 0.03 0.0 0.15 0.01
#pragma parameter VIGNETTE_STR "Vignette Strength" 0.6 0.0 1.5 0.05

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
uniform float halation;
uniform float halation_threshold;
uniform float black_lift;
uniform float VIGNETTE_STR;


// ============================================================
// Exact animated film noise from your original code
// ============================================================

float filmGrain(vec2 uv, float strength, float timer) {
    float x = (uv.x + 4.0) * (uv.y + 4.0) * ((mod(timer, 800.0) + 10.0) * 10.0);
    return (mod((mod(x, 13.0) + 1.0) * (mod(x, 123.0) + 1.0), 0.01) - 0.005) * strength;
}


void main() {
    // 1. Direct Texture Fetch (Raw Pixel Aesthetic, No Dither Smear)
    vec2 texelSize = 1.0 / TextureSize;
    vec3 color = texture2D(Texture, uv).rgb;

    // 2. Base Brightness
    color += brightness;

    // 3. Heavy Gothic Vignette
    vec2 frame_scale = TextureSize / InputSize;
    vec2 norm_uv = uv * frame_scale;
    vec2 cc = norm_uv - 0.5;
    float dist = dot(cc, cc);
    float vignette = 1.0 - dist * VIGNETTE_STR;
    color *= vignette;

    // 4. Saturation Adjustment
    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    color = mix(vec3(luma), color, saturation);

    // 5. Film Halation (Organic Highlight Bleed with custom Threshold)
    vec3 bright_pass = max(color - halation_threshold, 0.0);
    vec3 halation_bleed = (texture2D(Texture, uv + texelSize * 1.5).rgb + texture2D(Texture, uv - texelSize * 1.5).rgb) * 0.5;
    color += max(halation_bleed, 0.0) * bright_pass * halation;

    // 6. High Contrast & Controlled Black Lift (Prevents total blackout)
    color = (color - 0.5) * contrast + 0.5;
    color = max(color, black_lift); // Controlled floor to keep dungeon details visible

    // 7. Animated Film Grain
    float noise = filmGrain(uv, grain_str, float(FrameCount));
    color += noise;

    // 8. Gothic Cold Moonlight / Crypt Tint Blending
    float final_luma = dot(color, vec3(0.299, 0.587, 0.114));
    vec3 gothicColor = vec3(final_luma) * vec3(0.8, 0.9, 1.25); // Cold blue/silver crypt tone
    
    vec3 finalColor = mix(color, gothicColor, gothic_tint);

    gl_FragColor = vec4(clamp(finalColor, 0.0, 1.0), 1.0);
}
#endif