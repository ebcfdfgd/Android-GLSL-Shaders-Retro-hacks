#version 110

/* 777-ULTIMATE-V7-BRANCHLESS
    - LOTTES GAUSSIAN: Retained physical beam fading.
    - QUILEZ SCALING: S-Curve anti-moire logic retained.
    - ZERO-BRANCHING: Replaced all IF statements with Mix/Step/Check.
    - GPU-STABLE: Maximum frame-rate consistency for mobile devices.
*/

#pragma parameter BARREL_DISTORTION "Screen Curve (0=OFF)" 0.12 0.0 0.5 0.01
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.3 1.0 2.5 0.05
#pragma parameter v_amount "Vignette Intensity" 0.25 0.0 2.5 0.01

// --- Mask System ---
#pragma parameter MASK_TYPE "Mask: 0:RGB, 1:PNG" 0.0 0.0 1.0 1.0
#pragma parameter MASK_STR "Mask Intensity" 0.45 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width" 3.0 1.0 15.0 1.0
#pragma parameter MASK_H "Mask Height" 3.0 1.0 15.0 1.0

// --- Lottes Scanlines ---
#pragma parameter hardScan "Scanline Hardness" -8.0 -20.0 0.0 1.0
#pragma parameter SCAN_STR "Scanline Intensity" 0.50 0.0 1.0 0.05
#pragma parameter SCAN_DENS "Scanline Density" 1.0 0.2 10.0 0.1

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 TEX0, screen_scale, inv_tex_size;
uniform mat4 MVPMatrix;
uniform vec2 TextureSize, InputSize;

void main() {
    TEX0 = TexCoord;
    screen_scale = TextureSize / InputSize;
    inv_tex_size = 1.0 / TextureSize;
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 TEX0, screen_scale, inv_tex_size;
uniform sampler2D Texture, SamplerMask1;
uniform vec2 TextureSize, InputSize;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, BRIGHT_BOOST, v_amount;
uniform float MASK_TYPE, MASK_STR, MASK_W, MASK_H;
uniform float hardScan, SCAN_STR, SCAN_DENS;
#endif

void main() {
    // 1. حساب الإحداثيات والمركز (Branchless Geometry)
    vec2 uv = (TEX0.xy * screen_scale) - 0.5;
    float r2 = dot(uv, uv);
    
    // انحناء الشاشة الرياضي الصامت
    vec2 d_uv = uv * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8)) * (1.0 - 0.15 * BARREL_DISTORTION);

    // حدود الشاشة (Clipping) رياضياً بدلاً من IF
    vec2 bounds = step(abs(d_uv), vec2(0.5));
    float check = bounds.x * bounds.y;

    // 2. QUILEZ SCALING (Anti-Moire)
    vec2 tex_uv = (d_uv + 0.5) / screen_scale;
    vec2 p = tex_uv * TextureSize;
    vec2 i = floor(p);
    vec2 f = p - i;
    f = f * f * (3.0 - 2.0 * f); 
    
    vec3 res = texture2D(Texture, (i + f + 0.5) * inv_tex_size).rgb;
    res *= res; // Linear Space لضمان عمل نظام لوتس

    // 3. Lottes Dynamic Scanlines (Branchless Mix)
    float dst = fract(tex_uv.y * TextureSize.y * SCAN_DENS) - 0.5;
    float scan = exp2(hardScan * dst * dst);
    res = mix(res, res * scan, SCAN_STR);

    // 4. نظام الماسك الموحد (Vectorized Mask Logic)
    float mw = floor(max(MASK_W, 1.0));
    float mh = floor(max(MASK_H, 1.0));
    
    // RGB Mask Math
    float m_pos = fract(gl_FragCoord.x / mw);
    vec3 mcol_rgb = clamp(2.0 - abs(m_pos * 6.0 - vec3(1.0, 3.0, 5.0)), 0.6, 1.6);
    
    // PNG Mask Texture
    vec3 mcol_png = texture2D(SamplerMask1, gl_FragCoord.xy / vec2(mw, mh)).rgb * 1.5;
    
    // اختيار نوع الماسك رياضياً (Branchless Selection)
    vec3 mcol_final = mix(mcol_rgb, mcol_png, step(0.5, MASK_TYPE));
    res = mix(res, res * mcol_final, MASK_STR);

    // 5. اللمسات النهائية (Brightness + Vignette)
    res *= BRIGHT_BOOST;
    res *= mix(1.0, clamp(1.0 - (r2 * v_amount), 0.0, 1.0), step(0.01, v_amount));

    // ضرب النتيجة في check لإخفاء ما وراء الكيرف والتحويل لـ Gamma Correct
    gl_FragColor = vec4(sqrt(max(res * check, 0.0)), 1.0);
}
#endif