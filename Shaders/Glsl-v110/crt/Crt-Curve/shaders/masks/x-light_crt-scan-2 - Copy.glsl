#version 110

/* 777-V7-SUPRASONIC-LOTTES-QUILEZ
    - HARDWARE-ACCELERATED: Native Bilinear filtering.
    - QUILEZ: Integrated via UV-math (Zero extra samples).
    - BRANCHLESS: Optimized for performance.
*/

#pragma parameter BARREL_DISTORTION "Screen Curve" 0.15 0.0 1.0 0.02
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.25 1.0 2.5 0.05
#pragma parameter VIG_STR "Vignette Intensity" 0.15 0.0 2.0 0.05
#pragma parameter hardScan "Lottes Scan Hardness" -8.0 -20.0 0.0 1.0
#pragma parameter SCAN_STR "Scanline Intensity" 0.50 0.0 1.0 0.05
#pragma parameter MASK_STR "Mask Strength" 0.15 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width" 3.0 1.0 10.0 1.0

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
uniform float BARREL_DISTORTION, BRIGHT_BOOST, VIG_STR, hardScan, SCAN_STR, MASK_STR, MASK_W;
#endif

void main() {
    // 1. حساب الإحداثيات والمركز
    vec2 p = (uv * screen_scale) - 0.5;
    float r2 = dot(p, p); 

    // 2. انحناء الشاشة الرياضي
    vec2 p_curved = p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8)) * (1.0 - 0.1 * BARREL_DISTORTION);

    // 3. حدود الشاشة رياضياً
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float check = bounds.x * bounds.y;

    // 4. QUILEZ SCALING (تم الدمج بدون سحبات إضافية)
    vec2 tex_uv = (p_curved + 0.5) / screen_scale;
    vec2 p_pix = tex_uv * TextureSize;
    vec2 i = floor(p_pix);
    vec2 f = p_pix - i;
    f = f * f * (3.0 - 2.0 * f); // دالة Quilez للنعومة
    vec2 smooth_uv = (i + f + 0.5) / TextureSize;
    
    // سحب اللون باستخدام الإحداثيات المنعمة
    vec3 res = texture2D(Texture, smooth_uv).rgb;
    res *= res; 

    // 5. Lottes Gaussian Scanlines (استخدام tex_uv الأصلية للحفاظ على حدة الخطوط)
    float dst = fract(tex_uv.y * TextureSize.y) - 0.5;
    float scan = exp2(hardScan * dst * dst);
    res = mix(res, res * scan, SCAN_STR);

    // 6. Fast Mask
    float mw = floor(MASK_W);
    float pos = fract(gl_FragCoord.x / mw);
    vec3 mcol = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), 0.6, 1.6);
    res = mix(res, res * mcol, MASK_STR);

    // 7. اللمسات النهائية
    res *= BRIGHT_BOOST;
    res *= (1.0 - r2 * VIG_STR);
    
    gl_FragColor = vec4(sqrt(max(res * check, 0.0)), 1.0);
}
#endif