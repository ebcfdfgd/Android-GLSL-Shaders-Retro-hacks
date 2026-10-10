#version 450

/* ULTIMATE SONIC 2026 - HALATION + ADVANCED POST-PROCESSING (NO OUTLINE) */
#pragma parameter halation_str      "Halation Intensity" 0.4 0.0 2.0 0.05
#pragma parameter halation_thr      "Halation Threshold" 0.6 0.0 1.0 0.05
#pragma parameter MICRO_AO          "Depth: Micro-AO" 0.7 0.0 1.0 0.05
#pragma parameter AO_SKIN_PROT      "Depth: AO Skin Protect" 0.60 0.0 1.0 0.05
#pragma parameter RIM_LIGHT         "Light: Rim Strength" 1.5 0.0 2.0 0.05
#pragma parameter RIM_MASK_POWER    "Rim Mask Threshold" 0.8 0.0 3.0 0.1
#pragma parameter VIBRANCE          "Color: Vibrance" 1.1 -1.0 2.0 0.10
#pragma parameter de_dither         "Dither Blend (Center/Right)" 0.0 0.0 1.0 0.05

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float halation_str;
	float halation_thr;
	float MICRO_AO;
	float AO_SKIN_PROT;
	float RIM_LIGHT;
	float RIM_MASK_POWER;
	float VIBRANCE;
	float de_dither;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 texCoord;

void main()
{
	gl_Position = global.MVP * Position;
	texCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 texCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

const vec3 lumaWeight = vec3(0.299, 0.587, 0.114);

void main() {
    vec2 px = params.SourceSize.zw;

    // [1] EXACTLY 5 TEXTURE FETCHES (Center, Left, Right, Up, Down)
    vec3 C = texture(Source, texCoord).rgb;
    vec3 L = texture(Source, texCoord - vec2(px.x, 0.0)).rgb;
    vec3 R = texture(Source, texCoord + vec2(px.x, 0.0)).rgb;
    vec3 U = texture(Source, texCoord + vec2(0.0, px.y)).rgb;
    vec3 D = texture(Source, texCoord - vec2(0.0, px.y)).rgb;

    // [2] BASE COLOR WITH DITHER CLEANUP (Center & Right blend)
    vec3 cleaned_c = mix(C, (C + R) * 0.5, params.de_dither);
    vec3 res = cleaned_c;

    // [3] HALATION CALCULATION (Using all 4 surrounding fetches)
    vec3 halo_cleaned = (L + R + U + D) * 0.25;
    float haloLuma = dot(halo_cleaned, lumaWeight);
    float haloMask = smoothstep(params.halation_thr - 0.1, params.halation_thr + 0.1, haloLuma);
    vec3 halo_color = halo_cleaned * vec3(1.3, 0.8, 0.5) * haloMask;
    res += halo_color * params.halation_str;

    // [4] EDGE & LUMA CALCULATION (Required for Rim Light & AO)
    float y_m = dot(res, lumaWeight);
    vec3 diffSum = abs(res - L) + abs(res - R) + abs(res - U) + abs(res - D);
    float edge = dot(diffSum, vec3(0.333)) * 0.5;

    // [5] LIGHTING & AO (Using 4 directions: L vs R and U vs D)
    float dist = (abs(dot(L, lumaWeight) - dot(R, lumaWeight)) + abs(dot(U, lumaWeight) - dot(D, lumaWeight)));
    float rimMask = clamp(1.0 - (y_m * params.RIM_MASK_POWER), 0.0, 1.0); 

    // AO
    res -= (dist * params.MICRO_AO * clamp(1.0 - y_m, 0.0, 1.0)) * step(y_m, params.AO_SKIN_PROT);

    // Rim Light
    res += (edge * params.RIM_LIGHT * 0.7 * rimMask);

    // Vibrance
    res = mix(vec3(y_m), res, params.VIBRANCE);

    FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
