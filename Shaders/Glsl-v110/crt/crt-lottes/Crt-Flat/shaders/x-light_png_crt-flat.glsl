#version 110

/* ULTIMATE-TURBO-HYBRID-FLAT-LOTTES-SCAN
    - FIXED: Scanlines locked perfectly to game pixels (Lottes Method).
    - FLAT: No distortion or vignette (Maximum Performance).
    - BRANCHLESS: Clean math for zero lag.
    - STABILIZED: Screen-space Mask and Pixel-space Scanlines.
*/

#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 2.5 0.05
#pragma parameter MASK_W "Mask Width" 3.0 1.0 15.0 1.0
#pragma parameter MASK_H "Mask Height" 3.0 1.0 15.0 1.0
#pragma parameter SCAN_STR "Scanline Intensity (0=OFF)" 0.40 0.0 1.0 0.05
#pragma parameter hardScan "Lottes Scan Hardness" -8.0 -20.0 0.0 1.0
#pragma parameter maskDark "Mask Dark" 0.5 0.0 2.0 0.05
#pragma parameter maskLight "Mask Light" 1.5 0.0 2.0 0.05

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

varying vec2 TEX0;
uniform sampler2D Texture, SamplerMask1;
uniform vec2 TextureSize, OutputSize; 

#ifdef PARAMETER_UNIFORM
uniform float BRIGHT_BOOST, MASK_W, MASK_H, SCAN_STR, hardScan, maskDark, maskLight;
#endif

void main() {
    // 1. Direct Hardware Sampling
    vec3 res = texture2D(Texture, TEX0).rgb;
    
    // 2. STABILIZED LOTTES SCANLINES
    // ربط الحساب بإحداثيات بكسلات اللعبة الفعلية لمنع التموج (Moire)
    float pos_y = TEX0.y * TextureSize.y;
    float dst = fract(pos_y) - 0.5;
    float scanline = exp2(hardScan * dst * dst);
    
    // دمج السكان لاين
    res = mix(res, res * scanline, SCAN_STR);

    // 3. PIXEL-PERFECT MASK LOGIC
    // استخدام gl_FragCoord يضمن ثبات الماسك فوق بكسلات الشاشة الفيزيائية
    // تقسيم الإحداثيات على حجم الماكروبكسل (W, H) المختار
    vec2 maskCoord = gl_FragCoord.xy / vec2(MASK_W, MASK_H);
    vec3 mcol = texture2D(SamplerMask1, maskCoord).rgb;
    
    // تطبيق التحكم المستقل في المناطق الداكنة والفاتحة للماسك
    // mix(Dark, Light, mcol) يرفع السطوع في الأماكن الملونة ويخفضه في الفجوات
    vec3 finalMask = mix(vec3(maskDark), vec3(maskLight), mcol);
    res *= finalMask;

    // 4. Final Brightness & Output
    res *= BRIGHT_BOOST;
    
    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif