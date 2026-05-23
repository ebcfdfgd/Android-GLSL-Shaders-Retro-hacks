#version 110

/* 777-LITE-TURBO-V13-TRUE-RGB-W (Flat Edition)
    - REMOVED: Screen Curve (BARREL_DISTORTION) completely.
    - MASK: EXACT CLONE OF CODE 7 (Mathematical Phosphor Logic).
    - PERFORMANCE: Branchless mask logic for smoother performance.
*/

#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.30 1.0 2.5 0.05
#pragma parameter SCAN_STR "Scanline Intensity (0=OFF)" 0.30 0.0 1.0 0.05

// --- Code 7 Mathematical Mask Parameters ---
#pragma parameter MASK_DARK "Mask Dark Level" 0.5 0.0 1.0 0.05
#pragma parameter MASK_LIGHT "Mask Light Level" 1.5 0.0 2.0 0.05

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
precision lowp float;
#endif

varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;

#ifdef PARAMETER_UNIFORM
// تنظيف البارميترات وحذف متغير الـ distortion
uniform float BRIGHT_BOOST,  SCAN_STR, MASK_DARK, MASK_LIGHT;
#endif

void main() {
    vec2 sc = TextureSize / InputSize;
    vec2 p = (uv * sc) - 0.5;
    vec2 p2 = p * p;

    // 1. Geometry (Flat Coordinates - تم تثبيت الأبعاد المسطحة وإلغاء الكيرف)
    vec2 p_flat = p;

    if (abs(p_flat.x) > 0.5 || abs(p_flat.y) > 0.5) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    vec2 final_uv = (p_flat + 0.5) / sc;
    vec2 uv_pixels = final_uv * TextureSize;

    // 2. فصل الجزء الصحيح (i) والجزء العشري (f) للفلاتر الحادة
    vec2 i = floor(uv_pixels);
    vec2 f = uv_pixels - i;

    // 3. تطبيق معادلة Smoothstep لمنع تداخل البكسلات والحفاظ على حدة الصورة
    vec2 f_smooth = f * f * (3.0 - 2.0 * f);

    // 4. دمج الإحداثيات المنعمة وإرجاعها لمساحة الـ UV
    vec2 uv_final = (i + f_smooth) / TextureSize;

    // 5. سحب العينة النهائي الصافي من النسيج المسطح
    vec3 res = texture2D(Texture, uv_final).rgb;



    // 4. Scanlines (مربوطة الآن بالإحداثيات المسطحة بشكل مثالي)
    if (SCAN_STR > 0.0) {
        float pixel_y = (p_flat.y + 0.5) * InputSize.y;
        
        // إنشاء موجة السكان لاين (خط لكل بكسل لعبة)
        float scan = sin(pixel_y * 6.283185) * 0.5 + 0.5;
        
        // عملية ضرب مباشر
        res *= mix(1.0, scan, SCAN_STR);
    }

    // 5. TRUE RGB MASK (EXACT CLONE FROM 7 - سليم دون تغيير)
    vec3 mcol = vec3(0.0);
    mcol[int(mod(gl_FragCoord.x, 3.0))] = 1.0;

    // تطبيق نظام Dark-Light
    vec3 mask_weight = mix(vec3(MASK_DARK), vec3(MASK_LIGHT), mcol);

    // اضرب النتيجة النهائية في بكسل الصورة
    res *= mask_weight;

    // 6. FINAL STAGE
    gl_FragColor = vec4(res * BRIGHT_BOOST, 1.0);
}
#endif