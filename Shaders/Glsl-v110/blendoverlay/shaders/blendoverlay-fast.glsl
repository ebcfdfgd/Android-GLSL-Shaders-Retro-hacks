#version 110

/* LIGHT-ULTIMATE (Toshiba V3XEL Turbo - 5050 DNA)
    - UPDATED: Integrated AVG Luminance Compensation for L2.
    - PERFORMANCE: Branchless bounds checking and optimized math.
    - LOGIC: High-speed Overlay (L1) & Multiply (L2) with Normalized Energy.
*/

// --- PARAMETERS ---
#pragma parameter BARREL_DISTORTION "Curve 0 Strength" 0.15 0.0 1.0 0.02
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 5.0 0.05
#pragma parameter v_amount "Soft Vignette Intensity" 0.25 0.0 2.5 0.01

// L1: Fixed to Overlay
#pragma parameter OverlayMix "L1 Intensity (Overlay)" 1.0 0.0 1.0 0.05
#pragma parameter LUTWidth "L1 Width" 0.0 1.0 1024.0 1.0
#pragma parameter LUTHeight "L1 Height" 5.0 1.0 1024.0 1.0

// L2: Fixed to Multiply
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

float overlay_f(float a, float b) {
    return (a < 0.5) ? (2.0 * a * b) : (1.0 - 2.0 * (1.0 - a) * (1.0 - b));
}

void main() {
    // 1. إعداد الإحداثيات ومنطق كيرف 0 (r2)
    vec2 p = (TEX0.xy * screen_scale) - 0.5;
    float r2 = dot(p, p);
    
    // معادلة كيرف 0 فائقة السرعة بتوزيع 0.2/0.8
    vec2 p_curved = p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8));
    
    // فحص الحدود بنظام Step (Branchless) لزيادة الـ FPS
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float check = bounds.x * bounds.y;

    // 2. سحب الصورة (Direct Sampling)
    vec2 fetch_uv = (p_curved + 0.5) / screen_scale;
    vec3 gm = texture2D(Texture, fetch_uv).rgb;

    // 3. الفنتيج (استخدام r2 المحسوبة مسبقاً لتوفير الطاقة)
    gm *= clamp(1.0 - (r2 * v_amount), 0.0, 1.0);

    // إحداثيات ثابتة للطبقات
    vec2 mP = TEX0.xy * screen_scale;
    
    // 4. الطبقة الأولى (L1): Overlay
    if (OverlayMix > 0.01) {
        vec2 maskUV1 = vec2(fract(mP.x * OutputSize.x / max(LUTWidth, 1.0)), 
                            fract(mP.y * OutputSize.y / max(LUTHeight, 1.0)));
        vec3 m1 = texture2D(overlay, maskUV1).rgb;
        vec3 ovl1 = vec3(overlay_f(gm.r, m1.r), overlay_f(gm.g, m1.g), overlay_f(gm.b, m1.b));
        gm = mix(gm, clamp(ovl1, 0.0, 1.0), OverlayMix);
    }

    // 5. الطبقة الثانية (L2): Multiply مع نظام AVG التعويضي
    if (OverlayMix2 > 0.01) {
        vec2 maskUV2 = vec2(fract(mP.x * OutputSize.x / max(LUTWidth2, 1.0)), 
                            fract(mP.y * OutputSize.y / max(LUTHeight2, 1.0)));
        vec3 m2 = texture2D(overlay2, maskUV2).rgb;
        
        // حساب المتوسط لتعويض الفقد في الإضاءة الناتجة عن الـ Multiply
        float m2_avg = (m2.r + m2.g + m2.b) / 3.0;
        vec3 m2_normalized = m2 / max(m2_avg, 0.01); // يمنع السواد التام ويحمي الضوء
        
        gm = mix(gm, gm * m2_normalized, OverlayMix2);
    }

    // 6. النتيجة النهائية (Boost + Borders Check)
    gl_FragColor = vec4(clamp(gm * BRIGHT_BOOST * check, 0.0, 1.0), 1.0);
}
#endif