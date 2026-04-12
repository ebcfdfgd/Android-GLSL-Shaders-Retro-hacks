#version 110

/* ULTIMATE-TURBO-HYBRID (Zero-Load Version)
    - PERFORMANCE: All Heavy math (Curve, Scanlines, Mask) is strictly conditional.
    - TOSHIBA-CURVE: Fast cylindrical distortion with straight edge fix.
    - OPTIMIZED: Zero parameter = Zero GPU usage for that effect.
*/

// --- 1. Coordinates & Curve ---
#pragma parameter BARREL_DISTORTION "Toshiba Curve (0=OFF)" 0.12 0.0 0.5 0.01
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 2.5 0.05
#pragma parameter v_amount "Vignette Intensity (0=OFF)" 0.25 0.0 2.5 0.01

// --- 2. Mask System (Smart) ---
#pragma parameter MASK_TYPE "Mask: 0:RGB, 1:PNG" 0.0 0.0 1.0 1.0
#pragma parameter MASK_STR "Mask Intensity (0=OFF)" 0.45 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width" 3.0 1.0 15.0 1.0
#pragma parameter MASK_H "Mask Height" 3.0 1.0 15.0 1.0

// --- 3. Scanlines (Smart) ---
#pragma parameter SCAN_STR "Scanline Intensity (0=OFF)" 0.40 0.0 1.0 0.05
#pragma parameter SCAN_DENS "Scanline Density" 1.0 0.2 10.0 0.1

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
uniform vec2 TextureSize, InputSize, OutputSize;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, BRIGHT_BOOST, v_amount;
uniform float MASK_TYPE, MASK_STR, MASK_W, MASK_H;
uniform float SCAN_STR, SCAN_DENS;
#endif

void main() {
    vec2 sc = TextureSize / InputSize;
    vec2 uv = (TEX0.xy * sc) - 0.5;
    vec2 d_uv;

    // [A] Geometry Bypass (Skip heavy math if distortion is 0)
    if (BARREL_DISTORTION > 0.0) {
        float kx = BARREL_DISTORTION * 0.2; 
        float ky = BARREL_DISTORTION * 0.9; 
        d_uv.x = uv.x * (1.0 + (uv.y * uv.y) * kx);
        d_uv.y = uv.y * (1.0 + (uv.x * uv.x) * ky);
        d_uv *= (1.0 - 0.15 * BARREL_DISTORTION);
    } else {
        d_uv = uv;
    }

    // [B] Early Exit (Edge Clipping)
    if (abs(d_uv.x) > 0.5 || abs(d_uv.y) > 0.5) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // [C] Texture Sampling
    vec3 res = texture2D(Texture, (d_uv + 0.5) / sc).rgb;
    res *= BRIGHT_BOOST;

    // [D] Smart Scanlines Bypass
    if (SCAN_STR > 0.0) {
        float scanline = sin((gl_FragCoord.y / max(SCAN_DENS, 0.1)) * 3.14159) * 0.5 + 0.5;
        res = mix(res, res * scanline, SCAN_STR);
    }

    // [E] Smart Mask System Bypass
    if (MASK_STR > 0.0) {
        vec3 mcol = vec3(1.0);
        float mw = floor(max(MASK_W, 1.0));
        float mh = floor(max(MASK_H, 1.0));

        if (MASK_TYPE < 0.5) { 
            float pos = mod(gl_FragCoord.x, mw);
            if (mw <= 3.5) {
                mcol = (pos < 1.0) ? vec3(1.4, 0.6, 0.6) : (pos < 2.0) ? vec3(0.6, 1.4, 0.6) : vec3(0.6, 0.6, 1.4);
            } else {
                float ratio = pos / mw;
                mcol = vec3(clamp(abs(ratio * 6.0 - 3.0) - 1.0, 0.0, 1.0),
                            clamp(2.0 - abs(ratio * 6.0 - 2.0), 0.0, 1.0),
                            clamp(2.0 - abs(ratio * 6.0 - 4.0), 0.0, 1.0)) * 1.6;
            }
        } else {
            vec2 m_uv = gl_FragCoord.xy / vec2(mw, mh);
            mcol = texture2D(SamplerMask1, m_uv).rgb * 1.5;
        }
        res = mix(res, res * mcol, MASK_STR);
    }

    // [F] Soft Vignette Bypass
    if (v_amount > 0.0) {
        float vig_val = dot(d_uv, d_uv);
        res *= clamp(1.0 - (vig_val * v_amount), 0.0, 1.0);
    }

    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif