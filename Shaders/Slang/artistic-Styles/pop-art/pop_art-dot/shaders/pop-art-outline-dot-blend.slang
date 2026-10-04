#version 450

// Ben-Day Dots

// 4-Color Palette Controls (Obama Pop Art Poster Colors)

#pragma parameter SGPT_BLEND_LEVEL "Blend Level" 1.0 0.0 1.0 0.05
#pragma parameter PALETTE_DOMINANCE "Palette Dominance (4-Colors)" 0.80 0.0 1.0 0.05
#pragma parameter WHITE_THRESHOLD "HUD White Cutoff" 0.90 0.50 1.0 0.01
#pragma parameter INK_STRENGTH "Ink Outline Strength" 0.35 0.0 1.0 0.05
#pragma parameter INK_THRESHOLD "Ink Edge Sensitivity" 0.08 0.01 0.30 0.01
#pragma parameter DOT_DENSITY  "Dot Grid Size (px)"    6.0  3.0 16.0 0.5
#pragma parameter DOT_ANGLE    "Dot Grid Angle (deg)"  15.0 0.0 90.0 5.0
#pragma parameter DOT_STRENGTH "Dot Shading Strength" 0.85 0.0 1.0 0.05
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
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
	float SGPT_BLEND_LEVEL;
	float PALETTE_DOMINANCE;
	float WHITE_THRESHOLD;
	float INK_STRENGTH;
	float INK_THRESHOLD;
	float DOT_DENSITY;
	float DOT_ANGLE;
	float DOT_STRENGTH;
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
// BEN-DAY DOT PATTERN
// ============================================================
float benDayDot(vec2 fragCoord, float density, float angleDeg, float darkness)
{
    float angle = radians(angleDeg);

    vec2 rotated = vec2(
        fragCoord.x * cos(angle) - fragCoord.y * sin(angle),
        fragCoord.x * sin(angle) + fragCoord.y * cos(angle)
    );

    vec2 cell = mod(rotated, density) - density * 0.5;

    float dist = length(cell);

    float radius = darkness * (density * 0.5);

    return 1.0 - smoothstep(
        radius - 1.0,
        radius + 1.0,
        dist
    );
}

void main() {

    vec2 dx = vec2(1.0 / params.SourceSize.x, 0.0);
    vec2 dy = vec2(0.0, 1.0 / params.SourceSize.y);

    vec3 C = texture(Source, uv).rgb;
    vec3 L = texture(Source, uv - dx).rgb;
    vec3 R = texture(Source, uv + dx).rgb;
    vec3 U = texture(Source, uv - dy).rgb;
    vec3 D = texture(Source, uv + dy).rgb;

    // ========================================================
    // 1. SGPT Edge-Smoothing
    // ========================================================

    vec3 diffL = C - L;
    vec3 diffR = C - R;

    float wL = dot(abs(diffL), Y);
    float wR = dot(abs(diffR), Y);

    vec3 gameColor =
        (wR < wL)
        ? (C - 0.5 * global.SGPT_BLEND_LEVEL * diffR)
        : (C - 0.5 * global.SGPT_BLEND_LEVEL * diffL);

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
        posterized = vec3(global.C1_R, global.C1_G, global.C1_B);
    }
    else if (lum < 0.50) {
        posterized = vec3(global.C2_R, global.C2_G, global.C2_B);
    }
    else if (lum < 0.75) {
        posterized = vec3(global.C3_R, global.C3_G, global.C3_B);
    }
    else {
        posterized = vec3(global.C4_R, global.C4_G, global.C4_B);
    }

    // ========================================================
    // 3. Blend SGPT + 4-Color Palette
    // ========================================================

    vec3 color = mix(
        gameColor,
        posterized,
        global.PALETTE_DOMINANCE
    );

    // ========================================================
    // 4. HUD Mask
    // ========================================================

    float maxVal = max(C.r, max(C.g, C.b));

    float outlineAllowed =
        1.0 - smoothstep(
            global.WHITE_THRESHOLD - 0.05,
            global.WHITE_THRESHOLD,
            maxVal
        );

    // ========================================================
    // 5. Ink Outlines
    // ========================================================

    float edge = max(
        max(wL, wR),
        max(
            dot(abs(C - U), Y),
            dot(abs(C - D), Y)
        )
    );

    if (edge > global.INK_THRESHOLD) {

        float inkFactor =
            smoothstep(
                global.INK_THRESHOLD,
                global.INK_THRESHOLD + 0.1,
                edge
            )
            * global.INK_STRENGTH
            * outlineAllowed;

        color = mix(
            color,
            color * 0.15,
            inkFactor
        );
    }

    // ========================================================
    // 6. Ben-Day Dots
    // ========================================================

    float finalLum = dot(color, Y);

    // Darker regions receive stronger dots
    float darkness = 1.0 - finalLum;

    float dot_mask = benDayDot(
        uv * params.SourceSize.xy,
        global.DOT_DENSITY,
        global.DOT_ANGLE,
        darkness
    );

    color = mix(
        color,
        vec3(0.0),
        dot_mask * global.DOT_STRENGTH * 0.4
    );

    FragColor = vec4(
        clamp(color, 0.0, 1.0),
        1.0
    );
}

