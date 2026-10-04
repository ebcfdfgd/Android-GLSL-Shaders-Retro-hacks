#version 450

#pragma parameter BLURSCALEX "Blur Amount X-Axis" 0.30 0.0 1.0 0.05

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float BLURSCALEX;
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

void main() {
    // حساب موقع البكسل
    vec2 p = uv * params.SourceSize.xy;
    vec2 i = floor(p) + 0.5;
    vec2 f = p - i;
    
    // معادلة التكبير (Quilez Scaling)
    p = (i + 4.0 * f * f * f) / params.SourceSize.xy;
    
    // تطبيق الـ Blur Scale على محور X
    p.x = mix(p.x, uv.x, params.BLURSCALEX);
    
    // إخراج الصورة النهائية
    FragColor = texture(Source, p);
}
