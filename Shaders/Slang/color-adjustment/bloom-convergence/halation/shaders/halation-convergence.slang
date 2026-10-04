#version 450

// ===== Parameters =====

#pragma parameter convergence       "Convergence Strength"  0.004  0.0  0.02  0.001
#pragma parameter halation_str      "Halation Intensity"    0.4   0.0  2.0  0.05
#pragma parameter halation_thr      "Halation Threshold"    0.6   0.0  1.0  0.05

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float convergence;
	float halation_str;
	float halation_thr;
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

float luma(vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
}

void main() {
    vec2 px = params.SourceSize.zw;

    // --- Convergence (RGB Channel Separation) ---
    vec2 red_coord   = uv + vec2(params.convergence, 0.0);
    vec2 green_coord = uv;
    vec2 blue_coord  = uv - vec2(params.convergence, 0.0);

    // --- Texture Fetches ---
    vec3 colR    = texture(Source, red_coord).rgb;
    vec3 colG    = texture(Source, green_coord).rgb;
    vec3 colB    = texture(Source, blue_coord).rgb;
    vec3 colHalo = texture(Source, uv + px).rgb;

    // --- Base Color Assembly ---
    vec3 base = vec3(colR.r, colG.g, colB.b);

    // --- Halation Calculation ---
    float haloLuma = luma(colHalo);
    float haloMask = smoothstep(params.halation_thr - 0.1, params.halation_thr + 0.1, haloLuma);
    vec3 halo_color = colHalo * vec3(1.3, 0.8, 0.5) * haloMask;
    vec3 res = base + halo_color * params.halation_str;

    res = clamp(res, 0.0, 1.0);

    FragColor = vec4(res, 1.0);
}
