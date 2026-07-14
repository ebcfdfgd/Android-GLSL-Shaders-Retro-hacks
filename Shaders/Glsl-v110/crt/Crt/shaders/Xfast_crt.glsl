#version 110

/* 777-TURBO-ZFAST-PURE-RGB
    - PERFORMANCE: Ultra-fast array-based subpixel mask + Curve 20 Integration.
    - SYNC: Pixel-perfect scanlines locked to texture.
    - CURVE: Curve 20 (r2-based vector distortion).
    - BEAM: Scanlines disappear on white, Mask remains strong.
    - CONTROL: Dynamic Scanline Fade Cutoff Parameter.
*/

#pragma parameter BARREL_DISTORTION "Curve 0 Strength" 0.15 0.0 1.0 0.02
#pragma parameter LOWLUMSCAN "Scanline Darkness - Low" 4.5 0.0 15.0 0.5
#pragma parameter BRIGHTBOOST "Brightness Boost" 1.25 0.5 2.0 0.05
#pragma parameter MASK_STR "Mask Intensity" 0.45 0.0 1.0 0.05
#pragma parameter SCAN_FADE_POINT "Scanline Fade Cutoff" 0.85 0.5 1.0 0.05

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
uniform float BARREL_DISTORTION, LOWLUMSCAN, BRIGHTBOOST, MASK_STR, SCAN_FADE_POINT;
#else
#define BARREL_DISTORTION 0.15
#define LOWLUMSCAN 4.5
#define BRIGHTBOOST 1.25
#define MASK_STR 0.45
#define SCAN_FADE_POINT 0.85
#endif

void main() {
    // 1. إحداثيات كيرف 20 الفائق (r2-based)
    vec2 sc = TextureSize / InputSize;
    vec2 p = (uv * sc) - 0.5;

    float r2 = dot(p, p);
    vec2 p_curved = p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8));

    // فحص الحدود خالي من الشروط (Branchless) لضمان أعلى معدل إطارات
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float check = bounds.x * bounds.y;
    
    vec2 texCoord = (p_curved + 0.5) / sc;
    
    // سحب اللون وتطبيق حدود الشاشة الرقمية
    vec3 res = texture2D(Texture, texCoord).rgb;
    res *= check;

    // 2. سكان لاين Zfast منضبط (Pixel-Sync ومربوط بالكيرف الجديد تلقائياً)
    float pos_y = texCoord.y * TextureSize.y;
    float f_y = fract(pos_y); 
    float dist = f_y - 0.5;
    float Y = dist * dist;
    float YY = Y * Y;

    // معادلة الوزن منخفض السطوع والسطوع العالي
    float scanWeightL = (BRIGHTBOOST - LOWLUMSCAN * (Y - 1.5 * YY));
    
    // 3. ماسك RGB السريع الثابت (Screen-Locked)
    vec3 mcol = vec3(0.0);
    mcol[int(mod(gl_FragCoord.x, 3.0))] = 1.0;
    
    // قوة الماسك مستقرة وثابتة على جميع مستويات الإضاءة
    vec3 mask_rgb = mix(vec3(1.0), mcol * 1.5, MASK_STR);

    // 4. الدمج الذكي (تلاشي السكان لاين الصريح المربوط بالبارميتر)
    float luma = dot(res, vec3(0.299, 0.587, 0.114));
    
    // مزج السكان لاين، ومع زيادة السطوع يتجه الوزن إلى 1.0 تماماً عند الوصول لقيمة SCAN_FADE_POINT
    float final_scan = mix(scanWeightL, 1.0, smoothstep(0.1, SCAN_FADE_POINT, luma));
    vec3 final_rgb = res * final_scan;

    // تطبيق الماسك بقوته الكاملة على النتيجة المضيئة
    final_rgb *= mask_rgb;

    // 5. السطوع النهائي
    gl_FragColor = vec4(final_rgb, 1.0);
}
#endif