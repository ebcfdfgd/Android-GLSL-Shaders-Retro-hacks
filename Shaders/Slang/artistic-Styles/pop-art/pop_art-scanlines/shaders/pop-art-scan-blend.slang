#version 450

// 4-Color Palette Controls (Obama Pop Art Poster Colors)

// Scanlines

#pragma parameter SGPT_BLEND_LEVEL "Blend Level" 1.0 0.0 1.0 0.05
#pragma parameter PALETTE_DOMINANCE "Palette Dominance (4-Colors)" 0.80 0.0 1.0 0.05
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
#pragma parameter scanline_amount "Scanline Amount" 0.12 0.0 0.5 0.02
#pragma parameter scanline_scale "Scanline Density" 1.0 1.0 4.0 0.5

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float SGPT_BLEND_LEVEL;
	float PALETTE_DOMINANCE;
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
	float scanline_amount;
	float scanline_scale;
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

// ============================================================
// SCANLINE PATTERN
// ============================================================
float scanlinePattern(vec2 fragCoord, float scale)
{
    float line =
        sin(
            fragCoord.y / scale *
            3.14159
        );

    return line * 0.5 + 0.5;
}

void main() {

    // ========================================================
    // 1. SGPT Edge-Smoothing
    // ========================================================

    vec2 dx = vec2(1.0 / params.SourceSize.x, 0.0);

    vec3 C = texture(Source, uv).rgb;
    vec3 L = texture(Source, uv - dx).rgb;
    vec3 R = texture(Source, uv + dx).rgb;

    vec3 diffL = C - L;
    vec3 diffR = C - R;

    float wL = dot(abs(diffL), Y);
    float wR = dot(abs(diffR), Y);

    vec3 gameColor =
        (wR < wL)
        ? (C - 0.5 * params.SGPT_BLEND_LEVEL * diffR)
        : (C - 0.5 * params.SGPT_BLEND_LEVEL * diffL);

    gameColor = clamp(
        gameColor,
        min(C, min(L, R)),
        max(C, max(L, R))
    );

    // ========================================================
    // 2. Calculate Posterized Palette Target
    // ========================================================

    float lum = dot(gameColor, Y);
    vec3 posterized;

    if (lum < 0.25) {
        posterized = vec3(params.C1_R, params.C1_G, params.C1_B);
    }
    else if (lum < 0.50) {
        posterized = vec3(params.C2_R, params.C2_G, params.C2_B);
    }
    else if (lum < 0.75) {
        posterized = vec3(params.C3_R, params.C3_G, params.C3_B);
    }
    else {
        posterized = vec3(params.C4_R, params.C4_G, params.C4_B);
    }

    // ========================================================
    // 3. Blend SGPT Colors + 4-Color Palette
    // ========================================================

    vec3 color = mix(
        gameColor,
        posterized,
        params.PALETTE_DOMINANCE
    );

    // ========================================================
    // 4. Scanlines
    // ========================================================

    float scan =
        scanlinePattern(
            uv * params.SourceSize.xy,
            params.scanline_scale
        );

    color *= mix(
        1.0,
        scan,
        params.scanline_amount
    );

    FragColor = vec4(
        clamp(color, 0.0, 1.0),
        1.0
    );
}

