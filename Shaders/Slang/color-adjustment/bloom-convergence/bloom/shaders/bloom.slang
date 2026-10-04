#version 450

/* STANDALONE-FAST-BLOOM (4 DIRECTIONS) */

#pragma parameter BLOOM_STR "Bloom Intensity" 0.3 0.0 1.0 0.05
#pragma parameter BLOOM_THR "Bloom Threshold" 0.6 0.0 1.0 0.05
#pragma parameter BLOOM_RADIUS "Bloom Radius" 1.0 1.0 10.0 0.5

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float BLOOM_STR;
	float BLOOM_THR;
	float BLOOM_RADIUS;
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
    // Offset for 4 directions (Right, Left, Up, Down) based on Bloom Radius
    vec2 px = (params.SourceSize.zw) * params.BLOOM_RADIUS;
    vec3 base = texture(Source, uv).rgb;

    // Fast 4-Direction Bloom Calculation
    vec3 bloom = texture(Source, uv + vec2(px.x, 0.0)).rgb + 
                 texture(Source, uv - vec2(px.x, 0.0)).rgb + 
                 texture(Source, uv + vec2(0.0, px.y)).rgb + 
                 texture(Source, uv - vec2(0.0, px.y)).rgb;
    bloom *= 0.25;
    vec3 bloom_final = max(bloom - params.BLOOM_THR, 0.0) * params.BLOOM_STR;

    FragColor = vec4(base + bloom_final, 1.0);
}
