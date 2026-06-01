#version 110

#pragma parameter BARREL_DISTORTION "Screen Curve" 0.08 0.0 0.50 0.01
#pragma parameter SCAN_LOW "Scanline Intensity (Dark Scenes)" 0.8 0.0 1.0 0.05
#pragma parameter SCAN_HIGH "Scanline Intensity (Bright Scenes)" 0.3 0.0 1.0 0.05
#pragma parameter MASK_LOW "Mask Intensity (Dark Scenes)" 0.5 0.0 1.0 0.05
#pragma parameter MASK_HIGH "Mask Intensity (Bright Scenes)" 0.2 0.0 1.0 0.05
#pragma parameter GAMMA_BOOST "Gamma Brightness Boost" 0.0 -1.0 1.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
uniform mat4 MVPMatrix;

void main() {
    uv = TexCoord;
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform vec2 InputSize;
uniform vec2 OutputSize;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION;
uniform float SCAN_LOW;
uniform float SCAN_HIGH;
uniform float MASK_LOW;
uniform float MASK_HIGH;
uniform float GAMMA_BOOST;
#else
#define BARREL_DISTORTION 0.08
#define SCAN_LOW 0.8
#define SCAN_HIGH 0.3
#define MASK_LOW 0.5
#define MASK_HIGH 0.2
#define GAMMA_BOOST 1.0
#endif

#define PI 3.141592653589793
#define TAU 6.283185307179586

void main() {
    // 1. حسابات كيرف الشاشة (يطبق على اللعبة فقط)
    vec2 sc = TextureSize / InputSize;
    vec2 p = (uv * sc) - 0.5;

    float ky = BARREL_DISTORTION * 0.8; 
    vec2 p_curved;
    p_curved.x = p.x * (1.0 + (p.y * p.y) * (BARREL_DISTORTION * 0.2));
    p_curved.y = p.y * (1.0 + (p.x * p.x) * ky);
    p_curved *= (1.0 - 0.12 * BARREL_DISTORTION);

    // إحداثيات سحب اللعبة المنحنية
    vec2 texCoord = (p_curved + 0.5) / sc;
    
    // حدود الشاشة السوداء للانحناء
    vec2 bounds = step(abs(p_curved), vec2(0.5));

    // سحب ألوان اللعبة المنحنية وتطبيق الحدود
    vec3 res = texture2D(Texture, texCoord).rgb;
    res *= bounds.x * bounds.y;

    // 2. حساب السطوع الحالي للبكسل
    float l = max(max(res.r, res.g), res.b);

    // 3. تحديد قوة التأثير ديناميكياً حسب السطوع لمنع الإظلام
    float infl = mix(SCAN_LOW, SCAN_HIGH, l);
    float infl2 = mix(MASK_LOW, MASK_HIGH, l);

    // 4. حساب الـ Scanlines المستقيمة
    float scan = infl * sin((uv.y * TextureSize.y - 0.25) * TAU);

    // 5. نظام الـ Mask RGB الذكي (Aperture Grille)
    // نقوم بفحص موقع البكسل الحالي على الشاشة الحقيقية ونقسمه على دورة من 3 بكسلات
    float mod_x = mod(gl_FragCoord.x, 3.0);
    
    // نجعل القناع الافتراضي يقوم بتعتيم القنوات غير المستهدفة بناءً على قوة القناع الحالية
    vec3 msk = vec3(-infl2); 
    
    if (mod_x < 1.0) {
        msk.r = infl2; // البكسل الأول: نرفع إضاءة الأحمر ونخفض الأخضر والأزرق
    } else if (mod_x < 2.0) {
        msk.g = infl2; // البكسل الثاني: نرفع إضاءة الأخضر ونخفض الأحمر والأزرق
    } else {
        msk.b = infl2; // البكسل الثالث: نرفع إضاءة الأزرق ونخفض الأحمر والأخضر
    }

    // 6. تطبيق التأثيرات (الـ Scanline يطبق على الكل، والـ Mask يطبق قناة تلو الأخرى)
    res += res * scan;
    res += res * msk;

    // 7. تصحيح الجاما للسطوع لتعويض أي فقدان في الإضاءة الناتجة عن الـ RGB Mask
    res = mix(res, sqrt(res), GAMMA_BOOST);

    gl_FragColor = vec4(res, 1.0);
}
#endif