#version 450

// ===== Parameters =====
#pragma parameter bloom_str         "Bloom Intensity"           0.4     0.0  2.0  0.05
#pragma parameter bloom_thr         "Bloom Threshold"           0.6     0.0  1.0  0.05
#pragma parameter fake_ao           "Fake AO Strength"          0.4     0.0  1.0  0.05
#pragma parameter ao_threshold      "AO Threshold"              0.1     0.0  1.0  0.05
#pragma parameter de_dither         "Dither Blend"              0.0     0.0  1.0  0.05
#pragma parameter SAMPLE_RADIUS     "Bloom Sample Radius"       1.0     0.1  10.0 0.1

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float bloom_str;
	float bloom_thr;
	float fake_ao;
	float ao_threshold;
	float de_dither;
	float SAMPLE_RADIUS;
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
    vec2 base_px = params.SourceSize.zw;
    vec2 bloom_px = base_px * params.SAMPLE_RADIUS;

    // --- Center Fetch ---
    vec3 C = texture(Source, uv).rgb;

    // --- 1. Mix / Dither System (2 Fetches: Left and Right - Fixed 1-pixel) ---
    vec3 mix_L = texture(Source, uv - vec2(base_px.x, 0.0)).rgb;
    vec3 mix_R = texture(Source, uv + vec2(base_px.x, 0.0)).rgb;
    vec3 cleaned_c = mix(C, (mix_L + mix_R) * 0.5, params.de_dither);
    vec3 base = cleaned_c;

    // --- 2. Bloom System (2 Fetches: Left and Right - Controlled by params.SAMPLE_RADIUS) ---
    vec3 bloom_L = texture(Source, uv - vec2(bloom_px.x, 0.0)).rgb;
    vec3 bloom_R = texture(Source, uv + vec2(bloom_px.x, 0.0)).rgb;
    vec3 bloom_src = (bloom_L + bloom_R) * 0.5;
    vec3 bloom_final = max(bloom_src - params.bloom_thr, 0.0) * params.bloom_str;
    vec3 res = base + bloom_final;

    // --- 3. Fake AO System (2 Fetches: Up and Right - Fixed 1-pixel) ---
    vec3 ao_U = texture(Source, uv + vec2(0.0, base_px.y)).rgb;
    vec3 ao_R = texture(Source, uv + vec2(base_px.x, 0.0)).rgb;
    float y_m = luma(res);
    float ao_dist = abs(luma(C) - luma(ao_U)) + abs(luma(C) - luma(ao_R));
    float ao_mask = smoothstep(params.ao_threshold, params.ao_threshold + 0.2, ao_dist);
    res -= ao_mask * params.fake_ao * clamp(1.0 - y_m, 0.0, 1.0);

    res = clamp(res, 0.0, 1.0);

    FragColor = vec4(res, 1.0);
}
