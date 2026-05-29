#version 110

/* 777-ULTRA-PURE-LOTTES-SCAN-V13-TURBO (Optimized Curve 70)
    - OPTIMIZED: Completely Branchless.
    - INTEGRATED: Barrel Distortion (Curve 70 Logic).
    - FEATURE: Lottes Scanlines + White-Fade + LCD Mask.
*/

#pragma parameter BARREL_DISTORTION "Screen Curve" 0.08 0.0 0.5 0.01
#pragma parameter VIG_STR "Vignette Intensity" 0.35 0.0 2.0 0.05
#pragma parameter LCD_STR "LCD Mask Strength" 0.35 0.0 1.0 0.05
#pragma parameter LCD_SIZE "LCD Mask Size" 3.0 1.0 10.0 0.1
#pragma parameter hardScan "Lottes Scan Hardness" -8.0 -20.0 0.0 1.0
#pragma parameter SCAN_STR "Scanline Intensity" 0.30 0.0 1.0 0.05
#pragma parameter BRIGHTNESS_LCD "Brightness Boost" 1.25 1.0 2.5 0.05

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
uniform vec2 TextureSize, InputSize;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, VIG_STR, LCD_STR, LCD_SIZE, hardScan, SCAN_STR, BRIGHTNESS_LCD;
#endif

void main() {
    // 1. Optimized Geometry (Curve 70 Barrel Distortion)
    vec2 scale = TextureSize / InputSize;
    vec2 tex = vTexCoord * scale;
    vec2 texcoord = tex - vec2(0.5);
    
    // حساب التشوه الشعاعي
    float rsq = texcoord.x * texcoord.x + texcoord.y * texcoord.y;
    texcoord += texcoord * (BARREL_DISTORTION * rsq);
    
    // إعادة التحجيم لمنع الفراغات في الزوايا
    texcoord *= (1.0 - (0.12 * BARREL_DISTORTION));
    vec2 d_uv = (texcoord + vec2(0.5)) / scale;

    // 2. Fetch color
    vec3 base_color = texture2D(Texture, d_uv).rgb;

    // 3. Dynamic Fade on White Check
    float luma = dot(base_color, vec3(0.299, 0.587, 0.114));
    float white_fade = clamp((1.0 - luma) * 4.0, 0.0, 1.0);
    float current_scan_str = SCAN_STR * white_fade;

    // 4. LOTTES SCANLINES - Pixel-Perfect & Sharp
    float dst = fract(d_uv.y * TextureSize.y) - 0.5;
    float scanline = exp2(hardScan * dst * dst);
    vec3 res = mix(base_color, base_color * scanline, current_scan_str);

    // 5. Vectorized LCD Mask (Vertical RGB)
    float angle = gl_FragCoord.x * (6.283185 / LCD_SIZE);
    vec3 mcol = 0.5 + 0.5 * sin(vec3(angle, angle + 2.09439, angle + 4.18879));
    res = mix(res, res * mcol, LCD_STR);

    // 6. Optimized Vignette (Branchless)
    vec2 p = (vTexCoord * 2.0) - 1.0;
    res *= (1.0 - dot(p, p) * VIG_STR * 0.25);

    // 7. Branchless Border Check
    vec2 border = step(vec2(0.0), d_uv) * step(d_uv, vec2(1.0));
    res *= border.x * border.y;

    // 8. Final Combined Output
    gl_FragColor = vec4(res * BRIGHTNESS_LCD, 1.0);
}
#endif