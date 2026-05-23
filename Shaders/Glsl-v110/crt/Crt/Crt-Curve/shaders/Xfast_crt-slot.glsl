#version 110

/* 777-TURBO-ZFAST-PURE-RGB
    - PERFORMANCE: Ultra-fast Array-Index Subpixel Slot Mask.
    - SYNC: Pixel-perfect scanlines locked to texture.
    - CURVE: Classic Toshiba-V3 Barrel Distortion.
    - BEAM: Scanlines disappear on white, Mask remains strong.
    - CONTROL: Dynamic Scanline Fade Cutoff Parameter.
*/

#pragma parameter BARREL_DISTORTION "Screen Curve" 0.08 0.0 0.50 0.01
#pragma parameter LOWLUMSCAN "Scanline Darkness - Low" 4.5 0.0 15.0 0.5
#pragma parameter HILUMSCAN "Scanline Darkness - High" 12.0 0.0 50.0 1.0
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
uniform float BARREL_DISTORTION, LOWLUMSCAN, HILUMSCAN, BRIGHTBOOST, MASK_STR, SCAN_FADE_POINT;
#endif

void main() {
    // 1. إحداثيات الكيرف
    vec2 sc = TextureSize / InputSize;
    vec2 p = (uv * sc) - 0.5;

    float ky = BARREL_DISTORTION * 0.8; 
    vec2 p_curved;
    p_curved.x = p.x * (1.0 + (p.y * p.y) * (BARREL_DISTORTION * 0.2));
    p_curved.y = p.y * (1.0 + (p.x * p.x) * ky);
    p_curved *= (1.0 - 0.12 * BARREL_DISTORTION);

    vec2 texCoord = (p_curved + 0.5) / sc;
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    
    // سحب اللون وتطبيق حدود الشاشة
    vec3 res = texture2D(Texture, texCoord).rgb;
    res *= bounds.x * bounds.y;

    // 2. سكان لاين Zfast منضبط (Pixel-Sync)
    float pos_y = texCoord.y * TextureSize.y;
    float f_y = fract(pos_y); 
    float dist = f_y - 0.5;
    float Y = dist * dist;
    float YY = Y * Y;

    // معادلة الوزن منخفض السطوع والسطوع العالي
    float scanWeightL = (BRIGHTBOOST - LOWLUMSCAN * (Y - 1.5 * YY));
    float scanWeightH = 1.0 - HILUMSCAN * (YY - 2.0 * YY * Y); 

    // 3. ماسك الـ Slot المطور بأسلوب الـ Index Array المباشر الخفيف جداً
    vec3 mcol = vec3(0.0);
    
    // حساب موضع العمود (من 0 لـ 5) وموضع السطر (0 أو 1)
    int x_coord = int(mod(gl_FragCoord.x, 6.0));
    int y_coord = int(mod(gl_FragCoord.y, 2.0));
    
    // إذا كنا في السطر الثاني (y_coord == 1)، نطرح 3 من العمود لعمل الإزاحة المتبادلة (Offset)
    // نستخدم الـ Array Indexing المباشر الذي طلبته بدون أي شروط
    int idx = x_coord - (y_coord * 3);
    
    // حماية النطاق للتأكد من أن المؤشر يقع فقط بين 0 و 2 (أحمر، أخضر، أزرق)
    // إذا كان الناتج 0 يضيء الأحمر، 1 الأخضر، 2 الأزرق، وأي رقم آخر (مثل السوالب أو الفروقات) يترك البكسل أسود بالكامل vec3(0.0)
    if (idx >= 0 && idx < 3) {
        mcol[idx] = 2.0; // رفعنا السطوع لـ 2.0 لتعويض النقاط السوداء في السلوت ماسك
    }
    
    // مزج قوة الماسك بناءً على القوة المختارة
    vec3 mask_rgb = mix(vec3(1.0), mcol, MASK_STR);

    // 4. الدمج الذكي (تلاشي السكان لاين الصريح المربوط بالبارميتر)
    float luma = dot(res, vec3(0.299, 0.587, 0.114));
    
    // مزج السكان لاين، ومع زيادة السطوع يتجه الوزن إلى 1.0 تماماً عند الوصول لقيمة SCAN_FADE_POINT
    float final_scan = mix(scanWeightL, 1.0, smoothstep(0.1, SCAN_FADE_POINT, luma));
    vec3 final_rgb = res * final_scan;

    // تطبيق الماسك المطور بقوته الكاملة على النتيجة المضيئة واللون الأبيض
    final_rgb *= mask_rgb;

    // 5. السطوع النهائي
    gl_FragColor = vec4(final_rgb, 1.0);
}
#endif