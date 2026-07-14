#version 110

/* 777-CRT-ANALOG-MASTER (MATRIX ONLY - CLEAN & OPTIMIZED)
    - PERFORMANCE: Uses mat3 for hardware-accelerated color transformations.
    - PRECISION: Fixed Column-Major matrix layout for exact color reproduction.
    - FLOW: Color Matrix -> Contrast/Brightness -> Saturation -> Gamma.
*/

// Color Adjustment Parameters
#pragma parameter CLR_SAT "Saturation" 1.0 0.0 2.0 0.05
#pragma parameter CLR_CONT "Contrast" 1.0 0.0 2.0 0.05
#pragma parameter CLR_BRIGHT "Brightness" 0.0 -0.5 0.5 0.01
#pragma parameter CLR_BLK_LVL "Black Level" 0.0 -0.5 0.5 0.01
#pragma parameter CLR_GAMMA "Gamma Correction" 1.0 0.1 3.0 0.1

// Matrix Parameters (9x9)
#pragma parameter rr "Red -> Red" 1.0 -2.0 2.0 0.05
#pragma parameter rg "Green -> Red" 0.0 -2.0 2.0 0.05
#pragma parameter rb "Blue -> Red" 0.0 -2.0 2.0 0.05
#pragma parameter gr "Red -> Green" 0.0 -2.0 2.0 0.05
#pragma parameter gg "Green -> Green" 1.0 -2.0 2.0 0.05
#pragma parameter gb "Blue -> Green" 0.0 -2.0 2.0 0.05
#pragma parameter br "Red -> Blue" 0.0 -2.0 2.0 0.05
#pragma parameter bg "Green -> Blue" 0.0 -2.0 2.0 0.05
#pragma parameter bb "Blue -> Blue" 1.0 -2.0 2.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    uv = TexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D Texture;
varying vec2 uv;

#ifdef PARAMETER_UNIFORM
uniform float CLR_SAT, CLR_CONT, CLR_BRIGHT, CLR_BLK_LVL, CLR_GAMMA;
uniform float rr, rg, rb, gr, gg, gb, br, bg, bb;
#endif

void main() {
    // [1] سحب اللون الخام
    vec3 col = texture2D(Texture, uv).rgb;

    // [2] مصفوفة الألوان بنظام mat3 (أسرع وأدق)
    // ملاحظة: الترتيب هنا يتبع نظام Column-Major لضمان مطابقة الـ Parameters
    mat3 color_matrix = mat3(
        rr, gr, br,  // تأثير قناة الأحمر على (R, G, B)
        rg, gg, bg,  // تأثير قناة الأخضر على (R, G, B)
        rb, gb, bb   // تأثير قناة الأزرق على (R, G, B)
    );
    
    col = col * color_matrix;

    // [3] السطوع والتباين (Brightness & Contrast)
    // الترتيب الصحيح: إضافة السطوع أولاً ثم تعديل التباين حول نقطة المنتصف
    col += CLR_BRIGHT;
    col = (col - 0.5) * CLR_CONT + 0.5;

    // [4] مستوى السواد (Black Level)
    // يساعد في تعميق المناطق المظلمة دون التأثير على الألوان الساطعة
    col += CLR_BLK_LVL;

    // [5] التشبع (Saturation)
    // استخدام المعاملات المعيارية للإضاءة (Luma Coefficients)
    vec3 lum_coeff = vec3(0.299, 0.587, 0.114);
    float luma = dot(col, lum_coeff);
    col = mix(vec3(luma), col, CLR_SAT);

    // [6] تصحيح الجاما (Gamma Correction)
    // Clamp لضمان عدم خروج القيم عن النطاق (0-1) قبل الـ pow
    col = pow(clamp(col, 0.0, 1.0), vec3(CLR_GAMMA));

    // [7] الخرج النهائي
    gl_FragColor = vec4(col, 1.0);
}
#endif