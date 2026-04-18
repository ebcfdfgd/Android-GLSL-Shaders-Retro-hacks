#version 110

/* LIGHT-ULTRA-V11 - TURBO-STABLE-QUILEZ
    - RETAINED: Quilez scaling kept for superior anti-moire quality.
    - BRANCHLESS: Replaced all IF/Return statements with mathematical clipping (step/mix).
    - GPU-OPTIMIZED: Accelerated mask selection logic for Mali/Adreno performance.
*/

#pragma parameter BARREL_DISTORTION "Screen Curve" 0.15 0.0 0.5 0.01
#pragma parameter VIG_STR "Vignette Intensity" 0.15 0.0 1.0 0.05
#pragma parameter hardScan "Scanline Hardness" -8.0 -20.0 0.0 1.0
#pragma parameter scan_str "Scanline Intensity" 0.5 0.0 1.0 0.05
#pragma parameter br_boost "Bright Boost" 1.3 0.0 2.5 0.05
#pragma parameter mask_opacity "Mask Strength" 0.5 0.0 1.0 0.05
#pragma parameter MASK_MODE "Mask: 0:PNG1, 1:PNG2, 2:Dual" 0.0 0.0 2.0 1.0
#pragma parameter LUTWidth1 "PNG1 Width" 3.0 1.0 1024.0 1.0
#pragma parameter LUTHeight1 "PNG1 Height" 1.0 1.0 1024.0 1.0
#pragma parameter LUTWidth2 "PNG2 Width" 6.0 1.0 1024.0 1.0
#pragma parameter LUTHeight2 "PNG2 Height" 4.0 1.0 1024.0 1.0

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord, screen_scale;
uniform mat4 MVPMatrix;
uniform vec2 TextureSize, InputSize;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord;
    screen_scale = TextureSize / InputSize; 
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 vTexCoord, screen_scale;
uniform sampler2D Texture, shadowMaskSampler, shadowMaskSampler1;
uniform vec2 TextureSize, InputSize;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, VIG_STR, hardScan, scan_str, mask_opacity, br_boost, MASK_MODE;
uniform float LUTWidth1, LUTHeight1, LUTWidth2, LUTHeight2;
#endif

void main() {
    // 1. حساب الإحداثيات والمركز (Branchless Geometry)
    vec2 p = (vTexCoord * screen_scale) - 0.5;
    float r2 = dot(p, p);
    vec2 p_curved = p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8)) * (1.0 - 0.1 * BARREL_DISTORTION);

    // حدود الشاشة (Clipping) رياضياً بدلاً من IF
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float check = bounds.x * bounds.y;

    // --- 2. WORLD'S FASTEST QUILEZ SCALING (تم الإبقاء عليها للجودة) ---
    vec2 uv_pre = (p_curved + 0.5) / screen_scale;
    vec2 p_pix = uv_pre * TextureSize;
    vec2 i = floor(p_pix);
    vec2 f = p_pix - i;
    f = f * f * (3.0 - 2.0 * f); 
    vec3 col = texture2D(Texture, (i + f + 0.5) / TextureSize).rgb;
    col *= col; // التحويل للـ Linear Space

    // 3. الـ Scanlines (Lottes Gaussian) - Branchless Mix
    float dst = fract(uv_pre.y * InputSize.y) - 0.5;
    float lottes = exp2(hardScan * dst * dst);
    col = mix(col, col * lottes, scan_str);

    // 4. نظام الماسك السريع (Logic-Free Mask Selection)
    vec3 m1 = texture2D(shadowMaskSampler, gl_FragCoord.xy / vec2(LUTWidth1, LUTHeight1)).rgb;
    vec3 m2 = texture2D(shadowMaskSampler1, gl_FragCoord.xy / vec2(LUTWidth2, LUTHeight2)).rgb;
    
    // اختيار الماسك رياضياً (Branchless Selection)
    vec3 final_mask = mix(m1, m2, step(0.5, MASK_MODE));
    final_mask = mix(final_mask, m1 * m2, step(1.5, MASK_MODE));
    
    col = mix(col, col * final_mask, mask_opacity);

    // 5. اللمسات الأخيرة (Vignette + Brightness)
    col *= (1.0 - r2 * VIG_STR);
    col *= br_boost;

    // تطبيق الـ Clipping النهائي (إخفاء ما وراء الكيرف) والعودة من الحالة الخطية
    gl_FragColor = vec4(sqrt(max(col * check, 0.0)), 1.0);
}
#endif