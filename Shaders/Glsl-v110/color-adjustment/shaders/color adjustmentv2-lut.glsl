#version 110

/*
    LIGHT-ULTIMATE (Turbo-E Zero-Load Edition)
    - HARDWARE BYPASS: No LUT overhead when disabled.
    - 0-POW GLOW: Fifth-power logic (r2*r2*res) for surgically clean highlights.
    - OPTIMIZED: High-performance 3D LUT sampling for Mali/Adreno.
*/

// --- 1. LUT Parameters ---
#pragma parameter CLU_LUT_Size "LUT: Size (16, 32, 64)" 32.0 1.0 64.0 1.0
#pragma parameter CLU_LUT_SEL "LUT: Switch (-1:Off, 0:On)" -1.0 -1.0 0.0 1.0
#pragma parameter CLU_LUT_OPACITY "LUT: Opacity" 1.0 0.0 1.0 0.05

// --- 2. CRT Display Parameters ---
#pragma parameter CLU_GAMMA "CRT: Gamma (Darken)" 0.5 0.0 1.0 0.05
#pragma parameter CLU_CONTRAST "CRT: Contrast" 1.10 0.5 2.0 0.05
#pragma parameter CLU_SATURATION "CRT: Saturation" 1.3 0.0 2.0 0.05
#pragma parameter CLU_BRIGHT "CRT: Brightness" 1.1 1.0 2.0 0.05
#pragma parameter CLU_GLOW "CRT: Glow Strength (0=OFF)" 0.15 0.0 1.5 0.05
#pragma parameter CLU_HALATION "CRT: Halation (0=OFF)" 0.15 0.0 1.0 0.02
#pragma parameter CLU_BLK_D "CRT: Black Depth" 0.20 0.0 1.0 0.05

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
uniform sampler2D SamplerLUT1;

#ifdef PARAMETER_UNIFORM
uniform float CLU_LUT_Size, CLU_LUT_SEL, CLU_LUT_OPACITY;
uniform float CLU_GAMMA, CLU_CONTRAST, CLU_SATURATION, CLU_BRIGHT, CLU_GLOW, CLU_HALATION, CLU_BLK_D;
#endif

varying vec2 TEX0;

vec3 apply_3d_lut(sampler2D sampler, vec3 color, float size) {
    float red = (color.r * (size - 1.0) + 0.4999) / (size * size);
    float green = (color.g * (size - 1.0) + 0.4999) / size;
    float blue = color.b * (size - 1.0);
    float b_low = floor(blue) / size;
    float b_high = ceil(blue) / size;
    vec4 c1 = texture2D(sampler, vec2(b_low + red, green));
    vec4 c2 = texture2D(sampler, vec2(b_high + red, green));
    return mix(c1.rgb, c2.rgb, fract(blue));
}

void main() {
    vec4 texel = texture2D(Texture, TEX0);
    vec3 res = texel.rgb;

    // [1] Zero-Pow Gamma & Linearize
    // خلط تربيعي سريع جداً للتحكم في عمق الظلال
    vec3 res_sq = res * res;
    res = mix(res, res_sq, CLU_GAMMA);

    // [2] LUT Bypass Engine
    // تخطي كامل لعمليات البحث في الأنسجة (Texture Lookups) إذا كان الـ LUT معطلاً
    if (CLU_LUT_SEL > -0.5 && CLU_LUT_OPACITY > 0.0) {
        vec3 l_res = apply_3d_lut(SamplerLUT1, clamp(res, 0.0, 1.0), CLU_LUT_Size);
        res = mix(res, l_res, CLU_LUT_OPACITY);
    }

    // [3] Contrast & Saturation Core
    res = (res - 0.5) * CLU_CONTRAST + 0.5;
    // معامل Luma متوازن لضمان ثبات الألوان
    float luma = dot(res, vec3(0.2126, 0.7152, 0.0722)); 
    res = mix(vec3(luma), res, CLU_SATURATION);

    // [4] Black Depth (Shadow Mask)
    res *= (1.0 - CLU_BLK_D * (1.0 - luma));

    // [5] Zero-Pow Glow Mask (Targeting High Luminance)
    // حساب (x^5) عبر الضرب المباشر؛ هذا يضمن أن التوهج يصيب البياض الناصع فقط
    if (CLU_GLOW > 0.0) {
        vec3 r2 = res * res;
        vec3 highlight_mask = (r2 * r2) * res; 
        res += highlight_mask * (CLU_GLOW + highlight_mask * CLU_HALATION);
    }
    
    res *= CLU_BRIGHT;

    // [6] Output Gamma (Fast Sqrt)
    gl_FragColor = vec4(sqrt(max(res, 0.0)), texel.a);
}
#endif