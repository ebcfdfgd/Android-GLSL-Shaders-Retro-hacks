#version 450

// Convergence and Integrated Bloom - Optimized to 3 Fetches
// license: public domain

#pragma parameter CONV_STR "Convergence Strength" 0.05 -1.0 1.0 0.01
#pragma parameter BLOOM_STR "Bloom Intensity" 0.3 0.0 1.0 0.05
#pragma parameter BLOOM_THR "Bloom Threshold" 0.6 0.0 1.0 0.05

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float CONV_STR;
	float BLOOM_STR;
	float BLOOM_THR;
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

void main() {

    // 1. Horizontal Convergence
    vec2 conv = vec2(0.01 * params.CONV_STR, 0.0);

    // 2. Three Texture Fetches
    vec3 colR = texture(Source, uv + conv).rgb;
    vec3 colG = texture(Source, uv).rgb;
    vec3 colB = texture(Source, uv - conv).rgb;

    // 3. Base color
    vec3 base = vec3(
        colR.r,
        colG.g,
        colB.b
    );

    // 4. Integrated Bloom
    vec3 bloom_source =
        (colR + colG + colB) / 3.0;

    vec3 bloom_final =
        max(bloom_source - params.BLOOM_THR, 0.0) *
        params.BLOOM_STR;

    // 5. Final
    FragColor =
        vec4(base + bloom_final, 1.0);
}

