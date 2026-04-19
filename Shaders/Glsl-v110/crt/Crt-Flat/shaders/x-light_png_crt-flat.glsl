#version 110

/* ULTIMATE-TURBO-HYBRID-FLAT-FIXED
    - FIXED: Scanlines are now thinner and sharper (Giant line fix).
    - FLAT: No distortion or vignette.
    - BRANCHLESS: Optimized math for maximum mobile performance.
*/

#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 2.5 0.05
#pragma parameter MASK_TYPE "Mask: 0:RGB, 1:PNG" 0.0 0.0 1.0 1.0
#pragma parameter MASK_STR "Mask Intensity (0=OFF)" 0.45 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width" 3.0 1.0 15.0 1.0
#pragma parameter MASK_H "Mask Height" 3.0 1.0 15.0 1.0
#pragma parameter SCAN_STR "Scanline Intensity (0=OFF)" 0.40 0.0 1.0 0.05
#pragma parameter SCAN_DENS "Scanline Density" 2.0 0.5 5.0 0.1

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
uniform vec2 InputSize;

#ifdef PARAMETER_UNIFORM
uniform float BRIGHT_BOOST, MASK_TYPE, MASK_STR, MASK_W, MASK_H, SCAN_STR, SCAN_DENS;
#endif

void main() {
    // 1. Direct Hardware Sampling
    vec3 res = texture2D(Texture, TEX0).rgb;
    
    // 2. FIXED SCANLINES (الآن أنحف وأكثر دقة)
    // قمت بزيادة كثافة التردد (SCAN_DENS * 2.0) لضمان أن الخطوط لن تبدو عملاقة
    float scan_pos = TEX0.y * InputSize.y;
    float scanline = sin(scan_pos * 6.28318 * (SCAN_DENS * 2.0)) * 0.5 + 0.5;
    res = mix(res, res * scanline, SCAN_STR);

    // 3. Universal Mask Logic (Branchless)
    float mw = floor(max(MASK_W, 1.0));
    float mh = floor(max(MASK_H, 1.0));
    float pos = mod(gl_FragCoord.x, mw);
    
    // RGB Mask logic using mix/step
    vec3 m_thin = mix(vec3(1.4, 0.6, 0.6), vec3(0.6, 1.4, 0.6), step(1.0, pos));
    m_thin = mix(m_thin, vec3(0.6, 0.6, 1.4), step(2.0, pos));
    
    float ratio = pos / mw;
    vec3 m_wide = vec3(clamp(abs(ratio * 6.0 - 3.0) - 1.0, 0.0, 1.0),
                       clamp(2.0 - abs(ratio * 6.0 - 2.0), 0.0, 1.0),
                       clamp(2.0 - abs(ratio * 6.0 - 4.0), 0.0, 1.0)) * 1.6;
    
    vec3 mcol_rgb = mix(m_wide, m_thin, step(mw, 3.5));
    vec3 mcol_png = texture2D(SamplerMask1, gl_FragCoord.xy / vec2(mw, mh)).rgb * 1.5;
    
    vec3 mcol = mix(mcol_rgb, mcol_png, step(0.5, MASK_TYPE));
    res = mix(res, res * mcol, MASK_STR);

    // 4. Final Polish
    res *= BRIGHT_BOOST;
    
    gl_FragColor = vec4(res, 1.0);
}
#endif