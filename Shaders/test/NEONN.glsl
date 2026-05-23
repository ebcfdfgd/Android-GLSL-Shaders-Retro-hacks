#version 110

/* 
   GB-4WAY-HSL-NEON-CORE
   - PURPOSE: Replicates Core Palette control inside the Shader using HSL values.
   - FEATURES: Individual Hue, Saturation, and Lightness controls for all 4 slots.
   - MATH: Integrated high-performance HSL to RGB conversion matrix.
*/

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord;
uniform mat4 MVPMatrix;
void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord.xy;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 vTexCoord;
uniform sampler2D Texture;

// --- [ بارامترات التحكم الاحترافي بنظام HSL ] ---

// المقعد 0: الخلفية (BG) - افتراضياً مضبوط على أسود خالص لتفريغ الفراغ
#pragma parameter HUE_0 "Color 0 (BG) Hue" 0.0 0.0 360.0 1.0
#pragma parameter SAT_0 "Color 0 (BG) Saturation" 0.0 0.0 1.0 0.05
#pragma parameter LIGHT_0 "Color 0 (BG) Lightness" 0.0 0.0 1.0 0.05

// المقعد 1: سبرايت 1 - افتراضياً سيان ليزري مشع
#pragma parameter HUE_1 "Color 1 (Sprite1) Hue" 190.0 0.0 360.0 1.0
#pragma parameter SAT_1 "Color 1 (Sprite1) Saturation" 1.0 0.0 1.0 0.05
#pragma parameter LIGHT_1 "Color 1 (Sprite1) Lightness" 0.5 0.0 1.0 0.05

// المقعد 2: سبرايت 2 - افتراضياً أزرق نيون حاد
#pragma parameter HUE_2 "Color 2 (Sprite2) Hue" 240.0 0.0 360.0 1.0
#pragma parameter SAT_2 "Color 2 (Sprite2) Saturation" 1.0 0.0 1.0 0.05
#pragma parameter LIGHT_2 "Color 2 (Sprite2) Lightness" 0.5 0.0 1.0 0.05

// المقعد 3: السكور والنصوص - افتراضياً أبيض ليزر شديد السطوع
#pragma parameter HUE_3 "Color 3 (Txt/Score) Hue" 0.0 0.0 360.0 1.0
#pragma parameter SAT_3 "Color 3 (Txt/Score) Saturation" 0.0 0.0 1.0 0.05
#pragma parameter LIGHT_3 "Color 3 (Txt/Score) Lightness" 1.0 0.0 1.0 0.05

#ifdef PARAMETER_UNIFORM
uniform float HUE_0, SAT_0, LIGHT_0;
uniform float HUE_1, SAT_1, LIGHT_1;
uniform float HUE_2, SAT_2, LIGHT_2;
uniform float HUE_3, SAT_3, LIGHT_3;
#endif

// دالة رياضية لتحويل قيم HSL المريحة إلى ألوان RGB الصالحة للعرض
vec3 hsl2rgb(vec3 hsl) {
    float h = hsl.x / 360.0;
    float s = hsl.y;
    float l = hsl.z;
    
    if (s == 0.0) return vec3(l); // لون رمادي مطفأ لو التشبع صفر
    
    float q = (l < 0.5) ? (l * (1.0 + s)) : (l + s - l * s);
    float p = 2.0 * l - q;
    
    float r = clamp(abs(mod(h * 6.0 + 4.0, 6.0) - 3.0) - 1.0, 0.0, 1.0);
    float g = clamp(abs(mod(h * 6.0 + 2.0, 6.0) - 3.0) - 1.0, 0.0, 1.0);
    float b = clamp(abs(mod(h * 6.0, 6.0) - 3.0) - 1.0, 0.0, 1.0);
    
    return mix(vec3(p), vec3(q), vec3(r, g, b));
}

void main() {
    vec3 raw_col = texture2D(Texture, vTexCoord).rgb;
    
    // الفرز بناءً على عزل مستويات السطوع الـ 4 للجيم بوي
    float luma = dot(raw_col, vec3(0.299, 0.587, 0.114));
    
    vec3 hsl_target;
    
    if (luma > 0.75) {
        // الدرجة الأفتح أصلياً -> الخلفية المعكوسة
        hsl_target = vec3(HUE_0, SAT_0, LIGHT_0);
    } 
    else if (luma > 0.45) {
        // سبرايت 1
        hsl_target = vec3(HUE_1, SAT_1, LIGHT_1);
    } 
    else if (luma > 0.18) {
        // سبرايت 2
        hsl_target = vec3(HUE_2, SAT_2, LIGHT_2);
    } 
    else {
        // الدرجة الأكثر سواداً أصلياً -> السكور والخطوط الحادة
        hsl_target = vec3(HUE_3, SAT_3, LIGHT_3);
    }

    // تحويل النتيجة النهائية إلى RGB لعرضها على الشاشة
    vec3 final_color = hsl2rgb(hsl_target);

    gl_FragColor = vec4(final_color, 1.0);
}
#endif