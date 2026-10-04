#version 450

#pragma parameter LUT_OPACITY "LUT Opacity" 1.0 0.0 1.0 0.05

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float LUT_OPACITY;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 texCoord;

void main() { gl_Position = global.MVP * Position; texCoord = TexCoord.xy; }

#pragma stage fragment
layout(location = 0) in vec2 texCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D SamplerLUT1;

// دالة تطبيق الـ LUT (تستقبل تكتشر 64x64 Grid)
vec3 apply_lut(sampler2D tex, vec3 color) {
    float size = 64.0;
    float blue = color.b * (size - 1.0);
    vec2 quad;
    quad.y = floor(blue / 8.0);
    quad.x = floor(blue) - (quad.y * 8.0);
    
    vec2 texPos;
    texPos.x = (quad.x * size + color.r * (size - 1.0)) / (size * 8.0);
    texPos.y = (quad.y * size + color.g * (size - 1.0)) / (size * 8.0);
    
    return texture(tex, texPos).rgb;
}

void main() {
    vec3 color = texture(Source, texCoord).rgb;
    
    // تطبيق الـ LUT
    vec3 l_color = apply_lut(SamplerLUT1, clamp(color, 0.0, 1.0));
    
    // خلط الألوان الأصلية مع ألوان الـ LUT
    vec3 final_color = mix(color, l_color, params.LUT_OPACITY);
    
    FragColor = vec4(final_color, 1.0);
}
