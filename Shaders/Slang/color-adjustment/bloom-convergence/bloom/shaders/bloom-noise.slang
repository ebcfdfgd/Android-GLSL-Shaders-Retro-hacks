#version 450

// Bloom + Film Grain - 4 Directions (No Chromatic Aberration)
// license: public domain

#pragma parameter grain_str "Grain Strength" 0.1 0.0 100.0 0.10
#pragma parameter BLOOM_STR "Bloom Intensity" 0.3 0.0 1.0 0.05
#pragma parameter BLOOM_THR "Bloom Threshold" 0.6 0.0 1.0 0.05
#pragma parameter SAMPLE_RADIUS "Sample Radius" 1.0 0.1 10.0 0.1

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float grain_str;
	float BLOOM_STR;
	float BLOOM_THR;
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

void main() {
    gl_Position = global.MVP * Position;
    uv = TexCoord.xy;
}

#pragma stage fragment
layout(location = 0) in vec2 uv;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

// Uniforms

// Fixed Film Grain
float filmGrain(vec2 uv, float strength, float timer) {
    float x = (uv.x + 4.0) * (uv.y + 4.0) *
              ((mod(timer, 800.0) + 10.0) * 10.0);

    float n = fract(
        (mod(x, 13.0) + 1.0) *
        (mod(x, 123.0) + 1.0) *
        100.0
    );

    return (n - 0.5) * strength;
}

void main() {

    // 1. 4-Direction Texture Fetches (Center, Right, Left, Up, Down)
    vec2 px = (params.SourceSize.zw) * params.SAMPLE_RADIUS;
    
    vec3 col0 = texture(Source, uv).rgb;                                // Center
    vec3 col1 = texture(Source, uv + vec2(px.x, 0.0)).rgb; // Right
    vec3 col2 = texture(Source, uv - vec2(px.x, 0.0)).rgb; // Left
    vec3 col3 = texture(Source, uv + vec2(0.0, px.y)).rgb; // Up
    vec3 col4 = texture(Source, uv - vec2(0.0, px.y)).rgb; // Down

    // 2. Clean base image
    vec3 film = col0;

    // 3. Bloom (Average of 4 surrounding directions)
    vec3 bloom_src = (col1 + col2 + col3 + col4) * 0.25;
    vec3 bloom_final = max(bloom_src - params.BLOOM_THR, 0.0) * params.BLOOM_STR;
    film += bloom_final;

    // 4. Film Grain
    film += filmGrain(uv, params.grain_str, float(params.FrameCount));

    FragColor = vec4(film, 1.0);
}

