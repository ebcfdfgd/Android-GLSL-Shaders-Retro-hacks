#version 110

/* 777-LITE-TURBO-V2-PERFECT-BALANCE (Backported to 110)
    - Fixed: Red tint at odd mask widths (like 5px).
    - Logic: Smooth Interpolation for balanced RGB phosphors.
    - Optimized: Low-overhead code for older Android devices.
*/

#pragma parameter BARREL_DISTORTION "Screen Curve" 0.15 0.0 0.3 0.01
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.05 1.0 2.5 0.05
#pragma parameter VIG_STR "Vignette Intensity" 0.15 0.0 2.0 0.05

// --- Scanlines Control ---
#pragma parameter SCAN_STR "Scanline Intensity" 0.35 0.0 1.0 0.05
#pragma parameter SCAN_SIZE "Scanline Size (Zoom)" 5.0 1.0 10.0 0.5

// --- Advanced Mask Control ---
#pragma parameter MASK_STR "Mask Strength" 0.15 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width" 3.0 1.0 10.0 1.0

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
uniform mat4 MVPMatrix;

void main() {
    uv = TexCoord;
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, BRIGHT_BOOST, VIG_STR, SCAN_STR, SCAN_SIZE, MASK_STR, MASK_W;
#endif

void main() {
    vec2 sc = TextureSize / InputSize;
    vec2 p = (uv * sc) - 0.5;

    // 1. Simple Curve (Geometry)
    float ky = BARREL_DISTORTION * 0.8; 
    vec2 p_curved;
    p_curved.x = p.x * (1.0 + (p.y * p.y) * (BARREL_DISTORTION * 0.2));
    p_curved.y = p.y * (1.0 + (p.x * p.x) * ky);
    p_curved *= (1.0 - 0.1 * BARREL_DISTORTION);

    if (abs(p_curved.x) > 0.5 || abs(p_curved.y) > 0.5) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // 2. Sample & Brightness
    vec3 res = texture2D(Texture, (p_curved + 0.5) / sc).rgb;
    res *= BRIGHT_BOOST;

    // 3. Vignette
    res *= (1.0 - dot(p_curved, p_curved) * VIG_STR);

    // 4. Scanlines
    // استبدال gl_FragCoord بما يتناسب مع OpenGL ES 2.0
    float scanline = sin(gl_FragCoord.y * (6.28318 / SCAN_SIZE)) * 0.5 + 0.5;
    res *= mix(1.0, scanline, SCAN_STR);

    // 5. Balanced RGB Mask (منع زيادة اللون الأحمر في الأبعاد الفردية)
    float W = floor(MASK_W);
    float pos = mod(gl_FragCoord.x, W);
    
    // معادلة التوزيع اللوني المتوازن لمنع الـ Tinting
    vec3 mcol;
    mcol.r = clamp(2.0 - abs((pos / W) * 6.0 - 1.0), 0.6, 1.6);
    mcol.g = clamp(2.0 - abs((pos / W) * 6.0 - 3.0), 0.6, 1.6);
    mcol.b = clamp(2.0 - abs((pos / W) * 6.0 - 5.0), 0.6, 1.6);

    res = mix(res, res * mcol, MASK_STR);

    gl_FragColor = vec4(res, 1.0);
}
#endif