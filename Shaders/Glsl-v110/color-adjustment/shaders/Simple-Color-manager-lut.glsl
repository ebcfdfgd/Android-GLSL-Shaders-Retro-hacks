#version 110

/* 777-COLOR-BLOOM-LUT-MASTER (Optimized)
    - OPTIMIZED: Uniform Branch Bypass (Zero cost when LUT is OFF).
    - LUT ENGINE: Only executes if CLU_LUT_SEL is 1.0.
*/

// --- 1. Shader Parameters ---
#pragma parameter CLU_LUT_Size "LUT: Size (16, 32, 64)" 32.0 1.0 64.0 1.0
#pragma parameter CLU_LUT_SEL "LUT: Switch (0:Off, 1:On)" 0.0 0.0 1.0 1.0
#pragma parameter CLU_LUT_OPACITY "LUT: Opacity" 1.0 0.0 1.0 0.05

#pragma parameter CLR_SAT "Saturation" 1.0 0.0 2.0 0.05
#pragma parameter CLR_CONT "Contrast" 1.0 0.0 2.0 0.05
#pragma parameter CLR_BRIGHT "Brightness" 0.0 -0.5 0.5 0.05
#pragma parameter CLU_BLK_D "CRT Black Depth" 0.0 0.0 1.0 0.05
#pragma parameter CLR_GAMMA "Gamma Correction" 1.0 0.1 3.0 0.1
#pragma parameter CLR_R "Red Gain" 1.0 0.0 2.0 0.05
#pragma parameter CLR_G "Green Gain" 1.0 0.0 2.0 0.05
#pragma parameter CLR_B "Blue Gain" 1.0 0.0 2.0 0.05
#pragma parameter BLOOM_INT "Bloom Intensity" 0.0 0.0 2.0 0.05
#pragma parameter BLOOM_TH "Bloom Threshold" 0.88 0.0 1.0 0.01

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

uniform float CLU_LUT_Size, CLU_LUT_SEL, CLU_LUT_OPACITY;
uniform float CLR_SAT, CLR_CONT, CLR_BRIGHT, CLU_BLK_D, CLR_GAMMA, CLR_R, CLR_G, CLR_B, BLOOM_INT, BLOOM_TH;

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

    // 1. RGB Gain
    col *= vec3(CLR_R, CLR_G, CLR_B);

    // 2. LUT Engine (Bypassable - Zero cost if CLU_LUT_SEL is 0)
    if (CLU_LUT_SEL > 0.5 && CLU_LUT_OPACITY > 0.0) {
        vec3 l_res = apply_3d_lut(SamplerLUT1, clamp(col, 0.0, 1.0), CLU_LUT_Size);
        col = mix(col, l_res, CLU_LUT_OPACITY);
    }

    // 3. CRT Black Depth
    float luma_base = dot(col, lum_coeff);
    col *= (1.0 - CLU_BLK_D * (1.0 - luma_base));

    // 4. Contrast & Brightness
    col = (col - 0.5) * CLR_CONT + 0.5;
    col += CLR_BRIGHT;

    // 5. Zero-Cost Bloom
    float luma_bloom = dot(col, lum_coeff);
    float bloom_mask = max(0.0, luma_bloom - BLOOM_TH);
    col += col * bloom_mask * BLOOM_INT;

    // 6. Saturation
    float luma_sat = dot(col, lum_coeff);
    col = mix(vec3(luma_sat), col, CLR_SAT);

    // 7. Gamma Correction
    col = pow(col, vec3(CLR_GAMMA));

    // 8. Output
    gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
#endif