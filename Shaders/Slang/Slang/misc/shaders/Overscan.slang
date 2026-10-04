#version 450

#pragma parameter ia_overscan_percent_x "Horizontal Overscan %" 0.0 -25.0 25.0 1.0
#pragma parameter ia_overscan_percent_y "Vertical Overscan %" 0.0 -25.0 25.0 1.0

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float ia_overscan_percent_x;
	float ia_overscan_percent_y;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 vMin;
layout(location = 2) out vec2 vMax;

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord.xy;
    
    // حساب نطاق الصورة الفعلي داخل الـ Atlas
    vec2 sizeRatio = params.SourceSize.xy / params.SourceSize.xy;
    vMin = (TexCoord.xy / params.SourceSize.xy) * 0.0; // نقطة البداية
    vMax = sizeRatio; // نقطة النهاية (عرض وطول اللعبة الحقيقي)
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 vMin;
layout(location = 2) in vec2 vMax;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main() {
    // 1. حساب المركز
    vec2 center = (vMin + vMax) * 0.5;
    
    // 2. تطبيق الـ Overscan (مع قلب الإشارة ليعمل التصغير بشكل صحيح)
    vec2 scale = 1.0 - vec2(params.ia_overscan_percent_x, params.ia_overscan_percent_y) / 100.0;
    vec2 uv = center + (vTexCoord - center) / scale;
    
    // 3. منع ظهور بقية الـ Atlas (الـ Clamp)
    // نتأكد أن الإحداثيات داخل حدود اللعبة فقط
    float mask = step(vMin.x, uv.x) * step(uv.x, vMax.x) * step(vMin.y, uv.y) * step(uv.y, vMax.y);
    
    vec3 res = texture(Source, uv).rgb;
    FragColor = vec4(res * mask, 1.0);
}
