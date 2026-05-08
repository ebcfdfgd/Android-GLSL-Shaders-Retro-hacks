#version 110

/* LIGHT-ULTIMATE (Toshiba V3XEL Turbo - Curve 0 Edition)
   - UPDATED: Integrated Curve 0 (r2 based barrel distortion).
   - OPTIMIZED: Branchless pipeline for Adreno/Mali GPUs.
   - UNIFIED: L1 & L2 both use Multiply blending.
*/

// --- PARAMETERS ---
#pragma parameter BARREL_DISTORTION "Curve 0 Strength" 0.15 0.0 1.0 0.02
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 5.0 0.05
#pragma parameter v_amount "Soft Vignette Intensity" 0.25 0.0 2.5 0.01

// L1: Multiply
#pragma parameter OverlayMix "L1 Intensity (Multiply)" 1.0 0.0 1.0 0.05
#pragma parameter LUTWidth "L1 Width" 6.0 1.0 1024.0 1.0
#pragma parameter LUTHeight "L1 Height" 4.0 1.0 1024.0 1.0

// L2: Multiply
#pragma parameter OverlayMix2 "L2 Intensity (Multiply)" 0.0 0.0 1.0 0.05
#pragma parameter LUTWidth2 "L2 Width" 6.0 1.0 1024.0 1.0
#pragma parameter LUTHeight2 "L2 Height" 4.0 1.0 1024.0 1.0

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec4 TexCoord;
varying vec2 TEX0, screen_scale;
uniform mat4 MVPMatrix;
uniform vec2 TextureSize, InputSize;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    TEX0 = TexCoord.xy;
    screen_scale = TextureSize / InputSize;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 TEX0, screen_scale;
uniform vec2 OutputSize, TextureSize, InputSize;
uniform sampler2D Texture, overlay, overlay2;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, BRIGHT_BOOST, v_amount, OverlayMix, LUTWidth, LUTHeight, OverlayMix2, LUTWidth2, LUTHeight2;
#endif

void main() {
    // 1. منطق كيرف 0 (إحداثيات r2 فائقة السرعة)
    vec2 p = (TEX0.xy * screen_scale) - 0.5;
    float r2 = dot(p, p);
    
    // توزيع الانحناء بنسبة 0.2/0.8 لمظهر Toshiba الكلاسيكي
    vec2 p_curved = p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8));
    
    // فحص الحدود بنظام Step (Branchless) لزيادة الـ FPS
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float mask = bounds.x * bounds.y;
    
    // 2. سحب الصورة الخام (Direct Sampling)
    vec2 fetch_uv = (p_curved + 0.5) / screen_scale;
    vec3 gm = texture2D(Texture, fetch_uv).rgb;

    // 3. الفنتيج (استغلال r2 المحسوبة مسبقاً لتوفير الطاقة)
    gm *= clamp(1.0 - (r2 * v_amount), 0.0, 1.0);

    // 4. منطق الطبقات الموحد (Multiply)
    vec2 mP = TEX0.xy * screen_scale;
    
    // L1 Multiply
    vec2 maskUV1 = vec2(fract(mP.x * OutputSize.x / LUTWidth), fract(mP.y * OutputSize.y / LUTHeight));
    vec3 m1 = texture2D(overlay, maskUV1).rgb;
    gm = mix(gm, gm * m1, OverlayMix);

    // L2 Multiply
    vec2 maskUV2 = vec2(fract(mP.x * OutputSize.x / LUTWidth2), fract(mP.y * OutputSize.y / LUTHeight2));
    vec3 m2 = texture2D(overlay2, maskUV2).rgb;
    gm = mix(gm, gm * m2, OverlayMix2);

    // المخرجات النهائية مع الـ Boost والحدود السوداء
    gl_FragColor = vec4(clamp(gm * mask * BRIGHT_BOOST, 0.0, 1.0), 1.0);
}
#endif