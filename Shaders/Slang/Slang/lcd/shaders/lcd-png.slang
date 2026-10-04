#version 450

#pragma parameter MASK_STR "Mask Strength" 0.5 0.0 1.0 0.05
#pragma parameter LUTWidth "Mask Width (px)" 6.0 1.0 1024.0 1.0
#pragma parameter LUTHeight "Mask Height (px)" 6.0 1.0 1024.0 1.0
#pragma parameter GBA_BRIGHT_BST "Final Brightness Boost" 1.0 1.0 2.0 0.05

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float MASK_STR;
	float LUTWidth;
	float LUTHeight;
	float GBA_BRIGHT_BST;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 screen_scale;

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord.xy;
    // نفس المنطق بالضبط:
    screen_scale = params.SourceSize.xy / params.SourceSize.xy;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 screen_scale;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D overlay;

// --- Parameters ---

void main() {
    // 1. سحب لون اللعبة الخام
    vec3 col = texture(Source, vTexCoord).rgb;

    // 2. حساب إحداثيات الماسك (مطابقة تماماً لمنطق LIGHT-ULTIMATE)
    // حساب mP بناءً على إحداثيات الشاشة و الـ scale
    vec2 mP = vTexCoord * screen_scale;
    
    // حساب maskUV بنفس طريقة توزيع الـ LUT في الشيدر الثاني
    vec2 maskUV = vec2(fract(mP.x * params.OutputSize.x / params.LUTWidth), 
                       fract(mP.y * params.OutputSize.y / params.LUTHeight));

    // 3. سحب لون الماسك
    vec3 maskCol = texture(overlay, maskUV).rgb;

    // 4. الدمج (Mix)
    vec3 final_grid = mix(vec3(1.0), maskCol, params.MASK_STR);

    // 5. النتيجة النهائية
    FragColor = vec4(clamp(col * final_grid * params.GBA_BRIGHT_BST, 0.0, 1.0), 1.0);
}
