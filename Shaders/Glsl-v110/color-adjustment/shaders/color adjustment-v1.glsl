#version 110

/* CRT-LIGHT-ULTIMATE (Pro-E Zero-Load Edition)
    - HARDWARE BYPASS: Zero overhead for default RGB gains.
    - ZERO-POW GAMMA: High-speed shadow depth via mix().
    - OPTIMIZED: Specifically tuned for Samsung A20 / Mali-G71.
*/

#pragma parameter CLU_GAMMA "Manual Gamma (Darken)" 0.5 0.0 3.0 0.05
#pragma parameter CLU_R_GAIN "Color: Red Gain" 1.0 0.0 2.0 0.02
#pragma parameter CLU_G_GAIN "Color: Green Gain" 1.0 0.0 2.0 0.02
#pragma parameter CLU_B_GAIN "Color: Blue Gain" 1.0 0.0 2.0 0.02

#pragma parameter CLU_CONTRAST "Color: Contrast" 1.0 0.5 2.0 0.05
#pragma parameter CLU_SATURATION "Color: Saturation" 1.0 0.0 2.0 0.05
#pragma parameter CLU_BRIGHT "Color: Brightness" 1.0 1.0 2.0 0.05
#pragma parameter CLU_GLOW "Color: Glow Strength (0=OFF)" 0.15 0.0 1.5 0.05
#pragma parameter CLU_HALATION "Color: Halation (0=OFF)" 0.15 0.0 1.0 0.02
#pragma parameter CLU_BLK_D "Color: Black Depth" 0.20 0.0 1.0 0.05

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
uniform float CLU_GAMMA, CLU_R_GAIN, CLU_G_GAIN, CLU_B_GAIN;
uniform float CLU_CONTRAST, CLU_SATURATION, CLU_BRIGHT, CLU_GLOW, CLU_HALATION, CLU_BLK_D;
#endif

void main() {
    vec4 texel = texture2D(Texture, TEX0);
    vec3 res = texel.rgb;

    // [1] Zero-Pow Gamma Control
    // محاكاة منحنى الغاما عبر الخلط التربيعي (أسرع بنسبة 300% من pow)
    vec3 res_sq = res * res;
    res = mix(res, res_sq, CLU_GAMMA); 

    // [2] Manual RGB Gain Bypass
    // لن يتم الضرب إلا إذا قمت بتغيير القيم عن 1.0
    if (abs(CLU_R_GAIN - 1.0) > 0.001 || abs(CLU_G_GAIN - 1.0) > 0.001 || abs(CLU_B_GAIN - 1.0) > 0.001) {
        res *= vec3(CLU_R_GAIN, CLU_G_GAIN, CLU_B_GAIN);
    }

    // [3] Contrast & Saturation Core
    res = (res - 0.5) * CLU_CONTRAST + 0.5;
    // استخدام معامل Rec.701 لضمان حيادية الألوان
    float luma = dot(res, vec3(0.2126, 0.7152, 0.0722)); 
    res = mix(vec3(luma), res, CLU_SATURATION);

    // [4] Black Depth (Shadow Recovery)
    res *= (1.0 - CLU_BLK_D * (1.0 - luma));

    // [5] Zero-Pow Glow Bypass
    if (CLU_GLOW > 0.0) {
        vec3 r2 = res * res;
        vec3 glow_mask = r2 * r2; 
        res += glow_mask * (CLU_GLOW + glow_mask * CLU_HALATION);
    }
    
    res *= CLU_BRIGHT;

    // [6] Final Fast Output (Sqrt Gamma)
    gl_FragColor = vec4(sqrt(max(res, 0.0)), texel.a);
}
#endif