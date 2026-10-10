#version 450

// ===== Parameters =====
#pragma parameter bloom_str         "Bloom Intensity"           0.4     0.0  2.0  0.05
#pragma parameter bloom_thr         "Bloom Threshold"           0.6     0.0  1.0  0.05
#pragma parameter bloom_radius      "Bloom Radius"              2.0     0.1  10.0 0.1
#pragma parameter fake_ao           "Fake AO Strength"          0.4     0.0  1.0  0.05
#pragma parameter ao_threshold      "AO Threshold"              0.1     0.0  1.0  0.05
#pragma parameter SGPT_BLEND_LEVEL  "Blend Level"               0.85    0.0  1.0  0.05

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float bloom_str;
	float bloom_thr;
	float bloom_radius;
	float fake_ao;
	float ao_threshold;
	float SGPT_BLEND_LEVEL;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 uv;

void main()
{
	gl_Position = global.MVP * Position;
	uv = TexCoord;
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
    vec2 bloom_px = px * params.bloom_radius;

    // --- Center Fetch ---
    vec3 C = texture(Source, uv).rgb;

    // --- 1. SGPT Blend System (2 Fetches: Left and Right using fixed 1-pixel offset) ---
    vec3 L = texture(Source, uv - vec2(px.x, 0.0)).rgb;
    vec3 R = texture(Source, uv + vec2(px.x, 0.0)).rgb;

    vec3 diffL = C - L;
    vec3 diffR = C - R;

    float wL = luma(abs(diffL));
    float wR = luma(abs(diffR));

    vec3 cleaned_c = (wR < wL) ? (C - 0.5 * params.SGPT_BLEND_LEVEL * diffR)
                                : (C - 0.5 * params.SGPT_BLEND_LEVEL * diffL);
    cleaned_c = clamp(cleaned_c, min(C, min(L, R)), max(C, max(L, R)));
    vec3 base = cleaned_c;

    // --- 2. Bloom System (2 Dedicated Fetches: Left and Right using params.bloom_radius) ---
    vec3 bloom_L = texture(Source, uv - vec2(bloom_px.x, 0.0)).rgb;
    vec3 bloom_R = texture(Source, uv + vec2(bloom_px.x, 0.0)).rgb;
    vec3 bloom_src = (bloom_L + bloom_R) * 0.5;
    vec3 bloom_final = max(bloom_src - params.bloom_thr, 0.0) * params.bloom_str;
    vec3 res = base + bloom_final;

    // --- 3. Fake AO System (2 Fetches: Up and Right using fixed 1-pixel offset) ---
    vec3 ao_U = texture(Source, uv + vec2(0.0, px.y)).rgb;
    vec3 ao_R = texture(Source, uv + vec2(px.x, 0.0)).rgb;
    float y_m = luma(res);
    float ao_dist = abs(luma(C) - luma(ao_U)) + abs(luma(C) - luma(ao_R));
    float ao_mask = smoothstep(params.ao_threshold, params.ao_threshold + 0.2, ao_dist);
    res -= ao_mask * params.fake_ao * clamp(1.0 - y_m, 0.0, 1.0);

    res = clamp(res, 0.0, 1.0);

    FragColor = vec4(res, 1.0);
}
