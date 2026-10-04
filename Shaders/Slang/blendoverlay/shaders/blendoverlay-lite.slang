#version 450

/* LIGHT-ULTIMATE (Toshiba V3XEL Turbo - 5050 DNA)
    - UPDATED: Integrated Curve 0 (r2 based barrel distortion).
    - PERFORMANCE: Branchless bounds checking and optimized math.
    - LOGIC: High-speed Overlay (L1) & Multiply (L2).
*/

// --- PARAMETERS ---

// L1: Fixed to Overlay

// L2: Fixed to Multiply

#pragma parameter BARREL_DISTORTION "Curve 0 Strength" 0.15 0.0 1.0 0.02
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 5.0 0.05
#pragma parameter v_amount "Soft Vignette Intensity" 0.25 0.0 2.5 0.01
#pragma parameter OverlayMix "L1 Intensity (Overlay)" 1.0 0.0 1.0 0.05
#pragma parameter LUTWidth "L1 Width" 6.0 1.0 1024.0 1.0
#pragma parameter LUTHeight "L1 Height" 4.0 1.0 1024.0 1.0
#pragma parameter OverlayMix2 "L2 Intensity (Multiply)" 0.0 0.0 1.0 0.05
#pragma parameter LUTWidth2 "L2 Width" 6.0 1.0 1024.0 1.0
#pragma parameter LUTHeight2 "L2 Height" 4.0 1.0 1024.0 1.0

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float BARREL_DISTORTION;
	float BRIGHT_BOOST;
	float v_amount;
	float OverlayMix;
	float LUTWidth;
	float LUTHeight;
	float OverlayMix2;
	float LUTWidth2;
	float LUTHeight2;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 TEX0;
layout(location = 1) out vec2 screen_scale;

void main() {
    gl_Position = global.MVP * Position;
    TEX0 = TexCoord.xy;
    screen_scale = params.SourceSize.xy / params.SourceSize.xy;
}

#pragma stage fragment
layout(location = 0) in vec2 TEX0;
layout(location = 1) in vec2 screen_scale;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D overlay;
layout(set = 0, binding = 4) uniform sampler2D overlay2;

float overlay_f(float a, float b) {
    return (a < 0.5) ? (2.0 * a * b) : (1.0 - 2.0 * (1.0 - a) * (1.0 - b));
}

void main() {
    // 1. إعداد الإحداثيات ومنطق كيرف 0 (r2)
    vec2 p = (TEX0.xy * screen_scale) - 0.5;
    float r2 = dot(p, p);
    
    // معادلة كيرف 0 فائقة السرعة بتوزيع 0.2/0.8
    vec2 p_curved = p * (1.0 + r2 * vec2(params.BARREL_DISTORTION * 0.2, params.BARREL_DISTORTION * 0.8));
    
    // فحص الحدود بنظام Step (Branchless) لزيادة الـ FPS
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float check = bounds.x * bounds.y;

    // 2. سحب الصورة (Direct Sampling)
    vec2 fetch_uv = (p_curved + 0.5) / screen_scale;
    vec3 gm = texture(Source, fetch_uv).rgb;

    // 3. الفنتيج (استخدام r2 المحسوبة مسبقاً لتوفير الطاقة)
    gm *= clamp(1.0 - (r2 * params.v_amount), 0.0, 1.0);

    // إحداثيات ثابتة للطبقات
    vec2 mP = TEX0.xy * screen_scale;
    
    // 4. الطبقة الأولى (L1): Overlay
    if (params.OverlayMix > 0.01) {
        vec2 maskUV1 = vec2(fract(mP.x * params.OutputSize.x / params.LUTWidth), 
                            fract(mP.y * params.OutputSize.y / params.LUTHeight));
        vec3 m1 = texture(overlay, maskUV1).rgb;
        vec3 ovl1 = vec3(overlay_f(gm.r, m1.r), overlay_f(gm.g, m1.g), overlay_f(gm.b, m1.b));
        gm = mix(gm, clamp(ovl1, 0.0, 1.0), params.OverlayMix);
    }

    // 5. الطبقة الثانية (L2): Multiply
    if (params.OverlayMix2 > 0.01) {
        vec2 maskUV2 = vec2(fract(mP.x * params.OutputSize.x / params.LUTWidth2), 
                            fract(mP.y * params.OutputSize.y / params.LUTHeight2));
        vec3 m2 = texture(overlay2, maskUV2).rgb;
        gm = mix(gm, gm * m2, params.OverlayMix2);
    }

    // 6. النتيجة النهائية (Boost + Borders Check)
    FragColor = vec4(clamp(gm * params.BRIGHT_BOOST * check, 0.0, 1.0), 1.0);
}
