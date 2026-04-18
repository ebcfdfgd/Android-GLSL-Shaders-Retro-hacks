#version 110

/* ZFAST-7070-ULTIMATE-DYNAMIC-SCAN
    - FIXED: Scanline Moire using Screen-Space coordinates.
    - DYNAMIC: Scanlines react to brightness like original ZFast.
    - CURVE: Original 7070 Full Equation.
    - BLOOM: Zero-Sample Ghost Bloom.
*/

#pragma parameter BARREL_DISTORTION "Screen Curve" 0.15 0.0 1.0 0.01
#pragma parameter VIG_AMT "Vignette" 0.15 0.0 1.0 0.01
#pragma parameter BLOOM_STR "Bloom Strength" 0.35 0.0 1.0 0.05
#pragma parameter BLURSCALEX "Sharpness X-Axis" 0.30 0.0 2.0 0.05
#pragma parameter LOWLUMSCAN "Scanline Darkness" 0.40 0.0 1.0 0.05
#pragma parameter BRIGHT_B "Brightness Boost" 1.25 0.5 2.5 0.05
#pragma parameter MASK_STR "RGB Mask Strength" 0.15 0.0 1.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord, vInvSc, vBaseP;
uniform mat4 MVPMatrix;
uniform vec2 TextureSize, InputSize;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord;
    vec2 sc = TextureSize / InputSize;
    vInvSc = 1.0 / sc;
    vBaseP = (TexCoord * sc) - 0.5;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 vTexCoord, vInvSc, vBaseP;
uniform sampler2D Texture;
uniform vec2 TextureSize, OutputSize;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, VIG_AMT, BLOOM_STR, BLURSCALEX, LOWLUMSCAN, BRIGHT_B, MASK_STR;
#endif

vec2 curve7070(vec2 p) {
    p *= 1.031; 
    p.x *= 1.0 + (p.y * p.y) * BARREL_DISTORTION * 0.2;
    p.y *= 1.0 + (p.x * p.x) * BARREL_DISTORTION * 0.5;
    return p;
}

void main() {
    // 1. حساب الكيرف الأصلي
    vec2 p = curve7070(vBaseP);

    if (abs(p.x) > 0.5 || abs(p.y) > 0.5) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }
    
    vec2 final_uv = (p + 0.5) * vInvSc;

    // 2. سكيل Quilez للبكسل
    vec2 pos = final_uv * TextureSize;
    vec2 i = floor(pos) + 0.5;
    vec2 f = pos - i;
    vec2 p_scaled = (i + 4.0 * f * f * f) / TextureSize;
    p_scaled.x = mix(p_scaled.x, final_uv.x, BLURSCALEX);

    vec3 col = texture2D(Texture, p_scaled).rgb;

    // 3. البلوم الصفري
    col += col * col * (BLOOM_STR * 1.5);

    // 4. الحل النهائي للتموج مع "ديناميكية" zfast
    float scan_pos = vTexCoord.y * TextureSize.y;
    float scan_line = abs(sin(scan_pos * 3.14159265));
    
    // حساب السطوع لجعل السكان لاين يتفاعل مع الضوء
    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    float dynamic_low = LOWLUMSCAN * (1.1 - lum * 0.6); 
    
    float scan_weight = mix(1.0, (1.0 - dynamic_low), pow(scan_line, 2.0));
    
    col *= scan_weight;
    col *= BRIGHT_B;

    // 5. الفانيت
    if (VIG_AMT > 0.0) {
        col *= (1.0 - dot(p, p) * VIG_AMT * 3.0);
    }

    // 6. الماسك
    if (MASK_STR > 0.0) {
        float m = fract(gl_FragCoord.x * 0.333333);
        vec3 m_mask = (m < 0.333333) ? vec3(1.15, 0.85, 0.85) : 
                      (m < 0.666666) ? vec3(0.85, 1.15, 0.85) : vec3(0.85, 0.85, 1.15);
        col = mix(col, col * m_mask, MASK_STR);
    }

    gl_FragColor = vec4(col, 1.0);
}
#endif