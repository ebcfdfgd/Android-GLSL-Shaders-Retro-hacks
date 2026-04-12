#version 110

/* TIMOTHY LOTTES - HYBRID "0130" PERFORMANCE (V4.8 - TRUE BOOST)
    - OPTIMIZATION: Zero-Parameter Bypass (إيقاف كامل للحسابات عند التصفير)
    - FIXED: Bright Boost now placed AFTER scanlines/mask to restore lost light.
    - LOGIC: Replaced heavy math with conditional skips for Helio G90T/Older Androids.
*/

#pragma parameter BARREL_DISTORTION "Screen Curve" 0.12 0.0 0.5 0.01
#pragma parameter VIG_STR "Vignette Intensity" 0.15 0.0 1.0 0.05
#pragma parameter hardScan "Scanline Hardness" -8.0 -20.0 0.0 1.0
#pragma parameter scan_str "Scanline Intensity" 0.70 0.0 1.0 0.05
#pragma parameter hardPix "Pixel Hardness" -3.0 -20.0 0.0 1.0
#pragma parameter maskDark "Mask Dark" 0.5 0.0 2.0 0.1
#pragma parameter maskLight "Mask Light" 1.5 0.0 2.0 0.1
#pragma parameter brightBoost "Bright Boost" 1.3 0.0 2.5 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;
varying vec2 vTexCoord;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, VIG_STR, hardScan, scan_str, hardPix, maskDark, maskLight, brightBoost;
#endif

void main() {
    // 1. نظام الإيقاف الفوري (ULTRA-FAST BYPASS)
    // لو الانحناء والخطوط والماسك "صفر"، يتم عرض الصورة فوراً بتوفير طاقة 100%
    if (BARREL_DISTORTION <= 0.0 && scan_str <= 0.0 && maskDark >= 1.0 && maskLight <= 1.0) {
        vec3 raw_col = texture2D(Texture, vTexCoord).rgb;
        gl_FragColor = vec4(raw_col * brightBoost, 1.0);
        return; 
    }

    // 2. GEOMETRY (0130 Core)
    vec2 sc = TextureSize / InputSize;
    vec2 p = (vTexCoord * sc) - 0.5;
    
    vec2 p_curved;
    // لا نحسب الانحناء إلا إذا كانت قيمته أكبر من صفر
    if (BARREL_DISTORTION > 0.0) {
        p_curved.x = p.x * (1.0 + (p.y * p.y) * (BARREL_DISTORTION * 0.2));
        p_curved.y = p.y * (1.0 + (p.x * p.x) * (BARREL_DISTORTION * 0.8));
        p_curved *= (1.0 - 0.1 * BARREL_DISTORTION);
    } else {
        p_curved = p;
    }

    if (abs(p_curved.x) > 0.5 || abs(p_curved.y) > 0.5) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // --- Sharp Bilinear / Anti-Moire ---
    vec2 uv = (p_curved + 0.5) / sc;
    vec2 texel = uv * TextureSize;
    vec2 texel_floored = floor(texel);
    vec2 s = fract(texel);
    
    float region = 0.5 - (hardPix * 0.05); 
    vec2 region_edge = clamp(s / (1.0 - region * 2.0) - region / (1.0 - region * 2.0), 0.0, 1.0);
    vec2 final_uv = (texel_floored + region_edge) / TextureSize;

    // 3. FETCH & COLOR (Linearize)
    vec3 color = texture2D(Texture, final_uv).rgb;
    color *= color; 
    
    // 4. SCANLINES (تعمل فقط عند الحاجة)
    if (scan_str > 0.0) {
        float dst = fract(uv.y * TextureSize.y) - 0.5;
        float scan = exp2(hardScan * dst * dst);
        color *= mix(1.0, scan, scan_str);
    }
    
    // 5. SHADOW MASK (تجاوز ذكي لو القيم محايدة)
    if (maskDark < 0.9 || maskLight > 1.1) {
        vec3 m = vec3(maskDark);
        float x_mask = mod(gl_FragCoord.x, 3.0);
        if (x_mask < 1.0) m.r = maskLight;
        else if (x_mask < 2.0) m.g = maskLight;
        else m.b = maskLight;
        color *= m;
    }
    
    // 6. TRUE BRIGHT BOOST
    color *= brightBoost;
    
    // 7. VIGNETTE
    if (VIG_STR > 0.0) {
        color *= (1.0 - dot(p_curved, p_curved) * VIG_STR);
    }

    // Final Output: Fast SRGB (sqrt)
    gl_FragColor = vec4(sqrt(max(color, 0.0)), 1.0);
}
#endif