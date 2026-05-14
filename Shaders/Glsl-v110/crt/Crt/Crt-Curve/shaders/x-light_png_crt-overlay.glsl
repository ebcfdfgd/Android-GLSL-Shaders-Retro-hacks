#version 110

/* ULTIMATE-TURBO-HYBRID (V11-SCAN-FIXED)
    - SCANLINES: Physically locked to curved game pixels (Dynamic).
    - OVERLAY: Corrected Channel-by-Channel logic for GLSL 110.
    - MASK: PNG Texture support optimized.
    - PERFORMANCE: High-speed branching for mobile.
*/

#pragma parameter BARREL_DISTORTION "Toshiba Curve" 0.12 0.0 0.5 0.01
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 2.5 0.05
#pragma parameter v_amount "Vignette Intensity" 0.35 0.0 2.5 0.01

#pragma parameter MASK_STR "Mask Intensity" 0.45 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width" 3.0 1.0 15.0 1.0
#pragma parameter MASK_H "Mask Height" 3.0 1.0 15.0 1.0

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
uniform float MASK_STR, MASK_W, MASK_H;
uniform float SCAN_STR;
#endif

void main() {
    vec2 sc = TextureSize / InputSize;
    vec2 uv = (TEX0.xy * sc) - 0.5;
    vec2 d_uv;

    // [A] Geometry (Curvature)
    vec2 p2 = uv * uv;
    if (BARREL_DISTORTION > 0.0) {
        d_uv = uv * (1.0 + vec2(p2.y * (BARREL_DISTORTION * 0.2), p2.x * (BARREL_DISTORTION * 0.9)));
        d_uv *= (1.0 - 0.15 * BARREL_DISTORTION);
    } else {
        d_uv = uv;
    }

    // [B] Border Check
    if (abs(d_uv.x) > 0.5 || abs(d_uv.y) > 0.5) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // [C] Sampling
    vec3 res = texture2D(Texture, (d_uv + 0.5) / sc).rgb;

    // [D] Pixel-Perfect Scanlines (Locked to Input Resolution)
    if (SCAN_STR > 0.0) {
        // نستخدم d_uv.y المنحنية لضمان أن الخطوط تتبع انحناء الشاشة
        // نضرب في InputSize.y ليكون هناك خط واحد لكل بكسل من بكسلات اللعبة
        float pixel_y = (d_uv.y + 0.5) * InputSize.y;
        
        // استخدام Sine و PI لإنشاء نمط منتظم
        float scan = sin(pixel_y * 6.2831853) * 0.5 + 0.5;
        
        // تطبيق نظام الـ Overlay لكل قناة
        vec3 ovl;
        ovl.r = (res.r < 0.5) ? (2.0 * res.r * scan) : (1.0 - 2.0 * (1.0 - res.r) * (1.0 - scan));
        ovl.g = (res.g < 0.5) ? (2.0 * res.g * scan) : (1.0 - 2.0 * (1.0 - res.g) * (1.0 - scan));
        ovl.b = (res.b < 0.5) ? (2.0 * res.b * scan) : (1.0 - 2.0 * (1.0 - res.b) * (1.0 - scan));
        
        res = mix(res, ovl, SCAN_STR);
    }

    // [E] PNG Mask (Screen Space)
    if (MASK_STR > 0.0) {
        vec2 m_uv = gl_FragCoord.xy / vec2(max(MASK_W, 1.0), max(MASK_H, 1.0));
        vec3 mcol = texture2D(SamplerMask1, m_uv).rgb * 1.5;
        res = mix(res, res * mcol, MASK_STR);
    }

    // [F] Vignette
    if (v_amount > 0.0) {
        float vig_val = p2.x * p2.y * 15.0; 
        res *= (1.0 - clamp(vig_val * v_amount, 0.0, 1.0));
    }

    // [G] Final Brightness
    gl_FragColor = vec4(res * BRIGHT_BOOST, 1.0);
}
#endif