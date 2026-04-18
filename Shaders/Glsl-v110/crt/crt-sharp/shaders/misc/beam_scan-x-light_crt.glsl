#version 110

/* 777-V7-LOTTES-STABLE-QUILEZ
    - LOTTES GAUSSIAN: Physical fading kept for CRT authenticity.
    - QUILEZ SCALING: Anti-moire S-Curve retained.
    - BRANCHLESS: Zero IF/Return for maximum frame stability.
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
    // [1] حساب الإحداثيات والمركز (Branchless Geometry)
    vec2 p = (uv * screen_scale) - 0.5;
    float r2 = dot(p, p);
    vec2 p_curved = p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8)) * (1.0 - 0.1 * BARREL_DISTORTION);

    // حدود الشاشة (Clipping) رياضياً
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float check = bounds.x * bounds.y;

    // [2] Quilez Scaling (تم الإبقاء عليها للجودة)
    vec2 tex_uv = (p_curved + 0.5) / screen_scale;
    vec2 p_pix = tex_uv * TextureSize;
    vec2 i = floor(p_pix);
    vec2 f = p_pix - i;
    f = f * f * (3.0 - 2.0 * f); 
    
    vec3 res = texture2D(Texture, (i + f + 0.5) / TextureSize).rgb;
    res *= res; // Linear Space لضمان عمل نظام Lottes بدقة

    // [3] Lottes Gaussian Scanlines (تلاشي فيزيائي صامت)
    float dst = fract(tex_uv.y * TextureSize.y) - 0.5;
    float scan = exp2(hardScan * dst * dst);
    res = mix(res, res * scan, SCAN_STR);

    // [4] Turbo Mask & Vignette (Branchless Path)
    res *= (1.0 - r2 * VIG_STR);

    float invW = 1.0 / floor(max(MASK_W, 1.0));
    float m_pos = fract(gl_FragCoord.x * invW);
    vec3 mcol = clamp(2.0 - abs(m_pos * 6.0 - vec3(1.0, 3.0, 5.0)), 0.6, 1.6);
    res = mix(res, res * mcol, MASK_STR);

    // [5] Final Polish (Brightness + Clipping + Gamma Correction)
    res *= BRIGHT_BOOST;
    
    // إخفاء الزوائد خلف الكيرف والعودة من الحالة الخطية
    gl_FragColor = vec4(sqrt(max(res * check, 0.0)), 1.0);
}
#endif