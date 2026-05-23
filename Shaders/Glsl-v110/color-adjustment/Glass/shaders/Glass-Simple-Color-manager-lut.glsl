#version 110

/* 777-LUT-READY-SIGNAL + OPACITY
    - Features: 3D LUT Lookup with Opacity control + Pass 20 Glass Overlays.
    - Baked: Gamma/Sat/Bright are inside the LUT PNG.
*/

#pragma parameter CLU_LUT_Size "LUT: Size (16, 32, 64)" 32.0 4.0 64.0 4.0
#pragma parameter CLU_LUT_OPACITY "LUT: Opacity" 1.0 0.0 1.0 0.05
#pragma parameter GLASS_STR "Glass Reflection Strength" 0.15 0.0 1.0 0.05
#pragma parameter BORDER_GLOSS "Edge Gloss Intensity" 0.20 0.0 1.0 0.05

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
precision highp float;

uniform sampler2D Texture;
uniform sampler2D SamplerLUT1; 
uniform vec2 TextureSize, InputSize;
varying vec2 uv;

#ifdef PARAMETER_UNIFORM
uniform float CLU_LUT_Size, CLU_LUT_OPACITY, GLASS_STR, BORDER_GLOSS;
#endif

// وظيفة محرك الـ LUT
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
    // 1. جلب اللون الخام من اللعبة
    vec3 raw_col = texture2D(Texture, uv).rgb;

    // 2. معالجة اللوت مع التحكم في الشفافية
    vec3 lut_col = apply_3d_lut(SamplerLUT1, clamp(raw_col, 0.0, 1.0), CLU_LUT_Size);
    
    // دمج اللون الخام مع لون اللوت بناءً على الشفافية
    vec3 col = mix(raw_col, lut_col, CLU_LUT_OPACITY);

    // 3. إضافة تأثيرات الزجاج (Pass 20)
    vec2 sc = TextureSize / InputSize;
    vec2 p = (uv * sc) - 0.5;
    float r2 = dot(p, p);

    float fresnel = pow(r2 * 2.2, 2.0) * BORDER_GLOSS;
    float spec = smoothstep(0.4, 0.0, length(p - vec2(-0.35, 0.35)));
    spec *= 0.15 * GLASS_STR;
    float gloss = (1.0 - length(p)) * 0.05 * GLASS_STR;

    // النتيجة النهائية
    vec3 final_color = col + fresnel + spec + gloss;

    gl_FragColor = vec4(final_color, 1.0);
}
#endif