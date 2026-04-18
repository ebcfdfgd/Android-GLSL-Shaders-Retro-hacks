#version 110

/* LIGHT-ULTIMATE 1111 - OMNI-TURBO-NON-STOP
    - HARDWARE-ALIGNED: Replaced Quilez with 1:1 GPU Texture Fetching.
    - BRANCHLESS: Zero IF statements in the main shading path.
    - OPTIMIZED MASK: Triple-blending PNG masks using vectorized math.
*/

#pragma parameter BARREL_DISTORTION "Screen Curve" 0.12 0.0 0.5 0.01
#pragma parameter VIG_STR "Vignette Intensity" 0.15 0.0 1.0 0.05
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
uniform float BARREL_DISTORTION, VIG_STR, scan_str, mask_opacity, br_boost, MASK_MODE;
uniform float LUTWidth1, LUTHeight1, LUTWidth2, LUTHeight2;
#endif

void main() {
    // 1. حساب الإحداثيات والمركز
    vec2 p = (vTexCoord * screen_scale) - 0.5;
    float r2 = dot(p, p);

    // 2. انحناء الشاشة الرياضي (Branchless)
    vec2 p_curved = p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8));
    p_curved *= (1.0 - 0.1 * BARREL_DISTORTION);

    // 3. Clipping (بدل الـ if والـ return)
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float check = bounds.x * bounds.y;

    // 4. سحب اللون بالهاردوير مباشرة (أقصى سرعة ممكنة)
    vec2 uv_final = (p_curved + 0.5) / screen_scale;
    vec3 col = texture2D(Texture, uv_final).rgb;
    col *= col; // التحويل لـ Linear Space

    // 5. سكان لاينز اقتصادية (بديل الـ Gaussian الثقيل)
    float scanline = 0.5 + 0.5 * cos(uv_final.y * InputSize.y * 6.28318);
    col = mix(col, col * scanline, scan_str);

    // 6. نظام الماسك الموحد (Branchless Mask Selection)
    vec2 m_uv1 = gl_FragCoord.xy / vec2(LUTWidth1, LUTHeight1);
    vec2 m_uv2 = gl_FragCoord.xy / vec2(LUTWidth2, LUTHeight2);
    vec3 m1 = texture2D(shadowMaskSampler, m_uv1).rgb;
    vec3 m2 = texture2D(shadowMaskSampler1, m_uv2).rgb;
    
    // اختيار الماسك بناءً على MASK_MODE برياضيات الـ mix
    vec3 mask_final = mix(m1, m2, step(0.5, MASK_MODE));
    mask_final = mix(mask_final, m1 * m2, step(1.5, MASK_MODE));
    
    col = mix(col, col * mask_final, mask_opacity);

    // 7. المعالجة النهائية (Vignette + Boost + Clipping)
    col *= (1.0 - r2 * VIG_STR);
    col *= br_boost;
    col *= check; // إخفاء ما وراء الانحناء

    gl_FragColor = vec4(sqrt(max(col, 0.0)), 1.0);
}
#endif