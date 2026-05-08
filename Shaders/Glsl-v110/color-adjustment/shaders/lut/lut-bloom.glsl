#version 110

/* 777-LUT-CENTRAL-BLOOM
    - Pipeline: 3D LUT Lookup -> Central Radial Glow.
    - Logic: Glow intensity is tied to pixel brightness and center proximity.
*/

// --- Shader Parameters ---
#pragma parameter CLU_LUT_Size "LUT: Size (16, 32, 64)" 32.0 4.0 64.0 4.0
#pragma parameter CLU_LUT_OPACITY "LUT: Opacity/Intensity" 1.0 0.0 1.0 0.05
#pragma parameter GLOW_STR "Central Glow Intensity" 0.35 0.0 1.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
varying vec2 p_pos; // الإحداثيات بالنسبة للمركز
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    uv = TexCoord;
    p_pos = TexCoord - 0.5; // نقطة الصفر في منتصف الشاشة
}

#elif defined(FRAGMENT)
precision highp float;

uniform sampler2D Texture;
uniform sampler2D SamplerLUT1; 
varying vec2 uv, p_pos;

#ifdef PARAMETER_UNIFORM
uniform float CLU_LUT_Size, CLU_LUT_OPACITY, GLOW_STR;
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
    // 1. جلب اللون الخام وتطبيق الـ LUT
    vec3 raw_col = texture2D(Texture, uv).rgb;
    vec3 lut_res = apply_3d_lut(SamplerLUT1, clamp(raw_col, 0.0, 1.0), CLU_LUT_Size);
    vec3 col = mix(raw_col, lut_res, CLU_LUT_OPACITY);

    // 2. منطق البلوم المركزي (Central Radial Glow)
    vec3 lum_coeff = vec3(0.299, 0.587, 0.114);
    float r2 = dot(p_pos, p_pos);
    float luma = dot(col, lum_coeff);
    
    // دالة التلاشي الشعاعي (Radial Falloff)
    float radial = max(0.0, 1.0 - r2 * 3.0); 
    
    // إضافة التوهج بناءً على (اللون المعدل باللوت * السطوع * القوة * مكان البكسل)
    col += (col * luma * GLOW_STR) * radial;

    // 3. المخرج النهائي
    gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
#endif