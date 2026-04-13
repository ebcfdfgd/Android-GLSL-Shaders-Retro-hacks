#version 110

// --- LIGHT-ULTIMATE 1010 (Fixed Mask-to-File Scaling) ---
#pragma parameter BARREL_DISTORTION "Screen Curve" 0.15 0.0 0.5 0.01
#pragma parameter VIG_STR "Vignette Intensity" 0.15 0.0 1.0 0.05
#pragma parameter hardScan "Scanline Hardness" -8.0 -20.0 0.0 1.0
#pragma parameter scan_str "Scanline Intensity" 0.5 0.0 1.0 0.05
#pragma parameter br_boost "Brigt Boost" 1.3 0.0 2.5 0.05
#pragma parameter mask_opacity "Mask Strength" 0.5 0.0 1.0 0.05
#pragma parameter MASK_MODE "Mask: 0:PNG1, 1:PNG2, 2:Dual" 0.0 0.0 2.0 1.0
#pragma parameter LUTWidth1 "PNG1 Width" 3.0 1.0 1024.0 1.0
#pragma parameter LUTHeight1 "PNG1 Height" 1.0 1.0 1024.0 1.0
#pragma parameter LUTWidth2 "PNG2 Width" 6.0 1.0 1024.0 1.0
#pragma parameter LUTHeight2 "PNG2 Height" 4.0 1.0 1024.0 1.0

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

varying vec2 vTexCoord;
uniform sampler2D Texture;
uniform sampler2D shadowMaskSampler;  // PNG1
uniform sampler2D shadowMaskSampler1; // PNG2
uniform vec2 TextureSize;
uniform vec2 InputSize;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, VIG_STR, hardScan, scan_str, mask_opacity, br_boost, MASK_MODE;
uniform float LUTWidth1, LUTHeight1, LUTWidth2, LUTHeight2;
#else
#define BARREL_DISTORTION 0.12
#define VIG_STR 0.15
#define hardScan -8.0
#define scan_str 0.70
#define mask_opacity 0.3
#define br_boost 1.3
#define MASK_MODE 0.0
#define LUTWidth1 6.0
#define LUTHeight1 4.0
#define LUTWidth2 3.0
#define LUTHeight2 3.0
#endif

void main() {
    vec2 sc = TextureSize / InputSize;
    vec2 p = (vTexCoord * sc) - 0.5;
    vec2 p_curved;

    // انحناء الشاشة
    if (BARREL_DISTORTION > 0.0) {
        p_curved.x = p.x * (1.0 + (p.y * p.y) * (BARREL_DISTORTION * 0.2));
        p_curved.y = p.y * (1.0 + (p.x * p.x) * (BARREL_DISTORTION * 0.8));
        p_curved *= (1.0 - 0.1 * BARREL_DISTORTION);
    } else {
        p_curved = p;
    }

    // قص الزوائد
    if (abs(p_curved.x) > 0.5 || abs(p_curved.y) > 0.5) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    vec2 uv = (p_curved + 0.5) / sc;
    vec3 col = texture2D(Texture, uv).rgb;
    col *= col; 

    // الـ Scanlines
    if (scan_str > 0.0) {
        float dst = fract(uv.y * TextureSize.y) - 0.5;
        float scan = exp2(hardScan * dst * dst);
        col *= mix(1.0, scan, scan_str);
    }

    // --- التعديل الجديد: ربط إحداثيات الماسك بأبعاد الملف ---
    // بنستخدم gl_FragCoord ونقسم على الباراميتر عشان الـ 1:1 تايليج
    vec2 mCoord1 = gl_FragCoord.xy * vec2(1.0 / LUTWidth1, 1.0 / LUTHeight1);
    vec2 mCoord2 = gl_FragCoord.xy * vec2(1.0 / LUTWidth2, 1.0 / LUTHeight2);

    vec3 final_mask = vec3(1.0);

    if (MASK_MODE < 0.5) {
        final_mask = texture2D(shadowMaskSampler, fract(mCoord1)).rgb;
    } 
    else if (MASK_MODE < 1.5) {
        final_mask = texture2D(shadowMaskSampler1, fract(mCoord2)).rgb;
    } 
    else {
        vec3 m1 = texture2D(shadowMaskSampler, fract(mCoord1)).rgb;
        vec3 m2 = texture2D(shadowMaskSampler1, fract(mCoord2)).rgb;
        final_mask = m1 * m2;
    }
    
    col *= mix(vec3(1.0), final_mask, mask_opacity);

    if (VIG_STR > 0.0) {
        col *= (1.0 - dot(p_curved, p_curved) * VIG_STR);
    }
    col *= br_boost;

    gl_FragColor = vec4(sqrt(max(col, 0.0)), 1.0);
}
#endif