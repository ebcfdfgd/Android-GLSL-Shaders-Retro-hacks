#version 110

/* 777-CRT-ANALOG-MASTER (RAW SIGNAL + CENTRAL BLOOM)
    - ADDED: Central Radial Glow (Bloom).
    - OPTIMIZED: Branchless Luma calculation.
    - LOGIC: Glow intensity is tied to pixel brightness and center proximity.
*/

// --- BLOOM PARAMETERS ---
#pragma parameter GLOW_STR "Central Glow Intensity" 0.35 0.0 1.0 0.05

// Color Adjustment Parameters (Global Signal Only)
#pragma parameter CLR_SAT "Saturation" 1.0 0.0 2.0 0.05
#pragma parameter CLR_CONT "Contrast" 1.0 0.0 2.0 0.05
#pragma parameter CLR_BRIGHT "Brightness" 0.0 -0.5 0.5 0.01
#pragma parameter CLR_BLK_LVL "Black Level" 0.0 -0.5 0.5 0.01
#pragma parameter CLR_GAMMA "Gamma Correction" 1.0 0.1 3.0 0.1

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
varying vec2 p_pos; // الإحداثيات بالنسبة للمركز
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    uv = TexCoord;
    p_pos = TexCoord - 0.5; // تحديد نقطة الصفر في منتصف الشاشة
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D Texture;
varying vec2 uv, p_pos;

#ifdef PARAMETER_UNIFORM
uniform float GLOW_STR, CLR_SAT, CLR_CONT, CLR_BRIGHT, CLR_BLK_LVL, CLR_GAMMA;
#endif

void main() {
    // 1. سحب اللون الخام وتعريف ثوابت الإضاءة
    vec3 col = texture2D(Texture, uv).rgb;
    vec3 lum_coeff = vec3(0.299, 0.587, 0.114);

    // 2. منطق البلوم الشعاعي (Central Radial Glow)
    // حساب المسافة المربعة من المركز (r2)
    float r2 = dot(p_pos, p_pos);
    // حساب السطوع الحالي للبكسل
    float luma = dot(col, lum_coeff);
    // دالة التلاشي الشعاعي (Radial Falloff)
    float radial = max(0.0, 1.0 - r2 * 3.0); 
    // إضافة التوهج بناءً على (اللون * السطوع * القوة * مكان البكسل)
    col += (col * luma * GLOW_STR) * radial;

    // 3. Brightness & Contrast (Global)
    col += CLR_BRIGHT;
    col = (col - 0.5) * CLR_CONT + 0.5;

    // 4. Black Level (Global Adjustment)
    col += CLR_BLK_LVL;

    // 5. Saturation (Luminance based)
    float luma_final = dot(col, lum_coeff);
    col = mix(vec3(luma_final), col, CLR_SAT);

    // 6. Gamma Correction
    col = pow(clamp(col, 0.0, 1.0), vec3(CLR_GAMMA));

    // 7. Output
    gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
#endif