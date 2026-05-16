#version 110

// --- 777-TURBO-ZFAST-FIXED-SYNC ---
/* 
    - FIXED: Scanline size normalized to pixel height.
    - SYNC: Perfectly aligned with Toshiba Curve.
    - PERFORMANCE: Optimized Zfast logic for 4K.
    - RECOVERY: High-brightness Mask visibility fixed.
*/


#pragma parameter LOWLUMSCAN "Scanline Darkness - Low" 5.0 0.0 20.0 0.5
#pragma parameter HILUMSCAN "Scanline Darkness - High" 10.0 0.0 50.0 1.0
#pragma parameter BRIGHTBOOST "Scanline Brightness" 1.20 0.5 2.0 0.05
#pragma parameter MASK_DARK "Mask Intensity" 0.25 0.0 1.0 0.05
#pragma parameter MASK_FADE "Zfast Dynamic Strength" 0.8 0.0 1.0 0.05

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
uniform vec2 TextureSize, InputSize, OutputSize;

#ifdef PARAMETER_UNIFORM
uniform float LOWLUMSCAN, HILUMSCAN, BRIGHTBOOST, MASK_DARK, MASK_FADE;
#endif

void main() {
    vec2 sc = TextureSize / InputSize;
    vec2 p = (uv * sc) - 0.5;

    // تثبيت الإحداثيات المسطحة مباشرة للنسيج
    vec2 texCoord = uv;
    
    // ربط فحص الحدود بـ p لمنع الشاشة السوداء
    vec2 bounds = step(abs(p), vec2(0.5));
    float edge_mask = bounds.x * bounds.y;

    // 2. سحب اللون
    vec3 colour = texture2D(Texture, texCoord).rgb;
    colour *= edge_mask;

    // 3. إصلاح السكان لاين (Zfast Engine Fix)
    float pos_y = texCoord.y * TextureSize.y;
    float f_y = fract(pos_y); 
    
    // حساب المسافة من مركز البكسل (توسيط الشعاع)
    float dist = (f_y - 0.5);
    float Y = dist * dist;
    float YY = Y * Y;

    // موازنة الأوزان لمنع الخطوط العملاقة
    float scanLineWeight = (BRIGHTBOOST - LOWLUMSCAN * (Y - 1.5 * YY));
    float scanLineWeightB = 1.0 - HILUMSCAN * (YY - 2.0 * YY * Y); 

    // 4. المايكرو ماسك (Aperture) ثبات البكسل
    float mask_pos = gl_FragCoord.x;
    float mask = 1.0 + float(mod(mask_pos, 3.0) < 1.5) * -MASK_DARK;

    // 5. الدمج النهائي المصلح (فصل السكان لاين عن الماسك وتفعيل الفيد النقي)
    float luma = dot(colour, vec3(0.299, 0.587, 0.114));
    
    // الفيد الديناميكي يتحكم الآن بالسكان لاين فقط بناءً على السطوع والبارميتر
    float final_scan = mix(scanLineWeight, scanLineWeightB, luma * MASK_FADE);
    vec3 final_rgb = colour * final_scan;

    // تطبيق الماسك بشكل مستقل تماماً ليخترق ويظهر على الألوان الفاتحة والأبيض
    final_rgb *= mask;

    gl_FragColor = vec4(final_rgb, 1.0);
}
#endif