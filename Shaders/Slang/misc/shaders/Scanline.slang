#version 450

/*
    Scanlines Standalone Shader
    ---------------------------
*/

#pragma parameter scanline_amount      "Scanline Amount"           0.12 0.0 0.5 0.02
#pragma parameter scanline_scale       "Scanline Density"          1.0  1.0 4.0 0.5

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float scanline_amount;
	float scanline_scale;
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

// Scanline Pattern
float scanlinePattern(vec2 fragCoord, float scale) {
    float line = sin(fragCoord.y / scale * 3.14159);
    return line * 0.5 + 0.5;
}

void main() {
    vec3 C = texture(Source, uv).rgb;

    // Scanlines Overlay
    float scan = scanlinePattern(
        uv * params.SourceSize.xy,
        params.scanline_scale
    );

    C *= mix(
        1.0,
        scan,
        params.scanline_amount
    );

    FragColor = vec4(clamp(C, 0.0, 1.0), 1.0);
}

