#version 450

// Candy Bloom - Adapted for #version 110

#pragma parameter GlowLevel "Glow Level" 1.15 1.0 1.5 0.05
#pragma parameter GlowTightness "Glow Tightness" 0.75 0.0 2.0 0.05

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float GlowLevel;
	float GlowTightness;
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
    // جلب اللون من النسيج
    vec3 Picture = texture(Source, uv).rgb;

    // حساب الإضاءة (Luminance) بناءً على معايير YIQ
    float YIQLuminance = dot(vec3(0.3, 0.6, 0.1), Picture);
    
    // دمج التأثير بناءً على سطوع البكسل
    vec3 res = mix(Picture * params.GlowTightness, Picture * params.GlowLevel, YIQLuminance);

    FragColor = vec4(res, 1.0);
}
