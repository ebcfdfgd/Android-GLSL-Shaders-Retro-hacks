#version 110

/* ULTIMATE-TURBO-HYBRID (1012 Hardness Edition)
    - INTEGRATED: 1012 (Lottes) Gaussian Scanlines.
    - REPLACED: Legacy Sine Scanlines.
    - FEATURE: Toshiba Cylindrical Curve (Correctly mapped to Scanlines).
    - OPTIMIZED: Smart Branching for Mask & Scanline logic.
*/

// --- 1. Coordinates & Curve ---
#pragma parameter BARREL_DISTORTION "Toshiba Curve Strength" 0.12 0.0 0.5 0.01
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 2.5 0.05
#pragma parameter v_amount "Vignette Intensity" 0.25 0.0 2.5 0.01

// --- 2. Mask System (Smart) ---
#pragma parameter MASK_TYPE "Mask: 0:RGB, 1:PNG" 0.0 0.0 1.0 1.0
#pragma parameter MASK_STR "Mask Intensity" 0.45 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width" 3.0 1.0 15.0 1.0
#pragma parameter MASK_H "Mask Height" 3.0 1.0 15.0 1.0

// --- 3. 1012 Scanline Hardness ---
#pragma parameter hardScan "Scanline Hardness" -8.0 -20.0 0.0 1.0
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
precision highp float;
#endif

varying vec2 TEX0;
uniform sampler2D Texture, SamplerMask1;
uniform vec2 TextureSize, InputSize;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, BRIGHT_BOOST, v_amount;
uniform float MASK_TYPE, MASK_STR, MASK_W, MASK_H;
uniform float hardScan, SCAN_STR;
#endif

void main() {
    // [A] Coordinates Calculation
    vec2 sc = TextureSize / InputSize;
    vec2 uv = (TEX0.xy * sc) - 0.5;

    // Toshiba Cylindrical Curve
    float kx = BARREL_DISTORTION * 0.2; 
    float ky = BARREL_DISTORTION * 0.9; 
    vec2 d_uv;
    d_uv.x = uv.x * (1.0 + (uv.y * uv.y) * kx);
    d_uv.y = uv.y * (1.0 + (uv.x * uv.x) * ky);
    d_uv *= (1.0 - 0.15 * BARREL_DISTORTION);

    // Early Exit
    if (abs(d_uv.x) > 0.5 || abs(d_uv.y) > 0.5) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // [B] Texture Fetch
    vec2 final_uv = (d_uv + 0.5) / sc;
    vec3 res = texture2D(Texture, final_uv).rgb;

    // [C] 1012 Scanline Integration (Gaussian)
    if (SCAN_STR > 0.01) {
        // نستخدم final_uv.y بدلاً من gl_FragCoord لكي تنحني الخطوط مع الصورة
        float pos_y = final_uv.y * TextureSize.y;
        float dst = fract(pos_y) - 0.5;
        float scan = exp2(hardScan * dst * dst);
        res *= mix(1.0, scan, SCAN_STR);
    }

    // [D] Smart Mask System
    if (MASK_STR > 0.01) {
        vec3 mcol = vec3(1.0);
        float mw = floor(max(MASK_W, 1.0));
        float mh = floor(max(MASK_H, 1.0));

        if (MASK_TYPE < 0.5) { // Internal RGB Mask
            float pos = mod(gl_FragCoord.x, mw);
            if (mw <= 3.5) {
                mcol = (pos < 1.0) ? vec3(1.4, 0.6, 0.6) : (pos < 2.0) ? vec3(0.6, 1.4, 0.6) : vec3(0.6, 0.6, 1.4);
            } else {
                float r = pos / mw;
                mcol = vec3(clamp(abs(r * 6.0 - 3.0) - 1.0, 0.0, 1.0),
                            clamp(2.0 - abs(r * 6.0 - 2.0), 0.0, 1.0),
                            clamp(2.0 - abs(r * 6.0 - 4.0), 0.0, 1.0)) * 1.6;
            }
        } else { // PNG Texture Mask
            mcol = texture2D(SamplerMask1, gl_FragCoord.xy / vec2(mw, mh)).rgb * 1.5;
        }
        res = mix(res, res * mcol, MASK_STR);
    }

    // [E] Final Polish
    res *= BRIGHT_BOOST;
    res *= clamp(1.0 - (dot(d_uv, d_uv) * v_amount), 0.0, 1.0);

    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif