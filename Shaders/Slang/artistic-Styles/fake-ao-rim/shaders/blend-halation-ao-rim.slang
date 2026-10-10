#version 450

/* ULTIMATE SONIC 2026 - INTEGRATED BLEND + HALATION + ADVANCED POST-PROCESSING */
#pragma parameter SGPT_BLEND_LEVEL  "Blend Level" 0.85 0.0 1.0 0.05
#pragma parameter halation_str      "Halation Intensity" 0.4 0.0 2.0 0.05
#pragma parameter halation_thr      "Halation Threshold" 0.6 0.0 1.0 0.05
#pragma parameter MICRO_AO          "Depth: Micro-AO" 0.7 0.0 1.0 0.05
#pragma parameter AO_SKIN_PROT      "Depth: AO Skin Protect" 0.60 0.0 1.0 0.05
#pragma parameter RIM_LIGHT         "Light: Rim Strength" 1.5 0.0 2.0 0.05
#pragma parameter RIM_MASK_POWER    "Rim Mask Threshold" 0.8 0.0 3.0 0.1
#pragma parameter VIBRANCE          "Color: Vibrance" 1.1 -1.0 2.0 0.10

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float SGPT_BLEND_LEVEL;
	float halation_str;
	float halation_thr;
	float MICRO_AO;
	float AO_SKIN_PROT;
	float RIM_LIGHT;
	float RIM_MASK_POWER;
	float VIBRANCE;
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

// دوال الدمج الذكي
vec3 min_s(vec3 central, vec3 adj1, vec3 adj2) { return min(central, max(adj1, adj2)); }
vec3 max_s(vec3 central, vec3 adj1, vec3 adj2) { return max(central, min(adj1, adj2)); }

void main() {
    vec2 px = params.SourceSize.zw;
    
    // [1] EXACTLY 5 TEXTURE FETCHES (Center, Left, Right, Up, Down)
    vec3 C = texture(Source, texCoord).rgb;
    vec3 L = texture(Source, texCoord - vec2(px.x, 0.0)).rgb;
    vec3 R = texture(Source, texCoord + vec2(px.x, 0.0)).rgb;
    vec3 U = texture(Source, texCoord + vec2(0.0, px.y)).rgb;
    vec3 D = texture(Source, texCoord - vec2(0.0, px.y)).rgb;
    
    // [2] SGPT BLEND (Kept as is using C, L, R)
    vec3 min_sample = min_s(C, L, R);
    vec3 max_sample = max_s(C, L, R);
    float contrast = dot(max(C, max(L, R)) - min(C, min(L, R)), lumaWeight);
    contrast = clamp((1.0 - params.SGPT_BLEND_LEVEL) * contrast, 0.0, 1.0);

    vec3 col_L_blend = 0.5 * (C + L + contrast * (C - L));
    vec3 col_R_blend = 0.5 * (C + R + contrast * (C - R));

    float contrast_L = dot(abs(C - col_L_blend), lumaWeight);
    float contrast_R = dot(abs(C - col_R_blend), lumaWeight);

    vec3 res = contrast_R < contrast_L ? col_L_blend : col_R_blend;
    res = clamp(res, min_sample, max_sample);

    // [3] HALATION CALCULATION (Using all 4 directions: L, R, U, D)
    vec3 halo_cleaned = (L + R + U + D) * 0.25;
    float haloLuma = dot(halo_cleaned, lumaWeight);
    float haloMask = smoothstep(params.halation_thr - 0.1, params.halation_thr + 0.1, haloLuma);
    vec3 halo_color = halo_cleaned * vec3(1.3, 0.8, 0.5) * haloMask;
    res += halo_color * params.halation_str;

    // [4] OUTLINE & EDGE (Using all 4 directions: L, R, U, D)
    float y_m = dot(res, lumaWeight);
    vec3 diffSum = abs(res - L) + abs(res - R) + abs(res - U) + abs(res - D);
    float edge = dot(diffSum, vec3(0.333)) * 0.5;
    
    // [5] LIGHTING & AO & RIM (Using all 4 directions)
    float dist = (abs(dot(L, lumaWeight) - dot(R, lumaWeight)) + abs(dot(U, lumaWeight) - dot(D, lumaWeight)));
    float rimMask = clamp(1.0 - (y_m * params.RIM_MASK_POWER), 0.0, 1.0); 
    
    // AO
    res -= (dist * params.MICRO_AO * clamp(1.0 - y_m, 0.0, 1.0)) * step(y_m, params.AO_SKIN_PROT);
    
    // Rim Light
    res += (edge * params.RIM_LIGHT * 0.7 * rimMask);

    // [6] FINAL COLOR (Vibrance)
    res = mix(vec3(y_m), res, params.VIBRANCE);
    
    FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
