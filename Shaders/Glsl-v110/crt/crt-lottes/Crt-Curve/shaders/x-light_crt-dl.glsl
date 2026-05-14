#version 110

/* 777-LITE-TURBO-V4-ULTRA-FIXED-STABLE
    - FEATURE: Resolution-Independent Lottes Scanlines.
    - FIX: Scanlines stay fixed even if PS1 switches from 240p to 480i.
    - CONTROL: Added SCAN_ZOOM to manually adjust scanline count on any screen.
*/

#pragma parameter BARREL_DISTORTION "Screen Curve" 0.15 0.0 1.0 0.02
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.20 1.0 2.0 0.01
#pragma parameter VIG_STR "Vignette Intensity" 0.15 0.0 2.0 0.05

// --- Lottes Scanline Parameters ---
#pragma parameter hardScan "Lottes Scan Hardness" -8.0 -20.0 0.0 1.0
#pragma parameter SCAN_STR "Scanline Intensity" 0.40 0.0 1.0 0.05
#pragma parameter SCAN_ZOOM "Scanline Zoom (Manual)" 2.0 0.5 10.0 0.1

// --- Mask Parameters ---
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
uniform float BARREL_DISTORTION, BRIGHT_BOOST, VIG_STR, hardScan, SCAN_STR, SCAN_ZOOM, mask_dark, mask_light, MASK_W;
#endif

void main() {
    // 1. Coordinates & Curve
    vec2 p = (uv * screen_scale) - 0.5;
    float r2 = dot(p, p);
    vec2 p_curved = p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8));
    
    // 2. Exact Game UVs (Sampling)
    vec2 tex_uv = (p_curved + 0.5) / screen_scale;
    vec3 res = texture2D(Texture, tex_uv).rgb;

    // 3. Branchless Bounds Check
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float check = bounds.x * bounds.y;

    // 4. LOTTES SCANLINES (FIXED TO SCREEN COORDS)
    // بدلاً من استخدام TextureSize.y اللي بيتغير، نستخدم gl_FragCoord مع زوم يدوي
    // ده بيضمن إن عدد الخطوط ثابت بالنسبة لحجم الشاشة
    float pos_y = gl_FragCoord.y / SCAN_ZOOM;
    float dst = fract(pos_y) - 0.5;
    
    // معادلة Lottes الأصلية باستخدام exp2 والـ Hardness
    float scanline = exp2(hardScan * dst * dst);
    res = mix(res, res * scanline, SCAN_STR);

    // 5. RGB Mask (Locked to Screen Pixels)
    float W = floor(MASK_W);
    float pos = mod(gl_FragCoord.x, W) / W;
    vec3 mcol = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), mask_dark, mask_light);
    res *= mcol;

    // 6. Final Polish
    res *= BRIGHT_BOOST;
    res *= (1.0 - r2 * VIG_STR);

    gl_FragColor = vec4(res * check, 1.0);
}
#endif