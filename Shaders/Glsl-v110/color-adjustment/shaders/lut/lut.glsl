#version 110

/* 777-MINIMAL-LUT
    - PURE PIPELINE: 3D LUT Lookup only.
    - CONTROL: Opacity slider acts as both intensity and toggle (0.0 = Off).
*/

// --- Shader Parameters ---
#pragma parameter CLU_LUT_Size "LUT: Size (16, 32, 64)" 32.0 4.0 64.0 4.0
#pragma parameter CLU_LUT_OPACITY "LUT: Opacity/Intensity" 1.0 0.0 1.0 0.05

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
varying vec2 uv;

#ifdef PARAMETER_UNIFORM
uniform float CLU_LUT_Size, CLU_LUT_OPACITY;
#endif

// [LUT Engine]
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
    // 1. جلب اللون الخام
    vec3 raw_col = texture2D(Texture, uv).rgb;

    // 2. تطبيق الـ LUT والدمج بناءً على الشفافية مباشرة
    // إذا كانت الشفافية 0، سيعود اللون الخام كما هو تلقائياً
    vec3 lut_res = apply_3d_lut(SamplerLUT1, clamp(raw_col, 0.0, 1.0), CLU_LUT_Size);
    vec3 final_col = mix(raw_col, lut_res, CLU_LUT_OPACITY);

    // 3. المخرج النهائي
    gl_FragColor = vec4(final_col, 1.0);
}
#endif