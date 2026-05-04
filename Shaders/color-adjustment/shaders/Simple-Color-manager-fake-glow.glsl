#version 110

/* 777-CRT-ANALOG-MASTER + LUMINANCE GLOW (NO SAMPLES)
    - PERFORMANCE: ZERO additional texture fetches.
    - MATH: Uses non-linear scaling to make highlights "pop".
*/

// Color Adjustment Parameters
#pragma parameter CLR_SAT "Saturation" 1.0 0.0 2.0 0.05
#pragma parameter CLR_CONT "Contrast" 1.0 0.0 2.0 0.05
#pragma parameter CLR_BRIGHT "Brightness" 0.0 -0.5 0.5 0.01
#pragma parameter CLR_BLK_LVL "Black Level" 0.0 -0.5 0.5 0.01
#pragma parameter CLR_GAMMA "Gamma Correction" 1.0 0.1 3.0 0.1

// Fake Bloom (Glow) Parameters
#pragma parameter GLOW_STR "Glow Intensity" 0.15 0.0 1.0 0.05
#pragma parameter GLOW_CUT "Glow Threshold" 0.6 0.0 1.0 0.05

// Matrix Parameters (3x3)
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
uniform float GLOW_STR, GLOW_CUT;
#endif

void main() {
    // [1] سحب اللون الخام (سحبة واحدة فقط)
    vec3 col = texture2D(Texture, uv).rgb;

    // [2] مصفوفة الألوان (mat3)
    mat3 color_matrix = mat3(rr, gr, br, rg, gg, bg, rb, gb, bb);
    col = col * color_matrix;

    // [3] نظام الـ Glow الرياضي (بدون Samples)
    // بنحسب شدة الإضاءة الحالية للبكسل
    float luma_glow = dot(col, vec3(0.299, 0.587, 0.114));
    
    // بنطلع "الزيادة" فوق حد معين (Threshold) ونربعها عشان التوهج يبقى ناعم
    float glow = max(luma_glow - GLOW_CUT, 0.0);
    vec3 glow_add = col * (glow * glow * GLOW_STR * 10.0);
    
    // بنضيف التوهج للصورة الأصلية
    col += glow_add;

    // [4] السطوع والتباين
    col += CLR_BRIGHT;
    col = (col - 0.5) * CLR_CONT + 0.5;

    // [5] مستوى السواد
    col += CLR_BLK_LVL;

    // [6] التشبع
    float luma_final = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(vec3(luma_final), col, CLR_SAT);

    // [7] تصحيح الجاما
    col = pow(clamp(col, 0.0, 1.0), vec3(CLR_GAMMA));

    gl_FragColor = vec4(col, 1.0);
}
#endif