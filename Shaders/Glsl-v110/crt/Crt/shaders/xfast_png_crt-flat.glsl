#version 110

/* ULTIMATE-TURBO-HYBRID (V20-SCANLINE-FADE-FIXED)
    - SPEED: 100% Branchless design. No 'if' conditions.
    - SCANLINES: Zfast Pixel-Sync with Smart Fade Cutoff (disappears on bright whites).
    - MASK: Exact manual PNG texture dimension input (e.g., 6x2) with sharp subpixel offset.
    - OPTIMIZED: High-performance linear math (step, mix, clamp, smoothstep).
*/

// --- 1. Coordinates & Curve ---

#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.25 0.5 2.0 0.05

// --- 2. PNG Mask System ---
#pragma parameter MASK_STR "Mask Intensity (0=OFF)" 0.45 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width (Texture Pixels)" 6.0 1.0 64.0 1.0
#pragma parameter MASK_H "Mask Height (Texture Pixels)" 2.0 1.0 64.0 1.0

// --- 3. Scanlines & Fade ---
#pragma parameter LOWLUMSCAN "Scanline Darkness - Low" 4.5 0.0 15.0 0.5
#pragma parameter SCAN_FADE_POINT "Scanline Fade Cutoff" 0.85 0.5 1.0 0.05

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
uniform float  BRIGHT_BOOST; 
uniform float MASK_STR, MASK_W, MASK_H;
uniform float LOWLUMSCAN, SCAN_FADE_POINT;
#endif

void main() {
    vec2 sc = TextureSize / InputSize;
    vec2 uv = (TEX0.xy * sc) - 0.5;
    vec2 p2 = uv * uv;

    // [A] إحداثيات مسطحة مباشرة نسيجية
    vec2 final_uv = TEX0;

    // [B] فحص الحدود لمنع ظهور الشاشة السوداء
    vec2 bounds = step(abs(uv), vec2(0.5));
    float edge_mask = bounds.x * bounds.y;

    // [C] سحب اللون المسطح النقي
    vec3 res = texture2D(Texture, final_uv).rgb;

    // [D] Zfast Pixel-Sync Scanlines with Dynamic Fade Cutoff
    float pos_y = final_uv.y * TextureSize.y;
    float f_y = fract(pos_y); 
    float dist = f_y - 0.5;
    float Y = dist * dist;
    float YY = Y * Y;

    // معادلة حساب أوزان السطوع المدمجة
    float scanWeightL = (BRIGHT_BOOST - LOWLUMSCAN * (Y - 1.5 * YY));

    // حساب الإضاءة والدمج الذكي لاختفاء الخطوط عند البياض الشديد
    float luma = dot(res, vec3(0.299, 0.587, 0.114));
    float final_scan = mix(scanWeightL, 1.0, smoothstep(0.1, SCAN_FADE_POINT, luma));
    res *= final_scan;

    // [E] Sharp PNG-Only Mask System (معايرة الإبعاد المالي الدقيق بدون تداخل)
    vec2 mask_size = vec2(floor(MASK_W), floor(MASK_H));
    vec2 pixel_coord = floor(gl_FragCoord.xy);
    vec2 repeated_coord = mod(pixel_coord, mask_size);
    vec2 m_uv = (repeated_coord + 0.5) / mask_size;
    
    vec3 mcol = texture2D(SamplerMask1, m_uv).rgb * 1.5;
    res = mix(res, res * mcol, MASK_STR);

    

    // [G] FINAL STAGE
    gl_FragColor = vec4(res * BRIGHT_BOOST * edge_mask, 1.0);
}
#endif