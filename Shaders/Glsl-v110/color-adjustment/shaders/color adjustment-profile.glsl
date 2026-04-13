#version 110

/* CRT-LIGHT-ULTIMATE (Pro-E Zero-Load Edition)
    - HARDWARE BYPASS: Skips color matrix math if Profile is 0.
    - ZERO-POW CORE: Multiplier-based gamma for zero-lag response.
    - OPTIMIZED: Designed specifically for Mali/Adreno mobile GPUs.
*/

#pragma parameter CLU_GAMMA "CRT Gamma (Darken)" 0.5 0.0 1.0 0.05
#pragma parameter CLU_PROFILE "Profile: 0:Raw, 1:EU, 2:US, 3:JP" 0.0 0.0 3.0 1.0
#pragma parameter CLU_CONTRAST "CRT Contrast" 1.10 0.5 2.0 0.05
#pragma parameter CLU_SATURATION "CRT Saturation" 1.3 0.0 2.0 0.05
#pragma parameter CLU_BRIGHT "CRT Brightness" 1.1 1.0 2.0 0.05
#pragma parameter CLU_GLOW "CRT Glow (0=OFF)" 0.15 0.0 1.5 0.05
#pragma parameter CLU_HALATION "CRT Halation (0=OFF)" 0.15 0.0 1.0 0.02
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
uniform float CLU_GAMMA, CLU_PROFILE, CLU_CONTRAST, CLU_SATURATION, CLU_BRIGHT, CLU_GLOW, CLU_HALATION, CLU_BLK_D;
#endif

void main() {
    vec4 texel = texture2D(Texture, TEX0);
    vec3 res = texel.rgb;

    // [1] Zero-Pow Gamma (Darken Logic)
    // خلط تربيعي بدلاً من pow() المكلفة برمجياً
    vec3 res_sq = res * res;
    res = mix(res, res_sq, CLU_GAMMA);

    // [2] Color Profiles Bypass
    if (CLU_PROFILE > 0.5) {
        if (CLU_PROFILE < 1.5) { // EU/PAL Profile
            res = clamp(res * mat3(0.98, 0.02, 0.0, 0.02, 0.96, 0.02, 0.0, 0.02, 0.96), 0.0, 1.0);
        } 
        else if (CLU_PROFILE < 2.5) { // US/NTSC Profile (SMPTE)
            res = clamp(res * mat3(0.95, 0.05, 0.0, 0.02, 0.98, 0.0, 0.0, 0.05, 0.95), 0.0, 1.0);
        } 
        else { // JP/NTSC-J Profile
            res = clamp(res * mat3(0.9, 0.1, 0.0, 0.05, 0.9, 0.05, 0.0, 0.1, 1.1), 0.0, 1.0);
        }
    }

    // [3] Contrast & Saturation Core
    res = (res - 0.5) * CLU_CONTRAST + 0.5;
    float luma = dot(res, vec3(0.299, 0.587, 0.114)); 
    res = mix(vec3(luma), res, CLU_SATURATION);

    // [4] Black Depth (CRT Phosphor Feel)
    res *= (1.0 - CLU_BLK_D * (1.0 - luma));

    // [5] Optimized Glow Bypass
    if (CLU_GLOW > 0.0) {
        // استخدام التربيع المزدوج لمحاكاة التوهج بدون عمليات أسية معقدة
        vec3 r2 = res * res;
        vec3 glow_mask = r2 * r2; 
        res += glow_mask * (CLU_GLOW + glow_mask * CLU_HALATION);
    }

    res *= CLU_BRIGHT;

    // [6] Output Gamma (Fast Sqrt)
    // تعويض الغاما النهائي باستخدام الجذر التربيعي السريع
    gl_FragColor = vec4(sqrt(max(res, 0.0)), texel.a);
}
#endif