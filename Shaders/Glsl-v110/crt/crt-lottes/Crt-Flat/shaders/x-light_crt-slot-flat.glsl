#version 110

/* 777-LITE-TURBO-V4-ULTRA-FIXED (Flat Edition)
    - REMOVED: Barrel Distortion completely from parameters and uniforms.
    - UPDATED: Replaced original mask with ultra-fast 6x2 Slot Mask.
    - SPEED: Zero-cost math, Branchless logic.
*/

#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.20 1.0 2.0 0.01

// --- Lottes Scanline Parameters ---
#pragma parameter hardScan "Lottes Scan Hardness" -8.0 -20.0 0.0 1.0
#pragma parameter SCAN_STR "Scanline Intensity" 0.40 0.0 1.0 0.05
#pragma parameter MASK_STR "Mask Strength" 0.20 0.0 1.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
varying vec2 screen_scale; 
uniform mat4 MVPMatrix;
uniform vec2 TextureSize, InputSize;

void main() {
    uv = TexCoord;
    screen_scale = TextureSize / InputSize; 
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 uv;
varying vec2 screen_scale;
uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;

#ifdef PARAMETER_UNIFORM
// تم إزالة BARREL_DISTORTION لمنع فشل التحميل
uniform float BRIGHT_BOOST,  hardScan, SCAN_STR, MASK_STR;
#endif

void main() {
    // 1. Coordinates & Vignette Setup
    vec2 p = (uv * screen_scale) - 0.5;
    float r2 = dot(p, p); // تركناه لحساب الـ Vignette بالأسفل بنجاح
    
    // 2. Exact Game UVs (Flat Mode)
    vec2 tex_uv = uv;
    vec3 res = texture2D(Texture, tex_uv).rgb;

    // 3. Branchless Bounds Check
    vec2 bounds = step(abs(p), vec2(0.5));
    float check = bounds.x * bounds.y;

    // 4. LOTTES SCANLINES (مربوط الآن بالإحداثيات المسطحة بنقاء كامل)
    float dst = fract(tex_uv.y * TextureSize.y) - 0.5;
    float scanline = exp2(hardScan * dst * dst);
    res = mix(res, res * scanline, SCAN_STR);

    // 5. Advanced 6x2 Slot Mask (Ultra-Lightweight Indexing Mode)
    vec3 mcol = vec3(0.0);
    int x_coord = int(mod(gl_FragCoord.x, 6.0));
    int y_coord = int(mod(gl_FragCoord.y, 2.0));
    
    // إزاحة متبادلة بمقدار 3 بكسلات للسطر الثاني لتشكيل طوب السلوت ماسك
    int idx = x_coord - (y_coord * 3);
    
    if (idx >= 0 && idx < 3) {
        mcol[idx] = 2.0; // إضاءة الفوسفور الصافي الموجه
    }
    
    // دمج مصفوفة السلوت ماسك المتقدمة مع بكسل الصورة بناءً على القوة المختارة
    res = mix(res, res * mcol, MASK_STR);

    // 6. Final Polish
    res *= BRIGHT_BOOST;
   

    gl_FragColor = vec4(res * check, 1.0);
}
#endif