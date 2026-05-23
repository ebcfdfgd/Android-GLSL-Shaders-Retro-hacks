#version 110

/* 777-LITE-TURBO-V4-ULTRA-FIXED (Flat Edition)
    - REMOVED: Barrel Distortion completely from parameters and uniforms.
    - UPDATED: Replaced Mask Strength with Dark/Light Mask logic.
    - FEATURES: Lottes Scanlines, Branchless math.
    - CONTROLS: mask_dark (0.50) and mask_light (1.50) standard.
*/

#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.20 1.0 2.0 0.01


// --- Lottes Scanline Parameters ---
#pragma parameter hardScan "Lottes Scan Hardness" -8.0 -20.0 0.0 1.0
#pragma parameter SCAN_STR "Scanline Intensity" 0.40 0.0 1.0 0.05

// --- New Mask Parameters ---
#pragma parameter mask_dark "Mask Dark Color" 0.80 0.0 2.0 0.05
#pragma parameter mask_light "Mask Light Color" 1.20 0.0 2.0 0.05
#pragma parameter MASK_W "Mask Width (3=RGB)" 3.0 1.0 6.0 1.0

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
uniform float BRIGHT_BOOST,  hardScan, SCAN_STR, mask_dark, mask_light, MASK_W;
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

    // 5. RGB Mask (Dark/Light Logic)
    float W = floor(MASK_W);
    float pos = mod(gl_FragCoord.x, W) / W;
    vec3 mcol = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), mask_dark, mask_light);
    res *= mcol;

    // 6. Final Polish
    res *= BRIGHT_BOOST;
    

    gl_FragColor = vec4(res * check, 1.0);
}
#endif