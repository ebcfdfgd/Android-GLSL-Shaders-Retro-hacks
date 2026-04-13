#version 130

/*
    CRT-LIGHT-ULTIMATE (Simple Gamma Edition - v130)
    - Updated: GLSL 1.30 modern syntax.
    - Added: Simple Gamma Parameter for Mid-tone control.
    - Optimized for Speed and Linear Accuracy.
*/

// --- Parameters ---
#pragma parameter CLU_GAMMA "CRT Gamma Curve" 2.2 1.0 3.5 0.05
#pragma parameter CLU_R_GAIN "Red Channel Gain" 1.0 0.0 2.0 0.02
#pragma parameter CLU_G_GAIN "Green Channel Gain" 1.0 0.0 2.0 0.02
#pragma parameter CLU_B_GAIN "Blue Channel Gain" 1.0 0.0 2.0 0.02

#pragma parameter CLU_CONTRAST "CRT Contrast" 1.10 0.5 2.0 0.05
#pragma parameter CLU_SATURATION "CRT Saturation" 1.3 0.0 2.0 0.05
#pragma parameter CLU_BRIGHT "CRT Brightness" 1.1 1.0 2.0 0.05
#pragma parameter CLU_GLOW "CRT Glow Strength" 0.15 0.0 1.5 0.05
#pragma parameter CLU_HALATION "CRT Halation Strength" 0.15 0.0 1.0 0.02
#pragma parameter CLU_BLK_D "CRT Black Depth" 0.20 0.0 1.0 0.05

#if defined(VERTEX)
in vec4 VertexCoord;
in vec2 TexCoord;
out vec2 TEX0;
uniform mat4 MVPMatrix;

void main() {
    TEX0 = TexCoord;
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
precision highp float;

in vec2 TEX0;
out vec4 FragColor;

uniform sampler2D Texture;

#ifdef PARAMETER_UNIFORM
uniform float CLU_GAMMA;
uniform float CLU_R_GAIN, CLU_G_GAIN, CLU_B_GAIN;
uniform float CLU_CONTRAST, CLU_SATURATION, CLU_BRIGHT, CLU_GLOW, CLU_HALATION, CLU_BLK_D;
#endif

void main() {
    // استخدام texture بدلاً من texture2D في إصدار 130
    vec4 texel = texture(Texture, TEX0);
    vec3 res = texel.rgb;

    // 1. Linearize using Dynamic Gamma
    res = pow(max(res, 0.0), vec3(CLU_GAMMA));

    // 2. Manual RGB Gain
    res *= vec3(CLU_R_GAIN, CLU_G_GAIN, CLU_B_GAIN);

    // 3. Contrast & Saturation
    res = (res - 0.5) * CLU_CONTRAST + 0.5;
    float luma = dot(res, vec3(0.299, 0.587, 0.114)); 
    res = mix(vec3(luma), res, CLU_SATURATION);

    // 4. Black Depth
    res *= (1.0 - CLU_BLK_D * (1.0 - luma));

    // 5. High-Luma Focused Glow
    vec3 glow_mask = pow(max(res, 0.0), vec3(4.0)); 
    res += glow_mask * (CLU_GLOW + glow_mask * CLU_HALATION);
    
    res *= CLU_BRIGHT;

    // 6. Output Gamma (Inverse Correction)
    // تم ربط المخرج بـ 1.0/CLU_GAMMA لضمان توازن السطوع المرتد
    FragColor = vec4(pow(max(res, 0.0), vec3(1.0 / CLU_GAMMA)), texel.a);
}
#endif