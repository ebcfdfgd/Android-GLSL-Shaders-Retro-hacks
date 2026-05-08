#version 110

/* 777-LITE-TURBO-HYBRID-ZOOM-SCAN
    - MERGED: Sine-wave Scanlines with Zoom (SCAN_SIZE).
    - RETAINED: Lottes Mask Dark/Light controls.
    - OPTIMIZED: Clean layout for 1080p.
*/

#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.20 1.0 2.0 0.01
#pragma parameter SCAN_STR "Scanline Intensity" 0.40 0.0 1.0 0.05
#pragma parameter SCAN_SIZE "Scanline Size (Zoom)" 5.0 1.0 10.0 0.5
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
uniform float BRIGHT_BOOST, SCAN_STR, SCAN_SIZE, MASK_W, maskDark, maskLight;
#endif

void main() {
    // 1. Direct Sampling
    vec3 res = texture2D(Texture, uv).rgb;

    // 2. SINE-WAVE SCANLINES (التي تحتوي على قيمة الزوم)
    // نستخدم gl_FragCoord مع SCAN_SIZE للتحكم في حجم الخط يدوياً
    float scanline = sin(gl_FragCoord.y * (6.28318 / SCAN_SIZE)) * 0.5 + 0.5;
    res = mix(res, res * scanline, SCAN_STR);

    // 3. LOTTES MASK LOGIC (Dark/Light Control)
    float W = floor(MASK_W);
    float pos = mod(gl_FragCoord.x, W) / W;
    
    // حساب نمط توزيع RGB
    vec3 m_pattern = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), 0.0, 1.0);
    
    // تطبيق الـ Dark والـ Light بناءً على النمط
    vec3 mcol = mix(vec3(maskDark), vec3(maskLight), m_pattern);
    
    // دمج الماسك مع الصورة
    res *= mcol;

    // 4. Final Polish & Brightness
    res *= BRIGHT_BOOST;

    gl_FragColor = vec4(res, 1.0);
}
#endif