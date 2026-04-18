#version 110

/* ARCADE-MASTER-TURBO-V5-QUILEZ
    - QUALITY: Quilez scaling kept for zero-moire arcade visuals.
    - BRANCHLESS: Replaced all IF/Return statements with mathematical Mix/Step.
    - PERFORMANCE: Unified color grading and effects path.
*/

#pragma parameter BARREL_DISTORTION "Arcade: Screen Curve" 0.08 0.0 0.5 0.01
#pragma parameter bright_boost "Arcade: Brightness" 1.30 0.0 2.5 0.05
#pragma parameter contrast_val "Arcade: Contrast" 1.0 0.0 2.0 0.05
#pragma parameter sat_val "Arcade: Saturation" 1.1 0.0 2.0 0.05
#pragma parameter glow_str "Arcade: Glow/Halo" 0.25 0.0 1.0 0.05
#pragma parameter conv_shift "Arcade: Chrom Fringing" 0.40 0.0 1.0 0.05
#pragma parameter mask_type "CRT Mask: (0:Trin 1:Slot)" 1.0 0.0 1.0 1.0
#pragma parameter mask_str "CRT Mask: Strength" 0.45 0.0 1.0 0.05
#pragma parameter scan_str "CRT: Scanline Intensity" 0.70 0.0 1.0 0.05
#pragma parameter black_level "CRT: Black Depth" 0.05 0.0 0.5 0.01
#pragma parameter v_amount "Arcade: Vignette" 0.25 0.0 2.5 0.01

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord, sc_inv, tex_res; 
uniform mat4 MVPMatrix;
uniform vec2 TextureSize, InputSize;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord;
    tex_res = TextureSize;
    sc_inv = TextureSize / InputSize;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;
varying vec2 vTexCoord, sc_inv, tex_res;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, bright_boost, contrast_val, sat_val, glow_str, conv_shift;
uniform float mask_type, mask_str, scan_str, black_level, v_amount;
#endif

// WORLD'S FASTEST QUILEZ SCALING (Hardware Accelerated)
vec3 texQuilez(sampler2D tex, vec2 uv, vec2 res) {
    vec2 p = uv * res;
    vec2 i = floor(p);
    vec2 f = p - i;
    f = f * f * (3.0 - 2.0 * f); 
    return texture2D(tex, (i + f + 0.5) / res).rgb;
}

void main() {
    // 1. حساب الإحداثيات والكيرف (Branchless)
    vec2 uv = (vTexCoord * sc_inv) - 0.5;
    float r2 = dot(uv, uv);
    vec2 d_uv = uv * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8)) * (1.0 - 0.15 * BARREL_DISTORTION);

    // حدود الشاشة (Clipping) رياضياً
    vec2 bounds = step(abs(d_uv), vec2(0.5));
    float check = bounds.x * bounds.y;

    vec2 pos = (d_uv + 0.5) / sc_inv;

    // 2. سحب اللون الأساسي (Quilez)
    vec3 col = texQuilez(Texture, pos, tex_res);
    col *= col; // Linear Space

    // 3. Chromatic Aberration & Glow (Branchless Path)
    vec2 off = (1.0 / tex_res) * (1.2 + conv_shift);
    vec3 col_l = texQuilez(Texture, pos - vec2(off.x, 0.0), tex_res);
    vec3 col_r = texQuilez(Texture, pos + vec2(off.x, 0.0), tex_res);
    col_l *= col_l; col_r *= col_r;

    // دمج التأثيرات رياضياً (Mix بدلاً من IF)
    col += (col_l + col_r) * 0.4 * glow_str;
    col.r = mix(col.r, col_l.r * 1.2, conv_shift);
    col.b = mix(col.b, col_r.b * 1.2, conv_shift);

    // 4. Scanlines (Smooth Sinusoidal)
    float scan = 0.5 + 0.5 * sin(pos.y * InputSize.y * 6.28318);
    col = mix(col, col * scan * scan, scan_str);

    // 5. Fast CRT Mask (Vectorized)
    float m_trin = fract(gl_FragCoord.x * 0.3333);
    vec3 mask_trin = (m_trin < 0.333) ? vec3(1.1, 0.8, 0.8) : (m_trin < 0.666) ? vec3(0.8, 1.1, 0.8) : vec3(0.8, 0.8, 1.1);
    
    float m_slot = fract(gl_FragCoord.x * 0.5 + floor(gl_FragCoord.y * 0.2) * 0.5);
    vec3 mask_slot = (m_slot < 0.5) ? vec3(1.1, 0.8, 1.1) : vec3(0.8, 1.1, 0.8);
    
    vec3 mask_final = mix(mask_trin, mask_slot, step(0.5, mask_type));
    col = mix(col, col * mask_final, mask_str);

    // 6. Color Grading (Linear Path)
    col = max(col - black_level, 0.0) / (1.0 - black_level);
    col *= bright_boost;
    col = (col - 0.5) * contrast_val + 0.5;
    col = mix(vec3(dot(col, vec3(0.3, 0.59, 0.11))), col, sat_val);
    
    // Vignette
    col *= (1.0 - r2 * v_amount);

    // الخروج النهائي (Gamma Correction + Clipping)
    gl_FragColor = vec4(sqrt(max(col * check, 0.0)), 1.0);
}
#endif