#version 110

/* ULTIMATE-TURBO-HYBRID (V10-PNG-ONLY)
    - CLEANUP: Removed procedural RGB mask logic.
    - MASK: Exclusive high-performance PNG texture support.
    - OPTIMIZED: Retained turbo curve, scanlines, and vignette.
*/

// --- 1. Coordinates & Curve ---
#pragma parameter BARREL_DISTORTION "Toshiba Curve (0=OFF)" 0.12 0.0 0.5 0.01
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 2.5 0.05
#pragma parameter v_amount "Vignette Intensity (0=OFF)" 0.35 0.0 2.5 0.01

// --- 2. PNG Mask System ---
#pragma parameter MASK_STR "Mask Intensity (0=OFF)" 0.45 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width" 3.0 1.0 15.0 1.0
#pragma parameter MASK_H "Mask Height" 3.0 1.0 15.0 1.0

// --- 3. Scanlines ---
#pragma parameter SCAN_STR "Scanline Intensity (0=OFF)" 0.40 0.0 1.0 0.05
#pragma parameter SCAN_DENS "Scanline Size" 5.0 1.0 10.0 0.5

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
precision lowp float;
#endif

varying vec2 TEX0;
uniform sampler2D Texture, SamplerMask1;
uniform vec2 TextureSize, InputSize;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, BRIGHT_BOOST, v_amount;
uniform float MASK_STR, MASK_W, MASK_H;
uniform float SCAN_STR, SCAN_DENS;
#endif

void main() {
    vec2 sc = TextureSize / InputSize;
    vec2 uv = (TEX0.xy * sc) - 0.5;
    vec2 d_uv;

    // [A] Hyper-Fast Geometry 
    vec2 p2 = uv * uv;
    if (BARREL_DISTORTION > 0.0) {
        d_uv = uv * (1.0 + vec2(p2.y * (BARREL_DISTORTION * 0.2), p2.x * (BARREL_DISTORTION * 0.9)));
        d_uv *= (1.0 - 0.15 * BARREL_DISTORTION);
    } else {
        d_uv = uv;
    }

    // [B] Early Exit
    if (abs(d_uv.x) > 0.5 || abs(d_uv.y) > 0.5) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // [C] Texture Sampling
    vec3 res = texture2D(Texture, (d_uv + 0.5) / sc).rgb;

    // [D] Optimized Scanlines
    if (SCAN_STR > 0.0) {
        float scan = abs(fract(gl_FragCoord.y * (1.0 / SCAN_DENS) - 0.5) - 0.5) * 4.0;
        res *= 1.0 - SCAN_STR * (1.0 - clamp(scan, 0.0, 1.0));
    }

    // [E] PNG-Only Mask System
    if (MASK_STR > 0.0) {
        // حساب إحداثيات صورة الـ PNG بناءً على حجم الماسك المختار
        vec2 m_uv = gl_FragCoord.xy / vec2(max(MASK_W, 1.0), max(MASK_H, 1.0));
        vec3 mcol = texture2D(SamplerMask1, m_uv).rgb * 1.5;
        res = mix(res, res * mcol, MASK_STR);
    }

    // [F] Smooth Vignette
    if (v_amount > 0.0) {
        float vig_val = p2.x * p2.y * 15.0; 
        res *= (1.0 - clamp(vig_val * v_amount, 0.0, 1.0));
    }

    // [G] FINAL STAGE: Brightness Boost
    gl_FragColor = vec4(res * BRIGHT_BOOST, 1.0);
}
#endif