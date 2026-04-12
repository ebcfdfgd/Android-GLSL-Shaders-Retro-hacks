#version 110

/*
    LIGHT-ULTIMATE (Toshiba V3XEL Turbo Edition - Backported to 110)
    - Feature: Soft-Vignette (V3XEL Style).
    - Updated: Toshiba Cylindrical Curve (Faster, optimized for mobile).
    - Logic: Overlay (L1) & Multiply (L2) - Optimized for Adreno 300 series.
*/

// --- PARAMETERS ---
#pragma parameter BARREL_DISTORTION "Toshiba Curve Strength" 0.12 0.0 0.5 0.01
#pragma parameter ZOOM "Zoom Amount" 1.0 0.5 2.0 0.01
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 5.0 0.05
#pragma parameter v_amount "Soft Vignette Intensity" 0.25 0.0 2.5 0.01

// L1: Fixed to Overlay
#pragma parameter OverlayMix "L1 Intensity (Overlay)" 1.0 0.0 1.0 0.05
#pragma parameter LUTWidth "L1 Width" 6.0 1.0 1024.0 1.0
#pragma parameter LUTHeight "L1 Height" 4.0 1.0 1024.0 1.0

// L2: Fixed to Multiply
#pragma parameter OverlayMix2 "L2 Intensity (Multiply)" 0.0 0.0 1.0 0.05
#pragma parameter LUTWidth2 "L2 Width" 6.0 1.0 1024.0 1.0
#pragma parameter LUTHeight2 "L2 Height" 4.0 1.0 1024.0 1.0

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec4 TexCoord;
varying vec2 TEX0;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    TEX0 = TexCoord.xy;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 TEX0;
uniform vec2 OutputSize;
uniform vec2 TextureSize;
uniform vec2 InputSize;
uniform sampler2D Texture;
uniform sampler2D overlay;
uniform sampler2D overlay2;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, ZOOM, BRIGHT_BOOST, v_amount, OverlayMix, LUTWidth, LUTHeight, OverlayMix2, LUTWidth2, LUTHeight2;
#endif

// دالة الـ Overlay المحسنة للأداء
float overlay_f(float a, float b) {
    return (a < 0.5) ? (2.0 * a * b) : (1.0 - 2.0 * (1.0 - a) * (1.0 - b));
}

void main() {
    vec2 sc = TextureSize / InputSize;
    // تعديل الإحداثيات للبدء من المركز
    vec2 uv = (TEX0.xy * sc) - 0.5;
    uv /= ZOOM;
    
    // 1. كيرف توشيبا الأسطواني (Cylindrical Turbo)
    // حساب التشويه بمحورين منفصلين لسرعة المعالجة
    float kx = BARREL_DISTORTION * 0.2; 
    float ky = BARREL_DISTORTION * 0.9; 

    vec2 d_uv;
    d_uv.x = uv.x * (1.0 + (uv.y * uv.y) * kx);
    d_uv.y = uv.y * (1.0 + (uv.x * uv.x) * ky);
    
    // تصحيح الحواف المفقودة بسبب التقوس
    d_uv *= (1.0 - 0.15 * BARREL_DISTORTION);
    
    // 2. فحص الحدود والقطع المباشر (Overscan)
    if (abs(d_uv.x) > 0.5 || abs(d_uv.y) > 0.5) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // سحب الصورة الأساسية
    vec2 gC = (d_uv + 0.5) / sc;
    vec3 gm = texture2D(Texture, gC).xyz * BRIGHT_BOOST;

    // 3. الفنتيج الناعم (Soft Vignette) 
    // معادلة تربيعية لضمان تدرج ناعم يقلل السطوع تدريجياً نحو الأركان
    float vignette_sq = dot(d_uv, d_uv);
    gm *= clamp(1.0 - (vignette_sq * vignette_sq * v_amount), 0.0, 1.0);

    // حساب إحداثيات الماسكات (Masks) بناءً على دقة المخرج
    vec2 mP = TEX0.xy * sc;
    
    // الطبقة الأولى (L1): Overlay
    // يتم تطبيقها فقط إذا كانت الشدة أكبر من صفر لتوفير الطاقة
    if (OverlayMix > 0.01) {
        vec2 maskUV1 = vec2(fract(mP.x * OutputSize.x / LUTWidth), 
                            fract(mP.y * OutputSize.y / LUTHeight));
        vec3 m1 = texture2D(overlay, maskUV1).xyz;
        vec3 ovl1 = vec3(overlay_f(gm.r, m1.r), overlay_f(gm.g, m1.g), overlay_f(gm.b, m1.b));
        gm = mix(gm, clamp(ovl1, 0.0, 1.0), OverlayMix);
    }

    // الطبقة الثانية (L2): Multiply
    if (OverlayMix2 > 0.01) {
        vec2 maskUV2 = vec2(fract(mP.x * OutputSize.x / LUTWidth2), 
                            fract(mP.y * OutputSize.y / LUTHeight2));
        vec3 m2 = texture2D(overlay2, maskUV2).xyz;
        gm = mix(gm, gm * m2, OverlayMix2);
    }

    gl_FragColor = vec4(gm, 1.0);
}
#endif