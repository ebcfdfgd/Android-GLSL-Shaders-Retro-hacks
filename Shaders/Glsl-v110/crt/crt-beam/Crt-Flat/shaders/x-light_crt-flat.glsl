#version 110

/* 777-DYNAMIC-ZOOM-V18-FAST
    - PERFORMANCE: Replaced expensive pow() with fast Square-Chain.
    - DYNAMIC: Scanlines expand/contract based on pixel brightness.
    - MASK: Lottes Mask (RGB) with refined Dark/Light balance.
    - FIX: Constant 60fps/120fps even at 4K resolution.
*/

#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.30 1.0 2.0 0.05
#pragma parameter SCAN_STR "Scanline Intensity" 0.40 0.0 1.0 0.05
#pragma parameter SCAN_SIZE "Scanline Size (Zoom)" 5.0 1.0 10.0 0.5
#pragma parameter SCAN_BEAM "Scanline Glow/Beam" 1.2 0.5 3.0 0.1
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
uniform float BRIGHT_BOOST, SCAN_STR, SCAN_SIZE, SCAN_BEAM, MASK_W, maskDark, maskLight;
#endif

void main() {
    // 1. Direct Sampling
    vec3 res = texture2D(Texture, uv).rgb;

    // 2. FAST DYNAMIC SCANLINES (The "No-Pow" Engine)
    if (SCAN_STR > 0.0) {
        float lum = dot(res, vec3(0.299, 0.587, 0.114));
        
        float angle = gl_FragCoord.y * (6.28318 / SCAN_SIZE);
        float s_wave = sin(angle) * 0.5 + 0.5;
        
        /* 
           بديل الـ pow: نستخدم التربيع المتكرر.
           كلما زاد السطوع (lum)، قللنا تأثير السواد بضرب الموجة في نفسها
           بشكل يتناسب مع الـ SCAN_BEAM المختار.
        */
        float beam_factor = SCAN_BEAM + lum;
        float dynamic_scan = s_wave * s_wave; // تربيع أساسي لتنعيم الموجة
        
        // محاكاة تأثير الأس عبر الضرب الشرطي السريع
        if(beam_factor > 1.5) dynamic_scan *= s_wave; 
        if(beam_factor > 2.2) dynamic_scan *= s_wave;

        res = mix(res, res * dynamic_scan, SCAN_STR);
    }

    // 3. LOTTES MASK LOGIC (Dark/Light Control)
    float W = floor(MASK_W);
    float pos = mod(gl_FragCoord.x, W) / W;
    
    // حساب نمط توزيع RGB (Vectorized for Speed)
    vec3 m_pattern = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), 0.0, 1.0);
    
    // تطبيق الـ Dark والـ Light
    vec3 mcol = mix(vec3(maskDark), vec3(maskLight), m_pattern);
    res *= mcol;

    // 4. Final Polish & Brightness
    res *= BRIGHT_BOOST;

    gl_FragColor = vec4(res, 1.0);
}
#endif