#version 110

/* 777-V19-HYBRID-DYNAMIC-PNG-ZOOM-FAST
    - DYNAMIC: Scanlines react to luminance without pow() overhead.
    - MASK: High-performance PNG texture support (SamplerMask1).
    - PERFORMANCE: Optimized Square-Chain for 4K / High Refresh rates.
    - ZOOM: Manual Scanline Scale control (SCAN_SIZE) fixed to screen pixels.
*/

#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.30 1.0 2.5 0.05
#pragma parameter MASK_W "Mask Width" 3.0 1.0 15.0 1.0
#pragma parameter MASK_H "Mask Height" 3.0 1.0 15.0 1.0
#pragma parameter SCAN_STR "Scanline Intensity (0=OFF)" 0.40 0.0 1.0 0.05
#pragma parameter SCAN_SIZE "Scanline Size (Zoom)" 5.0 1.0 10.0 0.5
#pragma parameter SCAN_BEAM "Beam Glow (Light React)" 1.2 0.5 3.0 0.1
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
uniform vec2 TextureSize; 

#ifdef PARAMETER_UNIFORM
uniform float BRIGHT_BOOST, MASK_W, MASK_H, SCAN_STR, SCAN_SIZE, SCAN_BEAM, maskDark, maskLight;
#endif

void main() {
    // 1. Direct Hardware Sampling
    vec3 res = texture2D(Texture, TEX0).rgb;
    
    // 2. FAST DYNAMIC SCANLINES (The "Zaboula" Engine - No Pow)
    if (SCAN_STR > 0.0) {
        // حساب السطوع (Luminance) للتفاعل الديناميكي
        float lum = dot(res, vec3(0.299, 0.587, 0.114));
        
        // حساب الموجة بناءً على بكسلات الشاشة (Sine Wave)
        float angle = gl_FragCoord.y * (6.28318 / SCAN_SIZE);
        float s_wave = sin(angle) * 0.5 + 0.5;
        
        /* 
           بديل الـ pow: نستخدم التربيع المتسلسل (Square-Chain).
           كلما زاد السطوع (lum) أو الشعاع (SCAN_BEAM)، نزيد من حدة الضرب
           لجعل الخطوط "تفتح" وتتوهج في المناطق المضيئة.
        */
        float beam_factor = SCAN_BEAM + (lum * 1.5);
        float dynamic_scan = s_wave * s_wave; // التربيع الأساسي
        
        // محاكاة تأثير الأس عبر الضرب الشرطي السريع لضمان السلاسة
        if(beam_factor > 1.4) dynamic_scan *= s_wave;
        if(beam_factor > 2.0) dynamic_scan *= s_wave;
        if(beam_factor > 2.8) dynamic_scan *= s_wave;
        
        res = mix(res, res * dynamic_scan, SCAN_STR);
    }

    // 3. Texture Mask Logic (Screen-Space)
    float mw = floor(max(MASK_W, 1.0));
    float mh = floor(max(MASK_H, 1.0));
    
    // سحب النمط من ملف الماسك الخارجي PNG
    vec3 mcol_raw = texture2D(SamplerMask1, gl_FragCoord.xy / vec2(mw, mh)).rgb;
    
    // دمج السطوع الداكن والفاتح للـ Mask بشكل متوازن
    vec3 finalMask = mix(vec3(maskDark), vec3(maskLight), mcol_raw);
    res *= finalMask;

    // 4. Final Polish & Brightness Boost
    res *= BRIGHT_BOOST;
    
    gl_FragColor = vec4(res, 1.0);
}
#endif