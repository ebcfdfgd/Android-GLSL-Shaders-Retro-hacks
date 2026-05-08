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

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 TEX0, screen_scale;
uniform mat4 MVPMatrix;
uniform vec2 TextureSize, InputSize;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    TEX0 = TexCoord; 
    screen_scale = TextureSize / InputSize;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 TEX0, screen_scale;
uniform sampler2D Texture;          
uniform sampler2D OverlayTexture, OverlayTexture2; 
uniform vec2 TextureSize, InputSize, OutputSize;

#ifdef PARAMETER_UNIFORM
uniform float BRIGHT_BOOST, BARREL_DISTORTION, v_amount;
uniform float blend_mode, overlay_str, zoom_overlay, png_width, png_height;
uniform float blend_mode2, overlay_str2, zoom_overlay2, png_width2, png_height2;
#endif

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
    vec2 p_curved = p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8));
    
    // فحص الحدود بنظام Branchless لزيادة الـ FPS
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float check = bounds.x * bounds.y;

    // [3] سحب الصورة باستخدام الإحداثيات المنحنية
    vec2 fetch_uv = (p_curved + 0.5) / screen_scale;
    vec3 res = texture2D(Texture, fetch_uv).rgb;

    // [4] إحداثيات الماسك (محاذاته مع الإحداثيات المنحنية لضمان دقة التأثير)
    vec2 maskCoords = (p_curved + 0.5) * InputSize;

    // [5] Layer 1 (Mask/Scanline)
    if (overlay_str > 0.01) {
        vec2 maskUV1 = vec2(fract(maskCoords.x * (OutputSize.x / InputSize.x) / (png_width * zoom_overlay)), 
                            fract(maskCoords.y * (OutputSize.y / InputSize.y) / (png_height * zoom_overlay)));
        vec3 png1 = texture2D(OverlayTexture, maskUV1).rgb;
        res = mix(res, clamp(blend_logic(res, png1, blend_mode), 0.0, 1.0), overlay_str);
    }

    // [6] Layer 2 (Secondary Mask)
    if (overlay_str2 > 0.01) {
        vec2 maskUV2 = vec2(fract(maskCoords.x * (OutputSize.x / InputSize.x) / (png_width2 * zoom_overlay2)), 
                            fract(maskCoords.y * (OutputSize.y / InputSize.y) / (png_height2 * zoom_overlay2)));
        vec3 png2 = texture2D(OverlayTexture2, maskUV2).rgb;
        res = mix(res, clamp(blend_logic(res, png2, blend_mode2), 0.0, 1.0), overlay_str2);
    }

    // [7] Soft Vignette (استخدام r2 المحسوبة مسبقاً لتوفير الطاقة)
    res *= clamp(1.0 - (r2 * v_amount), 0.0, 1.0);

    // [8] Final Boost & Bounds Check
    res *= BRIGHT_BOOST * check;

    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif