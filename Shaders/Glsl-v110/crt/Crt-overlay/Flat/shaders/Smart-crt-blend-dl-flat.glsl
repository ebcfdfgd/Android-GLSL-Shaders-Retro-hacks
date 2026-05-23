#version 110

/* ULTIMATE-CRT-CORE-ADAPTIVE (Flat Version)
    - CRT Logic: Smart Scanlines, Mask
    - Feature: Scanline Bloom (Fades in bright areas based on threshold)
    - UPDATED: Independent Mask Light/Dark Controls, No Curve/Vignette
*/

// --- CRT PARAMETERS ---
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.20 1.0 2.0 0.01

// --- SMART SCANLINE PARAMETERS ---
#pragma parameter hardScan "Lottes Scan Hardness" -8.0 -20.0 0.0 1.0
#pragma parameter SCAN_STR "Scanline Intensity" 0.40 0.0 1.0 0.05
#pragma parameter SCAN_THRESH "Scanline Bloom Threshold" 0.8 0.5 1.0 0.05

// --- MASK PARAMETERS ---
#pragma parameter MASK_LIGHT "Mask Light Strength" 1.5 1.0 2.0 0.05
#pragma parameter MASK_DARK "Mask Dark Strength" 0.5 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width (3=RGB)" 3.0 1.0 6.0 1.0

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    uv = TexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize;

#ifdef PARAMETER_UNIFORM
uniform float BRIGHT_BOOST, hardScan, SCAN_STR, SCAN_THRESH, MASK_LIGHT, MASK_DARK, MASK_W;
#endif

// Smart Overlay blend function: Dynamic Bloom logic
float smart_overlay(float a, float b, float thresh) {
    return (a < thresh) ? 
           ( (1.0 / thresh) * a * b ) : 
           ( 1.0 - (1.0 / (1.0 - thresh)) * (1.0 - a) * (1.0 - b) );
}

void main() {
    // 1. Direct Sampling
    vec2 tex_uv = uv;
    vec3 res = texture2D(Texture, tex_uv).rgb;

    // 2. SMART LOTTES SCANLINES (Adaptive Mode)
    float dst = fract(tex_uv.y * TextureSize.y) - 0.5;
    float scanline = exp2(hardScan * dst * dst);
    
    vec3 smart_res;
    smart_res.r = smart_overlay(res.r, scanline, SCAN_THRESH);
    smart_res.g = smart_overlay(res.g, scanline, SCAN_THRESH);
    smart_res.b = smart_overlay(res.b, scanline, SCAN_THRESH);
    
    res = mix(res, clamp(smart_res, 0.0, 1.0), SCAN_STR);

    // 3. RGB Mask
    float W = floor(MASK_W);
    float pos = mod(gl_FragCoord.x, W) / W;
    vec3 mcol = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), MASK_DARK, MASK_LIGHT);
    res *= mcol;

    // 4. Final Polish
    res *= BRIGHT_BOOST;

    // 5. Output
    gl_FragColor = vec4(res, 1.0);
}
#endif