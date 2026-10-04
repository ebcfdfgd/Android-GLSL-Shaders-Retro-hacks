#version 450

/* 
   5-V23-PLASTIC-UPGRADE
   - FEATURE: Fixed Plastic Grain (Luminance-based) from V22.
   - PRESERVED: Clean LCD logic, No AA, and Sharp Ghosting.
   - PERFORMANCE: Optimized static noise calculation.
*/

#pragma parameter PROFILE "LCD Profile: 0:Off, 1:GBA, 2:GBC, 3:DMG-Green, 4:Modern-101" 0.0 0.0 4.0 1.0
#pragma parameter GHOST_STR "LCD Ghosting" 0.55 0.0 3.0 0.05
#pragma parameter MOTION_OFS "Motion Spread" 0.7 0.0 3.0 0.05
#pragma parameter RESPONSE_LAG "LCD Lag Jitter" 0.4 0.0 3.0 0.05
#pragma parameter LCD_GRAIN "LCD Plastic Strength" 0.02 0.0 1.0 0.01
#pragma parameter SATURATION "Saturation" 1.0 0.0 2.0 0.05
#pragma parameter BLACK_LEVEL "Black Level" 0.05 -0.5 0.5 0.01

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float PROFILE;
	float GHOST_STR;
	float MOTION_OFS;
	float RESPONSE_LAG;
	float LCD_GRAIN;
	float SATURATION;
	float BLACK_LEVEL;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord.xy;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

// البارامترات المصفاة

void main() {
    vec2 ps = params.SourceSize.zw;
    vec2 uv = vTexCoord;
    float time = float(params.FrameCount);
    vec3 col = texture(Source, uv).rgb;

    // [1] الـ Ghosting & Jitter (المنطق الأصلي للكود 5)
    if (params.GHOST_STR > 0.0) {
        float toggle = (mod(time, 2.0) > 0.5) ? 1.0 : -1.0;
        float off = (params.MOTION_OFS + (params.RESPONSE_LAG * toggle)) * 0.7;
        vec3 s1 = texture(Source, uv + (ps * off)).rgb;
        vec3 s2 = texture(Source, uv - (ps * off)).rgb;
        col = mix(col, (s1 + s2) * 0.5, params.GHOST_STR * 0.65);
    }

    // [2] مصفوفات الألوان المتميزة
    if (params.PROFILE > 0.5) {
    if (params.PROFILE < 1.5) {
        // GBA
        col *= mat3(0.84, 0.08, 0.08, 0.16, 0.76, 0.08, 0.00, 0.16, 0.84);
    }
    else if (params.PROFILE < 2.5) {
        // GBC
        col *= mat3(0.70, 0.15, 0.15, 0.20, 0.70, 0.10, 0.10, 0.15, 0.75);
    }
    else if (params.PROFILE < 3.5) {
        // DMG (Game Boy Classic)
        float grayscale = dot(col, vec3(0.299, 0.587, 0.114));
        col = mix(vec3(0.05, 0.1, 0.05), vec3(0.6, 0.75, 0.1), grayscale);
    }
    else {
        // 101 (GBA SP Bright Screen)
        col *= mat3(0.90, 0.05, 0.05, 0.05, 0.90, 0.05, 0.05, 0.05, 0.95);
    }
}

    // [3] المعالجة النهائية
    float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
    col = mix(vec3(luma), col, params.SATURATION);
    
    // --- إضافة تأثير البلاستيك المطور (من الكود الأخير) ---
    // ثابت لا يتأثر بالوقت (Static) ويظهر في المناطق المضيئة فقط
    vec2 pixel_coord = uv * params.SourceSize.xy;
    float noise = fract(sin(dot(pixel_coord, vec2(12.9898, 78.233))) * 43758.5453);
    float grain_effect = (noise - 0.5) * params.LCD_GRAIN;
    col += grain_effect * (luma + 0.2); 
    
    // Black Level & Final Clamp
    col = clamp(col - params.BLACK_LEVEL, 0.0, 1.0);

    FragColor = vec4(col, 1.0);
}
