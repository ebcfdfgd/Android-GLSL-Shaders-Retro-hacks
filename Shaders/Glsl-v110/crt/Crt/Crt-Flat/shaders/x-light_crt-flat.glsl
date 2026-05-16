#version 110

/* 777-LITE-TURBO-V2-PERFECT-BALANCE (Backported to 110 - Flat Edition)
    - REMOVED: Screen Curve / Barrel Distortion completely from geometry.
    - Position Fix: Brightness Boost moved to the final stage for better color retention.
    - Logic: Smooth Interpolation for balanced RGB phosphors.
*/

#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.17 1.0 2.0 0.01
#pragma parameter VIG_STR "Vignette Intensity" 0.15 0.0 2.0 0.05

// --- Scanlines Control ---
#pragma parameter SCAN_STR "Scanline Intensity" 0.30 0.0 1.0 0.05

// --- Advanced Mask Control ---
#pragma parameter MASK_STR "Mask Strength" 0.15 0.0 1.0 0.05

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
// تم حذف BARREL_DISTORTION لتنظيف البارميترات والـ Uniforms
uniform float BRIGHT_BOOST, VIG_STR, SCAN_STR, MASK_STR;
#endif

void main() {
    vec2 sc = TextureSize / InputSize;
    vec2 p = (uv * sc) - 0.5;

    // 1. Flat Coordinates (تم إلغاء هندسة الكيرف وتثبيت الأبعاد المسطحة)
    vec2 p_flat = p;

    if (abs(p_flat.x) > 0.5 || abs(p_flat.y) > 0.5) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // 2. Sample (إحداثيات مسطحة صافية للنسيج)
    vec3 res = texture2D(Texture, (p_flat + 0.5) / sc).rgb;

    // 3. Vignette (يعتمد على الأبعاد المسطحة)
    res *= (1.0 - dot(p_flat, p_flat) * VIG_STR);

    // 4. Scanlines (مربوطة الآن بالإحداثيات المسطحة بنقاء كامل)
    {
        // (p_flat.y + 0.5) يحول الإحداثيات المسطحة من (-0.5, 0.5) إلى (0, 1)
        float pixel_y = (p_flat.y + 0.5) * InputSize.y;
        
        // إنشاء موجة السكان لاين
        float scan = sin(pixel_y * 6.283185) * 0.5 + 0.5;
        
        // دمج السكان لاين بناءً على القوة المختارة
        res *= mix(1.0, scan, SCAN_STR);
    }

    // 5. Balanced RGB Mask (سليم دون تغيير)
    vec3 mcol = vec3(0.0);
    mcol[int(mod(gl_FragCoord.x, 3.0))] = 1.0;

    // اضرب النتيجة في بكسل الصورة بناءً على القوة المختارة
    res *= mix(vec3(1.0), mcol, MASK_STR);

    // 6. Final Brightness Boost
    res *= BRIGHT_BOOST;

    gl_FragColor = vec4(res, 1.0);
}
#endif