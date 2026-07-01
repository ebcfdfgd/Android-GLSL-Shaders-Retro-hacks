#version 110

/* 777-CRT-ANALOG-MASTER + CENTRAL RADIAL GLOW
    - COMBINED: Matrix Color Precision + Central Radial Glow.
    - SPEED: Zero branches, single texture fetch.
    - LOGIC: Glow is strongest at center and fades out (Radial Falloff).
*/

// Color Adjustment Parameters
#pragma parameter CLR_SAT "Saturation" 1.0 0.0 2.0 0.05
#pragma parameter CLR_CONT "Contrast" 1.0 0.0 2.0 0.05
#pragma parameter CLR_BRIGHT "Brightness" 0.0 -0.5 0.5 0.01
#pragma parameter CLR_BLK_LVL "Black Level" 0.0 -0.5 0.5 0.01
#pragma parameter CLR_GAMMA "Gamma Correction" 1.0 0.1 3.0 0.1

// Central Glow Parameter
#pragma parameter GLOW_STR "Central Glow Intensity" 0.3 0.0 1.0 0.05

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
varying vec2 p_pos; // متغير لنقل موضع البكسل بالنسبة للمركز
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    uv = TexCoord;
    p_pos = TexCoord - 0.5; // تحديد المركز عند (0,0)
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D Texture;
varying vec2 uv;
varying vec2 p_pos;

#ifdef PARAMETER_UNIFORM
uniform float CLR_SAT, CLR_CONT, CLR_BRIGHT, CLR_BLK_LVL, CLR_GAMMA;
uniform float rr, rg, rb, gr, gg, gb, br, bg, bb;
uniform float GLOW_STR;
#endif

void main() {
    // [1] سحب اللون الخام
    vec3 col = texture2D(Texture, uv).rgb;

    // [2] مصفوفة الألوان (mat3)
    mat3 color_matrix = mat3(rr, gr, br, rg, gg, bg, rb, gb, bb);
    col = col * color_matrix;

    // [3] التوهج المركزي (Central Radial Glow)
    // حساب المسافة من المركز (r2)
    float r2 = dot(p_pos, p_pos);
    // حساب الإضاءة (Luma)
    float luma = dot(col, vec3(0.299, 0.587, 0.114));
    // حساب التلاشي الشعاعي (Radial Falloff) - يتلاشى كلما ابتعدنا عن المركز
    float radial = max(0.0, 1.0 - r2 * 3.0); 
    // دمج التوهج: يعتمد على السطوع + القوة + مكانه في الشاشة
    col += (col * luma * GLOW_STR) * radial;

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