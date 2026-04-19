#version 110

/* 777-COLOR-BLOOM-MASTER (FIXED: Brightness & Defaults)
    - FIXED: Default Gamma set to 1.0 (Neutral).
    - FIXED: Black Depth defaulted to 0.0 (Off).
    - OPTIMIZED: Branchless pipeline.
*/

#pragma parameter CLR_SAT "Saturation" 1.0 0.0 2.0 0.05
#pragma parameter CLR_CONT "Contrast" 1.0 0.0 2.0 0.05
#pragma parameter CLR_BRIGHT "Brightness" 0.0 -0.5 0.5 0.05
#pragma parameter CLU_BLK_D "CRT Black Depth" 0.0 0.0 1.0 0.05
#pragma parameter CLR_GAMMA "Gamma Correction" 1.0 0.1 3.0 0.1
#pragma parameter CLR_R "Red Gain" 1.0 0.0 2.0 0.05
#pragma parameter CLR_G "Green Gain" 1.0 0.0 2.0 0.05
#pragma parameter CLR_B "Blue Gain" 1.0 0.0 2.0 0.05
#pragma parameter BLOOM_INT "Bloom Intensity" 0.0 0.0 2.0 0.05
#pragma parameter BLOOM_TH "Bloom Threshold" 0.8 0.0 1.0 0.05

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
#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D Texture;
varying vec2 uv;

uniform float CLR_SAT, CLR_CONT, CLR_BRIGHT, CLU_BLK_D, CLR_GAMMA, CLR_R, CLR_G, CLR_B, BLOOM_INT, BLOOM_TH;

void main() {
    // 1. Fetch
    vec3 col = texture2D(Texture, uv).rgb;
    vec3 lum_coeff = vec3(0.299, 0.587, 0.114);

    // 2. RGB Gain
    col *= vec3(CLR_R, CLR_G, CLR_B);

    // 3. CRT Black Depth (تم ضبط الافتراضي على 0.0 لعدم تعتيم الصورة)
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

    // 7. Gamma Correction (تم ضبط الافتراضي على 1.0)
    col = pow(col, vec3(CLR_GAMMA));

    // 8. Output
    gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
#endif