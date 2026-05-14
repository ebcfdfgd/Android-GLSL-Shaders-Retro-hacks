#version 110

/* 777-LITE-TURBO-V13-FIXED
    - SCANLINES: Physically locked to curved game pixels.
    - OVERLAY: Corrected logic for GLSL 110.
    - PERFORMANCE: Optimized for mobile GPUs.
*/

#pragma parameter BARREL_DISTORTION "Screen Curve" 0.15 0.0 1.0 0.02
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.30 1.0 2.5 0.05
#pragma parameter VIG_STR "Vignette Intensity" 0.35 0.0 2.0 0.05
#pragma parameter SCAN_STR "Scanline Intensity" 0.30 0.0 1.0 0.05
#pragma parameter MASK_STR "Mask Strength" 0.5 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width" 3.0 1.0 6.0 1.0

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
uniform vec2 TextureSize, InputSize;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, BRIGHT_BOOST, VIG_STR, SCAN_STR, MASK_STR, MASK_W;
#endif

void main() {
    // حساب النسبة الصحيحة بين التكستشر والمدخلات
    vec2 sc = TextureSize / InputSize;
    vec2 p = (uv * sc) - 0.5;
    vec2 p_curved;
    vec2 p2 = p * p;

    // 1. حساب الانحناء أولاً
    if (BARREL_DISTORTION > 0.0) {
        p_curved = p * (1.0 + vec2(p2.y * (BARREL_DISTORTION * 0.2), p2.x * (BARREL_DISTORTION * 0.8)));
        p_curved *= (1.0 - 0.1 * BARREL_DISTORTION);
    } else {
        p_curved = p;
    }

    // الخروج من الحدود
    if (abs(p_curved.x) > 0.5 || abs(p_curved.y) > 0.5) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // 2. أخذ العينة من التكستشر بناءً على الإحداثيات المنحنية
    vec3 res = texture2D(Texture, (p_curved + 0.5) / sc).rgb;

    // 3. الفينييت (Vignette)
    if (VIG_STR > 0.0) {
        float vignette = p2.x * p2.y * 15.0; 
        res *= (1.0 - clamp(vignette * VIG_STR, 0.0, 1.0));
    }

    // 4. سكان لاين "مطابق للبكسل المنحني"
    if (SCAN_STR > 0.0) {
        // السر هنا: نستخدم p_curved.y (الموقع المنحني) ونضربه في طول اللعبة
        // لضمان أن الخط يتبع البكسل حتى وهو مائل عند الأطراف
        float pixel_y = (p_curved.y + 0.5) * InputSize.y;
        
        // حساب الجيب (Sine) ليعطي خط لكل بكسل
        float scan = sin(pixel_y * 6.283185) * 0.5 + 0.5;
        
        // نظام الـ Overlay المتوافق
        vec3 ovl;
        ovl.r = (res.r < 0.5) ? (2.0 * res.r * scan) : (1.0 - 2.0 * (1.0 - res.r) * (1.0 - scan));
        ovl.g = (res.g < 0.5) ? (2.0 * res.g * scan) : (1.0 - 2.0 * (1.0 - res.g) * (1.0 - scan));
        ovl.b = (res.b < 0.5) ? (2.0 * res.b * scan) : (1.0 - 2.0 * (1.0 - res.b) * (1.0 - scan));
        
        res = mix(res, ovl, SCAN_STR);
    }

    // 5. الماستر (Mask) بناءً على إحداثيات الشاشة الفعلية
    if (MASK_STR > 0.0) {
        float pos = mod(gl_FragCoord.x, MASK_W) / MASK_W;
        vec3 mcol = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), 1.0 - MASK_STR, 1.0);
        res *= mcol;
    }

    // 6. النتيجة النهائية
    gl_FragColor = vec4(res * BRIGHT_BOOST, 1.0);
}
#endif