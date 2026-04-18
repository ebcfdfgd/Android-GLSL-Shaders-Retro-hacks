#version 110

/* 777-LITE-TURBO-V4-HYBRID-STABLE
    - QUILEZ RETAINED: S-Curve scaling kept for anti-moire quality.
    - BRANCHLESS CURVE: Screen distortion rewritten as pure math (No IFs).
    - OPTIMIZED MASK: Vectorized mask logic for high-speed subpixels.
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
varying vec2 uv, screen_scale; 
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

varying vec2 uv, screen_scale;
uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, BRIGHT_BOOST, VIG_STR, SCAN_STR, SCAN_SIZE, MASK_STR, MASK_W;
#endif

void main() {
    // [1] حساب الإحداثيات والمركز
    vec2 p = (uv * screen_scale) - 0.5;
    float r2 = dot(p, p);

    // [2] Branchless Geometry (التحويل لعملية ضرب موحدة بدل الـ IF)
    // حساب الكيرف دائماً (لو الباراميتر 0 النتيجة تكون صورة مسطحة طبيعية)
    vec2 p_curved = p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8));
    p_curved *= (1.0 - 0.1 * BARREL_DISTORTION);

    // حدود الشاشة (Clipping) رياضياً
    // check سيكون 1 داخل الحدود و 0 خارجها
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float check = bounds.x * bounds.y;

    // [3] QUILEZ SCALING (تم الإبقاء عليها بناءً على طلبك)
    vec2 tex_uv = (p_curved + 0.5) / screen_scale;
    vec2 p_pix = tex_uv * TextureSize;
    vec2 i = floor(p_pix);
    vec2 f = p_pix - i;
    f = f * f * (3.0 - 2.0 * f); 
    vec3 res = texture2D(Texture, (i + f + 0.5) / TextureSize).rgb;

    // [4] Optimized Scanlines & Brightness
    float scanline = sin(tex_uv.y * InputSize.y * (6.28318 * SCAN_SIZE)) * 0.5 + 0.5;
    res = mix(res, res * scanline, SCAN_STR);
    res *= BRIGHT_BOOST;

    // [5] Branchless Mask & Vignette
    res *= (1.0 - r2 * VIG_STR);

    // تحويل الـ Mask إلى معادلة Mix (أسرع من الـ IF)
    float W = floor(MASK_W);
    float pos = mod(gl_FragCoord.x, W) / W;
    vec3 mcol = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), 0.6, 1.6);
    res = mix(res, res * mcol, MASK_STR);

    // تطبيق الـ Clipping النهائي (إخفاء الزوائد) والسطوع
    gl_FragColor = vec4(res * check, 1.0);
}
#endif