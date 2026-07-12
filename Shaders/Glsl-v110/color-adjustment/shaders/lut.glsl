#version 110

/* 777-COLOR-LUT-CLEAN
   - OPTIMIZED: Pipeline strictly limited to LUT and essential post-processing.
*/

// --- 1. Shader Parameters ---
#pragma parameter CLU_LUT_Size "LUT: Size (16, 32, 64)" 32.0 4.0 64.0 4.0
#pragma parameter CLU_LUT_OPACITY "LUT: Opacity" 1.0 0.0 1.0 0.05

//#pragma parameter CLR_SAT "Saturation" 1.0 0.0 2.0 0.05


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

uniform float CLU_LUT_Size, CLU_LUT_OPACITY;
uniform float  CLR_SAT;

// [LUT Helper]
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
    vec3 col = texture2D(Texture, uv).rgb;
    vec3 lum_coeff = vec3(0.299, 0.587, 0.114);

    // 1. LUT Engine
    if (CLU_LUT_OPACITY > 0.0) {
        vec3 l_res = apply_3d_lut(SamplerLUT1, clamp(col, 0.0, 1.0), CLU_LUT_Size);
        col = mix(col, l_res, CLU_LUT_OPACITY);
    }

    // 3. Saturation
   // float luma_sat = dot(col, lum_coeff);
   // col = mix(vec3(luma_sat), col, CLR_SAT);

    // 5. Output
    gl_FragColor = vec4(col, 1.0);
}
#endif