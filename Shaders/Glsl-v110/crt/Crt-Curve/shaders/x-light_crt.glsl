#version 110

/* 777-LITE-TURBO-V4-ULTRA-FIXED
    - FIXED: Scanlines now lock perfectly to game pixels (No more giant lines).
    - SPEED: Zero-cost math, Branchless logic.
*/

#pragma parameter BARREL_DISTORTION "Screen Curve" 0.15 0.0 1.0 0.02
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.20 1.0 2.0 0.01
#pragma parameter VIG_STR "Vignette Intensity" 0.15 0.0 2.0 0.05
#pragma parameter SCAN_STR "Scanline Intensity" 0.40 0.0 1.0 0.05
#pragma parameter SCAN_SIZE "Scanline Density" 1.0 0.5 2.0 0.05
#pragma parameter MASK_STR "Mask Strength" 0.20 0.0 1.0 0.05
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
uniform float BARREL_DISTORTION, BRIGHT_BOOST, VIG_STR, SCAN_STR, SCAN_SIZE, MASK_STR, MASK_W;
#endif

void main() {
    // 1. Coordinates & Curve
    vec2 p = (uv * screen_scale) - 0.5;
    float r2 = dot(p, p);
    vec2 p_curved = p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8));
    
    // 2. Exact Game UVs
    vec2 tex_uv = (p_curved + 0.5) / screen_scale;
    vec3 res = texture2D(Texture, tex_uv).rgb;

    // 3. Branchless Bounds Check
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float check = bounds.x * bounds.y;

    // 4. FIXED SCANLINES (The Fix)
    // نستخدم p_curved.y + 0.5 لضمان إن الحساب يبدأ من بداية صورة اللعبة مش بداية التكستشر
    float scan_pos = (p_curved.y + 0.5) * InputSize.y;
    float scanline = sin(scan_pos * 6.28318 * SCAN_SIZE) * 0.5 + 0.5;
    res = mix(res, res * scanline, SCAN_STR);

    // 5. Optimized RGB Mask
    float W = floor(MASK_W);
    float pos = mod(gl_FragCoord.x, W) / W;
    vec3 mcol = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), 0.6, 1.6);
    res = mix(res, res * mcol, MASK_STR);

    // 6. Final Polish
    res *= BRIGHT_BOOST;
    res *= (1.0 - r2 * VIG_STR);

    gl_FragColor = vec4(res * check, 1.0);
}
#endif