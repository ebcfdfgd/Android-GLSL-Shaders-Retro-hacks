#version 110

/* 777-LITE-V2-PERFECT-BALANCE (1012 Scanline Integration)
    - INTEGRATED: Timothy Lottes Fast Gaussian Scanlines from 1012.
    - REMOVED: Legacy Sine-wave scanlines.
    - OPTIMIZED: Exponential decay for realistic CRT beam profiles.
*/

#pragma parameter BARREL_DISTORTION "Screen Curve" 0.15 0.0 1.0 0.02
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.17 1.0 2.0 0.01
#pragma parameter VIG_STR "Vignette Intensity" 0.15 0.0 2.0 0.05

// --- Lottes 1012 Scanlines Control ---
#pragma parameter hardScan "Scanline Hardness" -8.0 -20.0 0.0 1.0
#pragma parameter SCAN_STR "Scanline Intensity" 0.30 0.0 1.0 0.05

// --- Advanced Mask Control ---
#pragma parameter MASK_STR "Mask Strength" 0.15 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width" 5.0 1.0 10.0 1.0

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
uniform float BARREL_DISTORTION, BRIGHT_BOOST, VIG_STR, hardScan, SCAN_STR, MASK_STR, MASK_W;
#endif

void main() {
    vec2 sc = TextureSize / InputSize;
    vec2 p = (uv * sc) - 0.5;

    // 1. Geometry (Simple Curve)
    float ky = BARREL_DISTORTION * 0.8; 
    vec2 p_curved;
    p_curved.x = p.x * (1.0 + (p.y * p.y) * (BARREL_DISTORTION * 0.2));
    p_curved.y = p.y * (1.0 + (p.x * p.x) * ky);
    p_curved *= (1.0 - 0.1 * BARREL_DISTORTION);

    if (abs(p_curved.x) > 0.5 || abs(p_curved.y) > 0.5) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // 2. Sampling
    vec2 final_uv = (p_curved + 0.5) / sc;
    vec3 res = texture2D(Texture, final_uv).rgb;

    // 3. 1012 Scanlines Integration (Fast Gaussian Approximation)
    // حساب المسافة من مركز الخط بناءً على إحداثيات الصورة الأصلية
    float pos_y = final_uv.y * TextureSize.y;
    float dst = fract(pos_y) - 0.5;
    
    // معادلة Lottes الموفرة للطاقة: exp2(Hardness * dst^2)
    float scan = exp2(hardScan * dst * dst);
    res *= mix(1.0, scan, SCAN_STR);

    // 4. Balanced RGB Mask (Anti-Red Tint)
    float W = floor(MASK_W);
    float pos_x = mod(gl_FragCoord.x, W);
    vec3 mcol = clamp(2.0 - abs((pos_x / W) * 6.0 - vec3(1.0, 3.0, 5.0)), 0.6, 1.6);
    res = mix(res, res * mcol, MASK_STR);

    // 5. Final Adjustments
    res *= BRIGHT_BOOST;
    res *= (1.0 - dot(p_curved, p_curved) * VIG_STR);

    gl_FragColor = vec4(max(res, 0.0), 1.0);
}
#endif