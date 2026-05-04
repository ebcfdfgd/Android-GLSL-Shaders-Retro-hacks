#version 110

/* ULTIMATE-CRT-CORE-ADAPTIVE (Hybrid 012 Curve)
    - CRT Logic: 012 Distortion, Smart Scanlines, Mask, Vignette
    - Feature: Scanline Bloom (Fades in bright areas based on threshold)
    - UPDATED: Independent Mask Light/Dark Controls
*/

// --- CRT PARAMETERS ---
#pragma parameter BARREL_DISTORTION "Screen Curve Strength" 0.15 0.0 1.0 0.02
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.20 1.0 2.0 0.01
#pragma parameter VIG_STR "Vignette Intensity" 0.15 0.0 2.0 0.05

// --- SMART SCANLINE PARAMETERS ---
#pragma parameter hardScan "Lottes Scan Hardness" -8.0 -20.0 0.0 1.0
#pragma parameter SCAN_STR "Scanline Intensity" 0.40 0.0 1.0 0.05
#pragma parameter SCAN_THRESH "Scanline Bloom Threshold" 0.8 0.5 1.0 0.05

// --- MASK PARAMETERS (Updated) ---
#pragma parameter MASK_LIGHT "Mask Light Strength" 1.5 1.0 2.0 0.05
#pragma parameter MASK_DARK "Mask Dark Strength" 0.5 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width (3=RGB)" 3.0 1.0 6.0 1.0

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
varying vec2 screen_scale; 
uniform mat4 MVPMatrix;
uniform vec2 TextureSize, InputSize;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    uv = TexCoord;
    screen_scale = TextureSize / InputSize; 
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
uniform float BARREL_DISTORTION, BRIGHT_BOOST, VIG_STR, hardScan, SCAN_STR, SCAN_THRESH, MASK_LIGHT, MASK_DARK, MASK_W;
#endif

// Smart Overlay blend function: Dynamic Bloom logic
float smart_overlay(float a, float b, float thresh) {
    return (a < thresh) ? 
           ( (1.0 / thresh) * a * b ) : 
           ( 1.0 - (1.0 / (1.0 - thresh)) * (1.0 - a) * (1.0 - b) );
}

void main() {
    // 1. Coordinates & 012 Curve Logic
    vec2 p = (uv * screen_scale) - 0.5;
    float r2 = dot(p, p);
    
    // معادلة انحناء 012 المتطورة
    vec2 p_curved = p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8));
    
    // 2. Branchless Bounds Check
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float check = bounds.x * bounds.y;

    // 3. Exact Game UVs
    vec2 tex_uv = (p_curved + 0.5) / screen_scale;
    vec3 res = texture2D(Texture, tex_uv).rgb;

    // 4. SMART LOTTES SCANLINES (Adaptive Mode)
    float dst = fract(tex_uv.y * TextureSize.y) - 0.5;
    float scanline = exp2(hardScan * dst * dst);
    
    vec3 smart_res;
    smart_res.r = smart_overlay(res.r, scanline, SCAN_THRESH);
    smart_res.g = smart_overlay(res.g, scanline, SCAN_THRESH);
    smart_res.b = smart_overlay(res.b, scanline, SCAN_THRESH);
    
    res = mix(res, clamp(smart_res, 0.0, 1.0), SCAN_STR);

    // 5. RGB Mask (Updated logic)
    float W = floor(MASK_W);
    float pos = mod(gl_FragCoord.x, W) / W;
    // تم استبدال القوة الثابتة بـ Clamp ديناميكي بين Light و Dark
    vec3 mcol = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), MASK_DARK, MASK_LIGHT);
    res *= mcol;

    // 6. Final Polish (012 Style Boost & Vignette)
    res *= (1.0 - r2 * VIG_STR);
    res *= BRIGHT_BOOST;

    // 7. Output with clean borders (check)
    gl_FragColor = vec4(res * check, 1.0);
}
#endif