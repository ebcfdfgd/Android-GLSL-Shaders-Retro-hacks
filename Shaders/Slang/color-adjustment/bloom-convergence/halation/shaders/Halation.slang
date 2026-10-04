#version 450

/* STANDALONE-FAST-HALATION (4 DIRECTIONS) */

#pragma parameter HALATION_STR "Halation Intensity" 0.4 0.0 2.0 0.05
#pragma parameter HALATION_THR "Halation Threshold" 0.6 0.0 1.0 0.05
#pragma parameter HALATION_RADIUS "Halation Radius" 1.0 1.0 10.0 0.5

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float HALATION_STR;
	float HALATION_THR;
	float HALATION_RADIUS;
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
    // 4-Direction offset (Right, Left, Up, Down) based on Halation Radius
    vec2 px = (params.SourceSize.zw) * params.HALATION_RADIUS;
    vec3 base = texture(Source, uv).rgb;

    // Fast 4-Direction Halation calculation using nearby samples
    vec3 halo_sample = texture(Source, uv + vec2(px.x, 0.0)).rgb + 
                         texture(Source, uv - vec2(px.x, 0.0)).rgb + 
                         texture(Source, uv + vec2(0.0, px.y)).rgb + 
                         texture(Source, uv - vec2(0.0, px.y)).rgb;
    halo_sample *= 0.25;

    // Threshold and masking based on luminance
    float haloLuma = luma(halo_sample);
    float haloMask = smoothstep(params.HALATION_THR - 0.1, params.HALATION_THR + 0.1, haloLuma);
    
    // Apply warm reddish-orange/golden tint characteristic of film halation
    vec3 halo_color = halo_sample * vec3(1.3, 0.8, 0.5) * haloMask;

    vec3 final_color = base + halo_color * params.HALATION_STR;

    FragColor = vec4(final_color, 1.0);
}
