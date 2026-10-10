#version 450

// ===== Parameters =====
#pragma parameter bloom_str         "Bloom Intensity"           0.4     0.0  2.0  0.05
#pragma parameter bloom_thr         "Bloom Threshold"           0.6     0.0  1.0  0.05
#pragma parameter bloom_radius      "Bloom Radius"              1.0     0.5  5.0  0.25
#pragma parameter fake_ao           "Fake AO Strength"          0.4     0.0  1.0  0.05
#pragma parameter ao_threshold      "AO Threshold"              0.1     0.0  1.0  0.05

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
    vec2 halo_px = px * params.bloom_radius;

    // --- Center Fetch ---
    vec3 C = texture(Source, uv).rgb;

    // --- Up / Down Fetches (Shared for AO and Bloom) ---
    vec3 ao_U = texture(Source, uv + vec2(0.0, px.y)).rgb;
    vec3 ao_D = texture(Source, uv - vec2(0.0, px.y)).rgb;

    // --- Left / Right Fetches for AO (Fixed 1-pixel) ---
    vec3 ao_L = texture(Source, uv - vec2(px.x, 0.0)).rgb;
    vec3 ao_R = texture(Source, uv + vec2(px.x, 0.0)).rgb;

    // --- Left / Right Fetches for Bloom (Using Bloom Radius) ---
    vec3 bloom_L = texture(Source, uv - vec2(halo_px.x, 0.0)).rgb;
    vec3 bloom_R = texture(Source, uv + vec2(halo_px.x, 0.0)).rgb;

    // --- Bloom Calculation (L/R with radius + shared Up/Down) ---
    vec3 bloom_src = (bloom_L + bloom_R + ao_U + ao_D) * 0.25;
    vec3 bloom_final = max(bloom_src - params.bloom_thr, 0.0) * params.bloom_str;
    vec3 res = C + bloom_final;

    // --- Fake AO Calculation (4 Directions: Up, Down, Left, Right) ---
    float y_m = luma(res);
    float ao_dist = abs(luma(C) - luma(ao_U)) + 
                    abs(luma(C) - luma(ao_D)) + 
                    abs(luma(C) - luma(ao_L)) + 
                    abs(luma(C) - luma(ao_R));
    float ao_mask = smoothstep(params.ao_threshold, params.ao_threshold + 0.2, ao_dist * 0.5);
    res -= ao_mask * params.fake_ao * clamp(1.0 - y_m, 0.0, 1.0);

    res = clamp(res, 0.0, 1.0);

    FragColor = vec4(res, 1.0);
}
