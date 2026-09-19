#version 110

#pragma parameter SGPT_BLEND_LEVEL "Blend Level" 1.0 0.0 1.0 0.05
#pragma parameter PALETTE_DOMINANCE "Palette Dominance (4-Colors)" 0.80 0.0 1.0 0.05
#pragma parameter WHITE_THRESHOLD "HUD White Cutoff" 0.90 0.50 1.0 0.01
#pragma parameter INK_STRENGTH "Ink Outline Strength" 0.35 0.0 1.0 0.05
#pragma parameter INK_THRESHOLD "Ink Edge Sensitivity" 0.08 0.01 0.30 0.01

// 4-Color Palette Controls (Obama Pop Art Poster Colors)
#pragma parameter C1_R "Color 1 (Dark Blue) Red" 0.00 0.0 1.0 0.01
#pragma parameter C1_G "Color 1 (Dark Blue) Green" 0.20 0.0 1.0 0.01
#pragma parameter C1_B "Color 1 (Dark Blue) Blue" 0.30 0.0 1.0 0.01

#pragma parameter C2_R "Color 2 (Red) Red" 0.84 0.0 1.0 0.01
#pragma parameter C2_G "Color 2 (Red) Green" 0.10 0.0 1.0 0.01
#pragma parameter C2_B "Color 2 (Red) Blue" 0.13 0.0 1.0 0.01

#pragma parameter C3_R "Color 3 (Light Blue) Red" 0.47 0.0 1.0 0.01
#pragma parameter C3_G "Color 3 (Light Blue) Green" 0.60 0.0 1.0 0.01
#pragma parameter C3_B "Color 3 (Light Blue) Blue" 0.65 0.0 1.0 0.01

#pragma parameter C4_R "Color 4 (Beige) Red" 0.99 0.0 1.0 0.01
#pragma parameter C4_G "Color 4 (Beige) Green" 0.90 0.0 1.0 0.01
#pragma parameter C4_B "Color 4 (Beige) Blue" 0.66 0.0 1.0 0.01

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
precision mediump float;
#endif

varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize;

uniform float SGPT_BLEND_LEVEL;
uniform float PALETTE_DOMINANCE;
uniform float WHITE_THRESHOLD;
uniform float INK_STRENGTH;
uniform float INK_THRESHOLD;

uniform float C1_R, C1_G, C1_B;
uniform float C2_R, C2_G, C2_B;
uniform float C3_R, C3_G, C3_B;
uniform float C4_R, C4_G, C4_B;

const vec3 Y = vec3(0.299, 0.587, 0.114);

void main() {
    vec2 dx = vec2(1.0 / TextureSize.x, 0.0);
    vec2 dy = vec2(0.0, 1.0 / TextureSize.y);

    vec3 C = texture2D(Texture, uv).rgb;
    vec3 L = texture2D(Texture, uv - dx).rgb;
    vec3 R = texture2D(Texture, uv + dx).rgb;
    vec3 U = texture2D(Texture, uv - dy).rgb;
    vec3 D = texture2D(Texture, uv + dy).rgb;

    // SGPT Edge-Smoothing logic
    vec3 diffL = C - L;
    vec3 diffR = C - R;
    
    float wL = dot(abs(diffL), Y);
    float wR = dot(abs(diffR), Y);

    vec3 gameColor = (wR < wL) ? (C - 0.5 * SGPT_BLEND_LEVEL * diffR) 
                               : (C - 0.5 * SGPT_BLEND_LEVEL * diffL);

    gameColor = clamp(gameColor, min(C, min(L, R)), max(C, max(L, R)));

    // Calculate Posterized Palette Target
    float lum = dot(gameColor, Y);
    vec3 posterized;
    
    if (lum < 0.25) {
        posterized = vec3(C1_R, C1_G, C1_B);
    } else if (lum < 0.50) {
        posterized = vec3(C2_R, C2_G, C2_B);
    } else if (lum < 0.75) {
        posterized = vec3(C3_R, C3_G, C3_B);
    } else {
        posterized = vec3(C4_R, C4_G, C4_B);
    }

    // Blend game original colors with the 4-color palette
    vec3 color = mix(gameColor, posterized, PALETTE_DOMINANCE);

    // HUD Mask: Prevents outlines on bright elements/white HUD
    float maxVal = max(C.r, max(C.g, C.b));
    float outlineAllowed = 1.0 - smoothstep(WHITE_THRESHOLD - 0.05, WHITE_THRESHOLD, maxVal);

    // Ink Outlines (4-directional edge detection)
    float edge = max(max(wL, wR), max(dot(abs(C - U), Y), dot(abs(C - D), Y)));
    if (edge > INK_THRESHOLD) {
        float inkFactor = smoothstep(INK_THRESHOLD, INK_THRESHOLD + 0.1, edge) * INK_STRENGTH * outlineAllowed;
        color = mix(color, color * 0.15, inkFactor);
    }

    gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
#endif