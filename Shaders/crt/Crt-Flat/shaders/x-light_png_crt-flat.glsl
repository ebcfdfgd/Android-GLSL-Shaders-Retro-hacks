#version 110

/* ULTIMATE-TURBO-HYBRID-FLAT-LOTTES-SCAN
    - FIXED: Scanlines locked perfectly to game pixels (Lottes Method).
    - FLAT: No distortion or vignette.
    - BRANCHLESS: Optimized math.
    - ADDED: Lottes Dark/Light Mask controls (Force Enabled).
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
uniform vec2 TextureSize; 

#ifdef PARAMETER_UNIFORM
uniform float BRIGHT_BOOST, MASK_W, MASK_H, SCAN_STR, hardScan, maskDark, maskLight;
#endif

void main() {
    // 1. Direct Hardware Sampling
    vec3 res = texture2D(Texture, TEX0).rgb;
    
    // 2. LOTTES SCANLINES (Locked to TextureSize.y)
    float dst = fract(TEX0.y * TextureSize.y) - 0.5;
    float scanline = exp2(hardScan * dst * dst);
    res = mix(res, res * scanline, SCAN_STR);

    // 3. Texture Mask Logic (Force Enabled)
    float mw = floor(max(MASK_W, 1.0));
    float mh = floor(max(MASK_H, 1.0));
    vec3 mcol = texture2D(SamplerMask1, gl_FragCoord.xy / vec2(mw, mh)).rgb;
    
    // دمج السطوع الداكن والفاتح للـ Mask
    vec3 finalMask = mix(vec3(maskDark), vec3(maskLight), mcol);
    res *= finalMask; // الماسك مفعّل دائماً بقوة كاملة

    // 4. Final Polish
    res *= BRIGHT_BOOST;
    
    gl_FragColor = vec4(res, 1.0);
}
#endif