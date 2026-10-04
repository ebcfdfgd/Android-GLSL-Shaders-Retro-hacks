#version 450

// 4-Color Palette Controls (Obama Pop Art Poster Colors)

#pragma parameter SGPT_BLEND_LEVEL "Blend Level" 1.0 0.0 1.0 0.05
#pragma parameter PALETTE_DOMINANCE "Palette Dominance (4-Colors)" 0.80 0.0 1.0 0.05
#pragma parameter WHITE_THRESHOLD "HUD White Cutoff" 0.90 0.50 1.0 0.01
#pragma parameter INK_STRENGTH "Ink Outline Strength" 0.35 0.0 1.0 0.05
#pragma parameter INK_THRESHOLD "Ink Edge Sensitivity" 0.08 0.01 0.30 0.01
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

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float SGPT_BLEND_LEVEL;
	float PALETTE_DOMINANCE;
	float WHITE_THRESHOLD;
	float INK_STRENGTH;
	float INK_THRESHOLD;
	float C1_R;
	float C1_G;
	float C1_B;
	float C2_R;
	float C2_G;
	float C2_B;
	float C3_R;
	float C3_G;
	float C3_B;
	float C4_R;
	float C4_G;
	float C4_B;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 uv;

void main() {
    uv = TexCoord;
    gl_Position = global.MVP * Position;
}

#pragma stage fragment
layout(location = 0) in vec2 uv;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

const vec3 Y = vec3(0.299, 0.587, 0.114);

void main() {
    vec2 dx = vec2(1.0 / params.SourceSize.x, 0.0);
    vec2 dy = vec2(0.0, 1.0 / params.SourceSize.y);

    vec3 C = texture(Source, uv).rgb;
    vec3 L = texture(Source, uv - dx).rgb;
    vec3 R = texture(Source, uv + dx).rgb;
    vec3 U = texture(Source, uv - dy).rgb;
    vec3 D = texture(Source, uv + dy).rgb;

    // SGPT Edge-Smoothing logic
    vec3 diffL = C - L;
    vec3 diffR = C - R;
    
    float wL = dot(abs(diffL), Y);
    float wR = dot(abs(diffR), Y);

    vec3 gameColor = (wR < wL) ? (C - 0.5 * params.SGPT_BLEND_LEVEL * diffR) 
                               : (C - 0.5 * params.SGPT_BLEND_LEVEL * diffL);

    gameColor = clamp(gameColor, min(C, min(L, R)), max(C, max(L, R)));

    // Calculate Posterized Palette Target
    float lum = dot(gameColor, Y);
    vec3 posterized;
    
    if (lum < 0.25) {
        posterized = vec3(params.C1_R, params.C1_G, params.C1_B);
    } else if (lum < 0.50) {
        posterized = vec3(params.C2_R, params.C2_G, params.C2_B);
    } else if (lum < 0.75) {
        posterized = vec3(params.C3_R, params.C3_G, params.C3_B);
    } else {
        posterized = vec3(params.C4_R, params.C4_G, params.C4_B);
    }

    // Blend game original colors with the 4-color palette
    vec3 color = mix(gameColor, posterized, params.PALETTE_DOMINANCE);

    // HUD Mask: Prevents outlines on bright elements/white HUD
    float maxVal = max(C.r, max(C.g, C.b));
    float outlineAllowed = 1.0 - smoothstep(params.WHITE_THRESHOLD - 0.05, params.WHITE_THRESHOLD, maxVal);

    // Ink Outlines (4-directional edge detection)
    float edge = max(max(wL, wR), max(dot(abs(C - U), Y), dot(abs(C - D), Y)));
    if (edge > params.INK_THRESHOLD) {
        float inkFactor = smoothstep(params.INK_THRESHOLD, params.INK_THRESHOLD + 0.1, edge) * params.INK_STRENGTH * outlineAllowed;
        color = mix(color, color * 0.15, inkFactor);
    }

    FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
