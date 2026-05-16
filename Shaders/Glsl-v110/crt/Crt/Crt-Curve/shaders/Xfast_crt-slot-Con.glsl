#version 110

/* 777-TURBO-ZFAST-PURE-RGB
    - CONVERGENCE: Fixed Phosphor Beam Convergence from Simple Shader (CONV_X / CONV_Y).
    - SPEED: 100% Pure Branchless. No 'if' conditions, no int, no performance drag.
    - OPTIMIZED MASK: Replaced loops and arrays with clean floating-point wave scaling.
*/

#pragma parameter CONV_X "Home TV Convergence X" 0.35 -2.0 2.0 0.05
#pragma parameter CONV_Y "Home TV Convergence Y" 0.15 -2.0 2.0 0.05
#pragma parameter BARREL_DISTORTION "Screen Curve" 0.08 0.0 0.50 0.01
#pragma parameter LOWLUMSCAN "Scanline Darkness - Low" 4.5 0.0 15.0 0.5
#pragma parameter HILUMSCAN "Scanline Darkness - High" 12.0 0.0 50.0 1.0
#pragma parameter BRIGHTBOOST "Brightness Boost" 1.25 0.5 2.0 0.05
#pragma parameter MASK_STR "Mask Intensity" 0.45 0.0 1.0 0.05
#pragma parameter SCAN_FADE_POINT "Scanline Fade Cutoff" 0.85 0.5 1.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
uniform mat4 MVPMatrix;

void main() {
    uv = TexCoord;
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, LOWLUMSCAN, HILUMSCAN, BRIGHTBOOST, MASK_STR, SCAN_FADE_POINT, CONV_X, CONV_Y;
#endif

void main() {
    // 1. إحداثيات الكيرف السريعة
    vec2 sc = TextureSize / InputSize;
    vec2 p = (uv * sc) - 0.5;

    float ky = BARREL_DISTORTION * 0.8; 
    vec2 p_curved;
    p_curved.x = p.x * (1.0 + (p.y * p.y) * (BARREL_DISTORTION * 0.2));
    p_curved.y = p.y * (1.0 + (p.x * p.x) * ky);
    p_curved *= (1.0 - 0.12 * BARREL_DISTORTION);

    vec2 texCoord = (p_curved + 0.5) / sc;
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float edge_mask = bounds.x * bounds.y;

    // 2. إزاحة التقارب الثابتة (Fixed Convergence From Simple Shader)
    vec2 c_offset = vec2(CONV_X, CONV_Y) / TextureSize;
    
    // سحب القنوات الثلاثة منفصلة بناءً على الإزاحة الثابتة المحددة
    vec3 res;
    res.r = texture2D(Texture, texCoord + c_offset).r;
    res.g = texture2D(Texture, texCoord).g;
    res.b = texture2D(Texture, texCoord - c_offset).b;
    res *= edge_mask;

    // 3. سكان لاين Zfast الصافي (Pixel-Sync)
    float pos_y = texCoord.y * TextureSize.y;
    float f_y = fract(pos_y); 
    float dist = f_y - 0.5;
    float Y = dist * dist;
    float YY = Y * Y;
    float scanWeightL = (BRIGHTBOOST - LOWLUMSCAN * (Y - 1.5 * YY));

    // 4. أسرع معادلة تقارب خطي للـ Slot Mask
    float row_toggle = step(0.5, fract(gl_FragCoord.y * 0.5));
    float col_coord = fract((gl_FragCoord.x - (row_toggle * 3.0)) * 0.166666); // 1.0 / 6.0
    float x_pixel = col_coord * 6.0;

    vec3 mcol = vec3(
        step(0.0, x_pixel) * step(x_pixel, 1.0),
        step(1.0, x_pixel) * step(x_pixel, 2.0),
        step(2.0, x_pixel) * step(x_pixel, 3.0)
    ) * 2.0;

    vec3 mask_rgb = mix(vec3(1.0), mcol, MASK_STR);

    // 5. التلاشي الخطي النفاث بديل smoothstep
    float luma = dot(res, vec3(0.299, 0.587, 0.114));
    float fade_factor = clamp((luma - 0.1) / (SCAN_FADE_POINT - 0.1), 0.0, 1.0);
    float final_scan = mix(scanWeightL, 1.0, fade_factor);

    // دمج مصفوفات مخرجات الفسفور والسكان لاين والماسك خطياً
    vec3 final_rgb = res * final_scan * mask_rgb;

    gl_FragColor = vec4(final_rgb, 1.0);
}
#endif