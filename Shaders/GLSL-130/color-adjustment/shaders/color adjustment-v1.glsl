#version 110

/*
    CRT-LIGHT-ULTIMATE (Pro-E Edition)
    - Focused Glow & Halation on High Luminance (Square E).
    - Preserves Mid-tones and Brick Red (Square D).
    - Optimized for Speed.
*/

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
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 TEX0;
uniform mat4 MVPMatrix;

void main() {
    TEX0 = TexCoord;
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D Texture;
varying vec2 TEX0;

#ifdef PARAMETER_UNIFORM
uniform float CLU_R_GAIN, CLU_G_GAIN, CLU_B_GAIN;
uniform float CLU_CONTRAST, CLU_SATURATION, CLU_BRIGHT, CLU_GLOW, CLU_HALATION, CLU_BLK_D;
#endif

void main() {
    vec4 texel = texture2D(Texture, TEX0);
    vec3 res = texel.rgb;

    // 1. Linearize
    res = res * res;

    // 2. Manual RGB Gain
    res *= vec3(CLU_R_GAIN, CLU_G_GAIN, CLU_B_GAIN);

    // 3. Contrast & Saturation
    res = (res - 0.5) * CLU_CONTRAST + 0.5;
    float luma = dot(res, vec3(0.25, 0.5, 0.25)); 
    res = mix(vec3(luma), res, CLU_SATURATION);

    // 4. Black Depth
    res *= (1.0 - CLU_BLK_D * (1.0 - luma));

    // 5. THE FIX: High-Luma Focused Glow (E-Square Targeting)
    // نستخدم الـ Power لفلترة الـ Glow بحيث يظهر فقط عند القيم القريبة من 1.0
    vec3 glow_mask = pow(max(res, 0.0), vec3(4.0)); // عتبة قوية لاستهداف الـ E
    res += glow_mask * (CLU_GLOW + glow_mask * CLU_HALATION);
    
    res *= CLU_BRIGHT;

    // 6. Output Gamma (Fast Sqrt)
    gl_FragColor = vec4(sqrt(max(res, 0.0)), texel.a);
}
#endif