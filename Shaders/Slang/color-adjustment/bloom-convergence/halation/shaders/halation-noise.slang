#version 450

// Film Grain + Fast Halation - 4 Directions (Right, Left, Up, Down)
// license: public domain

#pragma parameter grain_str "Grain Strength" 0.1 0.0 2.0 0.05
#pragma parameter HALATION_STR "Halation Intensity" 0.4 0.0 2.0 0.05
#pragma parameter HALATION_THR "Halation Threshold" 0.6 0.0 1.0 0.05
#pragma parameter SAMPLE_RADIUS "Sample Radius" 1.0 0.1 10.0 0.1

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float grain_str;
	float HALATION_STR;
	float HALATION_THR;
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
    uv = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 uv;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

float luma(vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
}

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

    // 1. Base image
    vec3 col0 = texture(Source, uv).rgb;

    // 2. 4-Direction nearby samples for halation (Right, Left, Up, Down)
    vec2 px = (params.SourceSize.zw) * params.SAMPLE_RADIUS;

    vec3 col1 = texture(Source, uv + vec2(px.x, 0.0)).rgb;
    vec3 col2 = texture(Source, uv - vec2(px.x, 0.0)).rgb;
    vec3 col3 = texture(Source, uv + vec2(0.0, px.y)).rgb;
    vec3 col4 = texture(Source, uv - vec2(0.0, px.y)).rgb;

    // 3. Clean base image
    vec3 film = col0;

    // 4. Fast Halation (Average of 4 directions)
    vec3 halo_sample = (col1 + col2 + col3 + col4) * 0.25;

    float haloLuma = luma(halo_sample);

    float haloMask = smoothstep(
        params.HALATION_THR - 0.1,
        params.HALATION_THR + 0.1,
        haloLuma
    );

    // Warm reddish-orange film halation
    vec3 halo_color =
        halo_sample *
        vec3(1.3, 0.8, 0.5) *
        haloMask;

    film += halo_color * params.HALATION_STR;

    // 5. Film Grain
    film += filmGrain(
        uv,
        params.grain_str,
        float(params.FrameCount)
    );

    FragColor = vec4(film, 1.0);
}

