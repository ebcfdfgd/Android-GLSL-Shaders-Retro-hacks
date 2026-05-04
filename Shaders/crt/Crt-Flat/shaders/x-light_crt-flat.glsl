/* 777-LITE-TURBO-FLAT-LOTTES-SCAN
    - REMOVED: Barrel Distortion, Vignette, Bloom.
    - FIXED: Scanlines lock perfectly to game pixels.
    - ADDED: Lottes Mask Dark/Light controls (Force Enabled).
*/

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
    // 1. Direct Sampling
    vec3 res = texture2D(Texture, uv).rgb;

    // 2. LOTTES SCANLINES (Exponential Falloff)
    float dst = fract(uv.y * TextureSize.y) - 0.5;
    float scanline = exp2(hardScan * dst * dst);
    res = mix(res, res * scanline, SCAN_STR);

    // 3. Optimized RGB Mask with Dark/Light Control (Force Enabled)
    float W = floor(MASK_W);
    float pos = mod(gl_FragCoord.x, W) / W;
    
    // حساب توزيع الألوان للماسك
    vec3 m_pattern = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), 0.0, 1.0);
    // دمج السطوع الداكن والفاتح بناءً على النمط
    vec3 mcol = mix(vec3(maskDark), vec3(maskLight), m_pattern);
    
    // تطبيق الماسك بقوة كاملة
    res *= mcol;

    // 4. Final Polish
    res *= BRIGHT_BOOST;

    gl_FragColor = vec4(res, 1.0);
}
#endif