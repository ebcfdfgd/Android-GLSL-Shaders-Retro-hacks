#version 110

/* ULTIMATE-TURBO-HYBRID (V19-EXACT-PIXEL-FIXED - Flat Edition)
    - REMOVED: Barrel Distortion completely from parameters and uniforms.
    - SPEED: 100% Branchless design. No 'if' conditions.
    - FIX: Added strict subpixel centering offset to prevent texture distortion.
    - MASK: Sharp PNG pixel dimensions manual input (e.g., 6x2) via parameters.
    - SCANLINES: Integrated ultra-fast Lottes Scanlines (exp2 method).
*/

// --- 1. Coordinates ---
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 2.5 0.05

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
// تم حذف BARREL_DISTORTION من هنا لمنع فشل التحميل
uniform float BRIGHT_BOOST;
uniform float MASK_STR, MASK_W, MASK_H;
uniform float hardScan, SCAN_STR;
#endif

void main() {
    vec2 sc = TextureSize / InputSize;
    vec2 uv = (TEX0.xy * sc) - 0.5;
    vec2 p2 = uv * uv;

    // [A] تم حذف هندسة الكيرف وتثبيت الإحداثيات المسطحة مباشرة للنسيج
    vec2 final_uv = TEX0;

    // [B] فحص الحدود باستخدام إحداثيات uv المسطحة الصافية لمنع الشاشة السوداء
    vec2 bounds = step(abs(uv), vec2(0.5));
    float edge_mask = bounds.x * bounds.y;

    // [C] سحب اللون المسطح النقي
    vec3 res = texture2D(Texture, final_uv).rgb;

    // [D] LOTTES SCANLINES (مربوط الآن بالإحداثيات المسطحة بنقاء كامل)
    float dst = fract(final_uv.y * TextureSize.y) - 0.5;
    float scanline = exp2(hardScan * dst * dst);
    res = mix(res, res * scanline, SCAN_STR);

    // [E] Sharp PNG-Only Mask System
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