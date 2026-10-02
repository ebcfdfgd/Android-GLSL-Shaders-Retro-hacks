#version 110

/* ULTIMATE-TURBO-HYBRID (V19-QUILEZ-FLAT-EDITION)
    - INTEGRATED: Quilez Scaling (Organic Pixel Reconstruction).
    - OPTIMIZED: 100% Branchless (No 'if' conditions).
    - SCANLINES: Lottes Scanline model (Flat Projection).
*/

// --- 1. Parameters ---
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 2.5 0.05
#pragma parameter MASK_STR "Mask Intensity" 0.45 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width" 6.0 1.0 64.0 1.0
#pragma parameter MASK_H "Mask Height" 2.0 1.0 64.0 1.0
#pragma parameter hardScan "Lottes Scan Hardness" -8.0 -20.0 0.0 1.0
#pragma parameter SCAN_STR "Scanline Intensity" 0.40 0.0 1.0 0.05

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
precision mediump float;
#endif

varying vec2 TEX0;
uniform sampler2D Texture, SamplerMask1;
uniform vec2 TextureSize;
uniform float BRIGHT_BOOST, MASK_STR, MASK_W, MASK_H, hardScan, SCAN_STR;

void main() {
    // 1. Quilez Scaling (التكبير العضوي فائق النقاء للمنظور المسطح)
    vec2 q_p = TEX0 * TextureSize;
    vec2 q_i = floor(q_p) + 0.5;
    vec2 q_f = q_p - q_i;
    vec2 q_final = (q_i + 4.0 * q_f * q_f * q_f) / TextureSize;
    
    vec3 res = texture2D(Texture, q_final).rgb;

    // 2. Lottes Scanlines
    float dst = fract(TEX0.y * TextureSize.y) - 0.5;
    float scanline = exp2(hardScan * dst * dst);
    res = mix(res, res * scanline, SCAN_STR);

    // 3. Sharp PNG Mask System
    vec2 mask_size = vec2(floor(MASK_W), floor(MASK_H));
    vec2 m_uv = (mod(floor(gl_FragCoord.xy), mask_size) + 0.5) / mask_size;
    vec3 mcol = texture2D(SamplerMask1, m_uv).rgb * 1.5;
    res = mix(res, res * mcol, MASK_STR);

    // 4. Final Output
    gl_FragColor = vec4(clamp(res * BRIGHT_BOOST, 0.0, 1.0), 1.0);
}
#endif