#version 450

/* ULTIMATE-HYBRID-NO-ZOOM-CURVE-0
   - UPDATED: Integrated Curve 0 (r2 based barrel distortion).
   - REMOVED: Legacy kx/ky coordinate logic.
   - PERFORMANCE: Optimized Branchless bounds checking.
*/

// --- PARAMETERS ---

#pragma parameter BRIGHT_BOOST "Final Bright Boost" 1.2 1.0 5.0 0.05
#pragma parameter BARREL_DISTORTION "Curve 0 Strength" 0.15 0.0 1.0 0.02
#pragma parameter v_amount "Soft Vignette Intensity" 0.25 0.0 2.5 0.01
#pragma parameter blend_mode "L1 Mode: Mult, Over, Soft, SUB, DODGE, DARK" 0.0 0.0 5.0 1.0
#pragma parameter overlay_str "L1 PNG Intensity" 0.35 0.0 1.0 0.05
#pragma parameter zoom_overlay "L1 PNG Scale" 1.0 0.1 10.0 0.1
#pragma parameter png_width "L1 PNG Width" 6.0 1.0 1024.0 1.0
#pragma parameter png_height "L1 PNG Height" 4.0 1.0 1024.0 1.0
#pragma parameter blend_mode2 "L2 Mode: Mult, Over, Soft, SUB, DODGE, DARK" 0.0 0.0 5.0 1.0
#pragma parameter overlay_str2 "L2 PNG Intensity" 0.20 0.0 1.0 0.05
#pragma parameter zoom_overlay2 "L2 PNG Scale" 1.0 0.1 10.0 0.1
#pragma parameter png_width2 "L2 PNG Width" 6.0 1.0 1024.0 1.0
#pragma parameter png_height2 "L2 PNG Height" 4.0 1.0 1024.0 1.0

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float BRIGHT_BOOST;
	float BARREL_DISTORTION;
	float v_amount;
	float blend_mode;
	float overlay_str;
	float zoom_overlay;
	float png_width;
	float png_height;
	float blend_mode2;
	float overlay_str2;
	float zoom_overlay2;
	float png_width2;
	float png_height2;
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
    TEX0 = TexCoord; 
    screen_scale = params.SourceSize.xy / params.SourceSize.xy;
}

#pragma stage fragment
layout(location = 0) in vec2 TEX0;
layout(location = 1) in vec2 screen_scale;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D OverlayTexture;
layout(set = 0, binding = 4) uniform sampler2D OverlayTexture2;

vec3 blend_logic(vec3 a, vec3 b, float mode) {
    if (mode < 0.5) return a * b;
    if (mode < 1.5) return mix(2.0 * a * b, 1.0 - 2.0 * (1.0 - a) * (1.0 - b), step(0.5, a.r));
    if (mode < 2.5) return (1.0 - 2.0 * b) * a * a + 2.0 * b * a;
    if (mode < 3.5) return clamp(a - b, 0.0, 1.0);
    if (mode < 4.5) return a / (1.00001 - b);
    return min(a, b);
}

void main() {
    // [1] إعداد الإحداثيات الأساسية
    vec2 p = (TEX0.xy * screen_scale) - 0.5;
    
    // [2] معادلة كيرف 0 (تعتمد على r2 لسرعة المعالجة)
    float r2 = dot(p, p);
    vec2 p_curved = p * (1.0 + r2 * vec2(params.BARREL_DISTORTION * 0.2, params.BARREL_DISTORTION * 0.8));
    
    // فحص الحدود بنظام Branchless لزيادة الـ FPS
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float check = bounds.x * bounds.y;

    // [3] سحب الصورة باستخدام الإحداثيات المنحنية
    vec2 fetch_uv = (p_curved + 0.5) / screen_scale;
    vec3 res = texture(Source, fetch_uv).rgb;

    // [4] إحداثيات الماسك (محاذاته مع الإحداثيات المنحنية لضمان دقة التأثير)
    vec2 maskCoords = (p_curved + 0.5) * params.SourceSize.xy;

    // [5] Layer 1 (Mask/Scanline)
    if (params.overlay_str > 0.01) {
        vec2 maskUV1 = vec2(fract(maskCoords.x * (params.OutputSize.x / params.SourceSize.x) / (params.png_width * params.zoom_overlay)), 
                            fract(maskCoords.y * (params.OutputSize.y / params.SourceSize.y) / (params.png_height * params.zoom_overlay)));
        vec3 png1 = texture(OverlayTexture, maskUV1).rgb;
        res = mix(res, clamp(blend_logic(res, png1, params.blend_mode), 0.0, 1.0), params.overlay_str);
    }

    // [6] Layer 2 (Secondary Mask)
    if (params.overlay_str2 > 0.01) {
        vec2 maskUV2 = vec2(fract(maskCoords.x * (params.OutputSize.x / params.SourceSize.x) / (params.png_width2 * params.zoom_overlay2)), 
                            fract(maskCoords.y * (params.OutputSize.y / params.SourceSize.y) / (params.png_height2 * params.zoom_overlay2)));
        vec3 png2 = texture(OverlayTexture2, maskUV2).rgb;
        res = mix(res, clamp(blend_logic(res, png2, params.blend_mode2), 0.0, 1.0), params.overlay_str2);
    }

    // [7] Soft Vignette (استخدام r2 المحسوبة مسبقاً لتوفير الطاقة)
    res *= clamp(1.0 - (r2 * params.v_amount), 0.0, 1.0);

    // [8] Final Boost & Bounds Check
    res *= params.BRIGHT_BOOST * check;

    FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
