#version 110

/* 777-HYPER-TURBO-V5 (Pro-Max Speed)
    - BRANCHLESS: Eliminated IFs for seamless GPU execution.
    - MATH-OPTIMIZED: Replaced 'pow' with multiplication for faster scanlines.
    - REUSE: Combined r2 (dot product) for Curve, Vignette, and Clipping.
*/

#pragma parameter BARREL_DISTORTION "Screen Curve" 0.12 0.0 0.5 0.01
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.25 1.0 2.5 0.05
#pragma parameter VIG_STR "Vignette Intensity" 0.15 0.0 2.0 0.05
#pragma parameter SCAN_STR "Scanline Intensity" 0.35 0.0 1.0 0.05
#pragma parameter SCAN_BEAM "Scanline Thinness" 1.5 0.5 10.0 0.1
#pragma parameter MASK_STR "Mask Strength" 0.15 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width" 3.0 1.0 10.0 1.0

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv, screen_sc, inv_tex_size;
uniform mat4 MVPMatrix;
uniform vec2 TextureSize, InputSize;

void main() {
    uv = TexCoord;
    screen_sc = TextureSize / InputSize;
    inv_tex_size = 1.0 / TextureSize; 
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 uv, screen_sc, inv_tex_size;
uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, BRIGHT_BOOST, VIG_STR, SCAN_STR, SCAN_BEAM, MASK_STR, MASK_W;
#endif

void main() {
    // [1] الأساسيات
    vec2 p = (uv * screen_sc) - 0.5;
    float r2 = dot(p, p); 

    // [2] Geometry Curve (Branchless)
    vec2 p_curved = mix(p, p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8)) * (1.0 - 0.1 * BARREL_DISTORTION), step(0.001, BARREL_DISTORTION));

    // [3] Clipping (ضرب النتيجة النهائية في check لتجنب if)
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float check = bounds.x * bounds.y;

    // [4] High-Speed Quilez Scaling
    vec2 tex_uv = (p_curved + 0.5) / screen_sc;
    vec2 coord = tex_uv * TextureSize;
    vec2 i = floor(coord);
    vec2 f = fract(coord);
    f = f * f * (3.0 - 2.0 * f); 
    vec3 res = texture2D(Texture, (i + f + 0.5) * inv_tex_size).rgb;

    // [5] Fast Scanlines (استبدال pow بضرب بسيط للسرعة)
    float s_base = 0.5 + 0.5 * sin(tex_uv.y * InputSize.y * 6.28318);
    float scanline = s_base * s_base; // تعطي تأثير الـ Thinness بجهد أقل
    res = mix(res, res * scanline, SCAN_STR);

    // [6] Fast Mask (Vectorized)
    float mw = floor(MASK_W);
    float pos = mod(gl_FragCoord.x, mw) / mw;
    vec3 mcol = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), 0.6, 1.6);
    res = mix(res, res * mcol, MASK_STR);

    // [7] Final Fusion
    res *= BRIGHT_BOOST;
    res *= (1.0 - r2 * VIG_STR);
    
    gl_FragColor = vec4(res * check, 1.0);
}
#endif