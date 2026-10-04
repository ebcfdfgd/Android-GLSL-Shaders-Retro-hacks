#version 450

#pragma parameter SGPT_BLEND_LEVEL "Blend Level" 1.0 0.0 1.0 0.05

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float SGPT_BLEND_LEVEL;
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

const vec3 Y = vec3(0.299, 0.587, 0.114);

void main() {
    vec2 dx = vec2(1.0 / params.SourceSize.x, 0.0);

    // [1] قراءة البكسلات (3 سحبات)
    vec3 C = texture(Source, uv).rgb;
    vec3 L = texture(Source, uv - dx).rgb;
    vec3 R = texture(Source, uv + dx).rgb;

    // [2] حساب الفروقات (بدون كونتراست)
    vec3 diffL = C - L;
    vec3 diffR = C - R;
    
    // تحديد أي جانب هو "الأقرب" أو الأقل حدة للدمج معه
    float wL = dot(abs(diffL), Y);
    float wR = dot(abs(diffR), Y);

    // [3] الدمج المباشر (Direct Blend)
    // ندمج بناءً على الـ SGPT_BLEND_LEVEL مباشرة دون حسابات إضافية
    vec3 color = (wR < wL) ? (C - 0.5 * params.SGPT_BLEND_LEVEL * diffR) 
                           : (C - 0.5 * params.SGPT_BLEND_LEVEL * diffL);

    // [4] Clamp نهائي لحماية الألوان من الخروج عن النطاق
    FragColor = vec4(clamp(color, min(C, min(L, R)), max(C, max(L, R))), 1.0);
}
