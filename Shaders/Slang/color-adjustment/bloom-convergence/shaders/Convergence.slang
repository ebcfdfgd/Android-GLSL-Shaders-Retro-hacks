#version 450

#pragma parameter CONV_X "Convergence Horizontal" 0.05 -1.0 1.0 0.01
#pragma parameter CONV_Y "Convergence Vertical" 0.0 -1.0 1.0 0.01

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float CONV_X;
	float CONV_Y;
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

    // Convergence
    vec2 conv = 0.01 * vec2(params.CONV_X, params.CONV_Y);

    vec2 red_coord   = uv + conv;
    vec2 green_coord = uv;
    vec2 blue_coord  = uv - conv;

    // 3 Texture Fetches
    vec3 red_light   = texture(Source, red_coord).rgb;
    vec3 green_light = texture(Source, green_coord).rgb;
    vec3 blue_light  = texture(Source, blue_coord).rgb;

    // Combine RGB channels
    vec3 res = vec3(
        red_light.r,
        green_light.g,
        blue_light.b
    );

    FragColor = vec4(res, 1.0);
}

