/* 777-LITE-TURBO-FLAT-LOTTES-SCAN
    - REMOVED: Barrel Distortion, Vignette, Bloom (Pure Flat Performance).
    - FIXED: Scanlines lock perfectly to game pixels (Anti-Moire).
    - ADDED: Lottes Mask Dark/Light controls (Force Enabled).
    - OPTIMIZED: Zero-latency code for low-end devices.
*/

#version 110

#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.20 1.0 2.0 0.01
#pragma parameter SCAN_STR "Scanline Intensity" 0.40 0.0 1.0 0.05
#pragma parameter hardScan "Lottes Scan Hardness" -8.0 -20.0 0.0 1.0
#pragma parameter MASK_W "Mask Width (3=RGB)" 3.0 1.0 10.0 1.0
#pragma parameter maskDark "Mask Dark" 0.5 0.0 2.0 0.05
#pragma parameter maskLight "Mask Light" 1.5 0.0 2.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
uniform mat4 MVPMatrix;

void main() {
    uv = TexCoord;
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize;

#ifdef PARAMETER_UNIFORM
uniform float BRIGHT_BOOST, SCAN_STR, hardScan, MASK_W, maskDark, maskLight;
#endif

void main() {
    // 1. Direct Sampling (Exact Pixel Mapping)
    vec3 res = texture2D(Texture, uv).rgb;

    // 2. STABILIZED LOTTES SCANLINES
    // ربط الحساب بإحداثيات بكسلات اللعبة مباشرة لمنع الاهتزاز والتموج
    float pos_y = uv.y * TextureSize.y;
    float dst = fract(pos_y) - 0.5;
    float scanline = exp2(hardScan * dst * dst);
    
    // دمج السكان لاين بنسبة الشدة المحددة
    res = mix(res, res * scanline, SCAN_STR);

    // 3. PIXEL-PERFECT RGB MASK
    float W = floor(MASK_W);
    // استخدام gl_FragCoord يضمن ثبات الماسك فوق بكسلات الشاشة الفيزيائية
    float pos = mod(gl_FragCoord.x, W) / W;
    
    // حساب نمط توزيع RGB الكلاسيكي
    vec3 m_pattern = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), 0.0, 1.0);
    
    // التحكم المستقل في السطوع (الظلال والإضاءة)
    vec3 mcol = mix(vec4(maskDark).rgb, vec4(maskLight).rgb, m_pattern);
    
    // تطبيق الماسك النهائي
    res *= mcol;

    // 4. Final Polish
    res *= BRIGHT_BOOST;

    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif