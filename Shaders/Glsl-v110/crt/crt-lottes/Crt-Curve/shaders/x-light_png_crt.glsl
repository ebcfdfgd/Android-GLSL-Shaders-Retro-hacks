#version 110

/* ULTIMATE-TURBO-HYBRID (V19-EXACT-PIXEL-FIXED)
    - SPEED: 100% Branchless design. No 'if' conditions.
    - FIX: Added strict subpixel centering offset to prevent texture distortion.
    - MASK: Sharp PNG pixel dimensions manual input (e.g., 6x2) via parameters.
    - SCANLINES: Integrated ultra-fast Lottes Scanlines (exp2 method).
*/

// --- 1. Coordinates & Curve ---
#pragma parameter BARREL_DISTORTION "Toshiba Curve (0=OFF)" 0.12 0.0 0.5 0.01
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 2.5 0.05
#pragma parameter v_amount "Vignette Intensity (0=OFF)" 0.35 0.0 2.5 0.01

// --- 2. PNG Mask System ---
#pragma parameter MASK_STR "Mask Intensity (0=OFF)" 0.45 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width (Texture Pixels)" 6.0 1.0 64.0 1.0
#pragma parameter MASK_H "Mask Height (Texture Pixels)" 2.0 1.0 64.0 1.0

// --- 3. Lottes Scanlines ---
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
precision lowp float;
#endif

varying vec2 TEX0;
uniform sampler2D Texture, SamplerMask1;
uniform vec2 TextureSize, InputSize;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, BRIGHT_BOOST, v_amount;
uniform float MASK_STR, MASK_W, MASK_H;
uniform float hardScan, SCAN_STR;
#endif

void main() {
    vec2 sc = TextureSize / InputSize;
    vec2 uv = (TEX0.xy * sc) - 0.5;
    vec2 p2 = uv * uv;

    // [A] Hyper-Fast Branchless Geometry
    vec2 d_uv = uv * (1.0 + vec2(p2.y * (BARREL_DISTORTION * 0.2), p2.x * (BARREL_DISTORTION * 0.9)));
    d_uv *= (1.0 - 0.15 * BARREL_DISTORTION);

    // [B] Branchless Early Exit Replacement
    vec2 bounds = step(abs(d_uv), vec2(0.5));
    float edge_mask = bounds.x * bounds.y;

    // [C] Fast Texture Sampling
    vec2 final_uv = (d_uv + 0.5) / sc;
    vec3 res = texture2D(Texture, final_uv).rgb;

    // [D] LOTTES SCANLINES
    float dst = fract(final_uv.y * TextureSize.y) - 0.5;
    float scanline = exp2(hardScan * dst * dst);
    res = mix(res, res * scanline, SCAN_STR);

    // [E] Sharp PNG-Only Mask System (معادلة المعايرة وتوسيط البكسل الصافية)
    vec2 mask_size = vec2(floor(MASK_W), floor(MASK_H));
    
    // 1. حساب البكسل الحالي على الشاشة بدون تنعيم
    vec2 pixel_coord = floor(gl_FragCoord.xy);
    
    // 2. استخدام mod لتكرار الإحداثيات داخل حدود حجم الماسك
    vec2 repeated_coord = mod(pixel_coord, mask_size);
    
    // 3. إضافة الـ 0.5 (Subpixel Offset) لضمان القراءة من منتصف البكسل تماماً ومنع التداخل
    vec2 m_uv = (repeated_coord + 0.5) / mask_size;
    
    vec3 mcol = texture2D(SamplerMask1, m_uv).rgb * 1.5;
    res = mix(res, res * mcol, MASK_STR);

    // [F] Smooth Vignette
    float vig_val = p2.x * p2.y * 15.0; 
    res *= (1.0 - clamp(vig_val * v_amount, 0.0, 1.0));

    // [G] FINAL STAGE
    gl_FragColor = vec4(res * BRIGHT_BOOST * edge_mask, 1.0);
}
#endif