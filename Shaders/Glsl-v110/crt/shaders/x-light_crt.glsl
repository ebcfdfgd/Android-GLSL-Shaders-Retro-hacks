#version 110

/* 777-LITE-TURBO-V4-ULTRA (SPEED MATCHED WITH LCD)
    - SPEED: Removed Quilez scaling; relies on zero-cost Hardware Bilinear.
    - BRANCHLESS: Removed all "if/return" bounds checking for 100% GPU throughput.
*/

#pragma parameter BARREL_DISTORTION "Screen Curve" 0.15 0.0 1.0 0.02
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.17 1.0 2.0 0.01
#pragma parameter VIG_STR "Vignette Intensity" 0.15 0.0 2.0 0.05
#pragma parameter SCAN_STR "Scanline Intensity" 0.30 0.0 1.0 0.05
#pragma parameter SCAN_SIZE "Scanline Zoom (Density)" 1.0 0.5 4.0 0.1
#pragma parameter MASK_STR "Mask Strength" 0.15 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width" 5.0 1.0 10.0 1.0

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
    vec2 p = (uv * screen_scale) - 0.5;
    
    // 1. Branchless Geometry Curve (إلغاء الـ if لتسريع المعالجة)
    float r2 = dot(p, p);
    vec2 p_curved = p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8));
    p_curved *= (1.0 - 0.1 * BARREL_DISTORTION);
    
    vec2 tex_uv = (p_curved + 0.5) / screen_scale;

    // 2. Hardware Texture Fetch (السر الحقيقي لسرعة شيدر الـ LCD)
    vec3 res = texture2D(Texture, tex_uv).rgb;

    // 3. Branchless Bounds Check (إخفاء الحواف رياضياً بدون return)
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    res *= bounds.x * bounds.y;

    // 4. Optimized Scanlines & Brightness
    float scanline = sin(tex_uv.y * InputSize.y * (6.28318 * SCAN_SIZE)) * 0.5 + 0.5;
    res *= mix(1.0, scanline, SCAN_STR);
    res *= BRIGHT_BOOST;

    // 5. Fast Vignette
    res *= (1.0 - dot(p_curved, p_curved) * VIG_STR);

    // 6. Vectorized RGB Mask (نفس قوة الـ V3 ولكن مستمرة بدون تعطيل)
    float W = floor(MASK_W);
    float pos = mod(gl_FragCoord.x, W);
    vec3 mcol = clamp(2.0 - abs((pos / W) * 6.0 - vec3(1.0, 3.0, 5.0)), 0.6, 1.6);
    res = mix(res, res * mcol, MASK_STR);

    gl_FragColor = vec4(res, 1.0);
}
#endif