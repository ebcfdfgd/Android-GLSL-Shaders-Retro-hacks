#version 450

// film noise - converted to #version 110
// license: public domain

#pragma parameter BOGUS_FILM_NOISE "-------------------CONVERG./FILM NOISE-------------------" 0.0 0.0 0.0 0.0
#pragma parameter x_off_r "Conv. X Offset Red" 0.05 -1.0 1.0 0.01
#pragma parameter y_off_r "Conv. Y Offset Red" 0.0 -1.0 1.0 0.01
#pragma parameter x_off_g "Conv. X Offset Green" -0.0 -1.0 1.0 0.01
#pragma parameter y_off_g "Conv. Y Offset Green" -0.0 -1.0 1.0 0.01
#pragma parameter x_off_b "Conv. X Offset Blue" -0.05 -1.0 1.0 0.01
#pragma parameter y_off_b "Conv. Y Offset Blue" 0.0 -1.0 1.0 0.01
#pragma parameter grain_str "Grain Strength" 2.0 0.0 100.0 0.5

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float BOGUS_FILM_NOISE;
	float x_off_r;
	float y_off_r;
	float x_off_g;
	float y_off_g;
	float x_off_b;
	float y_off_b;
	float grain_str;
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

float filmGrain(vec2 uv, float strength, float timer) {
    float x = (uv.x + 4.0) * (uv.y + 4.0) * ((mod(timer, 800.0) + 10.0) * 10.0);
    return (mod((mod(x, 13.0) + 1.0) * (mod(x, 123.0) + 1.0), 0.01) - 0.005) * strength;
}

void main() {
    vec2 red_coord = uv + 0.01 * vec2(params.x_off_r, params.y_off_r);
    vec3 red_light = texture(Source, red_coord).rgb;
    
    vec2 green_coord = uv + 0.01 * vec2(params.x_off_g, params.y_off_g);
    vec3 green_light = texture(Source, green_coord).rgb;
    
    vec2 blue_coord = uv + 0.01 * vec2(params.x_off_b, params.y_off_b);
    vec3 blue_light = texture(Source, blue_coord).rgb;

    vec3 film = vec3(red_light.r, green_light.g, blue_light.b);
    film += filmGrain(uv, params.grain_str, float(params.FrameCount));

    FragColor = vec4(film, 1.0);
}
