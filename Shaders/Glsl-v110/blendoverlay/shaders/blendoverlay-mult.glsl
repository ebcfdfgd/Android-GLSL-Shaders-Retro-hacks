#version 110

/* LIGHT-ULTIMATE (Toshiba V3XEL Turbo - Curve 0 Edition)
   - UPDATED: Integrated AVG Normalization for BOTH L1 & L2.
   - OPTIMIZED: Branchless pipeline for Adreno/Mali GPUs.
   - UNIFIED: L1 & L2 both use Normalized Multiply blending.
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
#pragma parameter LUTWidth2 "L2 Width" 3.0 1.0 1024.0 1.0
#pragma parameter LUTHeight2 "L2 Height" 0.0 1.0 1024.0 1.0

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
    float border_mask = bounds.x * bounds.y;
    
    // 2. سحب الصورة الخام (Direct Sampling)
    vec2 fetch_uv = (p_curved + 0.5) / screen_scale;
    vec3 gm = texture2D(Texture, fetch_uv).rgb;

    // 3. الفنتيج (استغلال r2 المحسوبة مسبقاً لتوفير الطاقة)
    gm *= clamp(1.0 - (r2 * v_amount), 0.0, 1.0);

    // 4. منطق الطبقات الموحد (Normalized Multiply)
    vec2 mP = TEX0.xy * screen_scale;
    
    // --- L1 Normalized Multiply ---
    vec2 maskUV1 = vec2(fract(mP.x * OutputSize.x / max(LUTWidth, 1.0)), 
                        fract(mP.y * OutputSize.y / max(LUTHeight, 1.0)));
    vec3 m1 = texture2D(overlay, maskUV1).rgb;
    // حساب متوسط إضاءة الماسك الأول لتعويضه
    float avg1 = (m1.r + m1.g + m1.b) / 3.0;
    vec3 m1_balanced = m1 / max(avg1, 0.01); 
    gm = mix(gm, gm * m1_balanced, OverlayMix);

    // --- L2 Normalized Multiply ---
    vec2 maskUV2 = vec2(fract(mP.x * OutputSize.x / max(LUTWidth2, 1.0)), 
                        fract(mP.y * OutputSize.y / max(LUTHeight2, 1.0)));
    vec3 m2 = texture2D(overlay2, maskUV2).rgb;
    // حساب متوسط إضاءة الماسك الثاني لتعويضه
    float avg2 = (m2.r + m2.g + m2.b) / 3.0;
    vec3 m2_balanced = m2 / max(avg2, 0.01); 
    gm = mix(gm, gm * m2_balanced, OverlayMix2);

    // المخرجات النهائية مع الـ Boost والحدود السوداء
    gl_FragColor = vec4(clamp(gm * border_mask * BRIGHT_BOOST, 0.0, 1.0), 1.0);
}
#endif