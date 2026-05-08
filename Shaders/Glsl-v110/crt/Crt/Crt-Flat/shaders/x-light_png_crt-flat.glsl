#version 110

/* ULTIMATE-TURBO-HYBRID-ZOOM-SCAN
    - MERGED: Sine-wave Scanlines with Zoom (SCAN_SIZE).
    - RETAINED: Lottes Mask with Texture Sampling (SamplerMask1).
    - ADDED: Manual Scanline Scale control.
*/

#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 2.5 0.05
#pragma parameter MASK_W "Mask Width" 3.0 1.0 15.0 1.0
#pragma parameter MASK_H "Mask Height" 3.0 1.0 15.0 1.0
#pragma parameter SCAN_STR "Scanline Intensity (0=OFF)" 0.40 0.0 1.0 0.05
#pragma parameter SCAN_SIZE "Scanline Size (Zoom)" 5.0 1.0 10.0 0.5
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
uniform float BRIGHT_BOOST, MASK_W, MASK_H, SCAN_STR, SCAN_SIZE, maskDark, maskLight;
#endif

void main() {
    // 1. Direct Hardware Sampling
    vec3 res = texture2D(Texture, TEX0).rgb;
    
    // 2. ZOOMABLE SINE SCANLINES (تم استبدال الـ Lottes بهذا النظام)
    // نستخدم gl_FragCoord للتحكم في الخطوط يدوياً عبر SCAN_SIZE
    float scanline = sin(gl_FragCoord.y * (6.28318 / SCAN_SIZE)) * 0.5 + 0.5;
    res = mix(res, res * scanline, SCAN_STR);

    // 3. Texture Mask Logic
    float mw = floor(max(MASK_W, 1.0));
    float mh = floor(max(MASK_H, 1.0));
    
    // سحب النمط من ملف الماسك الخارجي
    vec3 mcol = texture2D(SamplerMask1, gl_FragCoord.xy / vec2(mw, mh)).rgb;
    
    // دمج السطوع الداكن والفاتح للـ Mask بناءً على النمط المسحوب
    vec3 finalMask = mix(vec3(maskDark), vec3(maskLight), mcol);
    res *= finalMask;

    // 4. Final Polish
    res *= BRIGHT_BOOST;
    
    gl_FragColor = vec4(res, 1.0);
}
#endif