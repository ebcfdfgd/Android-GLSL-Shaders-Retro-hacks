#version 110
#extension GL_OES_standard_derivatives : enable

/* ULTIMATE-LCD-ACCURACY-V4
    - FIXED: Grid "Huge Squares" (Lines are now resolution-independent).
    - FIXED: Thick/Thin lines (Perfect pixel alignment using screen derivatives).
    - FIXED: Green Tint (Normalized RGB subpixel weights).
    - BRIGHTNESS: Clean Linear Boost.
    - ADDED: Thickness Control for X and Y lines.
*/

#pragma parameter GRID_W "Grid Intensity X" 0.3 0.0 1.0 0.05
#pragma parameter GRID_H "Grid Intensity Y" 0.3 0.0 1.0 0.05
#pragma parameter THICK_X "Line Thickness X" 0.05 0.0 0.4 0.01
#pragma parameter THICK_Y "Line Thickness Y" 0.05 0.0 0.4 0.01
#pragma parameter SUBPIX_STR "Subpixel Strength" 0.5 0.0 1.0 0.05
#pragma parameter BRIGHTNESS_LCD "Brightness Boost" 1.2 1.0 2.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec4 TexCoord;
varying vec2 vTexCoord;
varying vec2 pix_coord;
uniform mat4 MVPMatrix;
uniform vec2 TextureSize;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord.xy;
    pix_coord = vTexCoord * TextureSize;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 vTexCoord;
varying vec2 pix_coord;
uniform sampler2D Texture;

#ifdef PARAMETER_UNIFORM
uniform float GRID_W, GRID_H, THICK_X, THICK_Y, SUBPIX_STR, BRIGHTNESS_LCD;
#endif

void main() {
    // 1. اللون الأساسي
    vec3 color = texture2D(Texture, vTexCoord).rgb;

    // 2. إحداثيات البكسل ومقدار التغير (Scale)
    vec2 pos = fract(pix_coord);
    vec2 df = fwidth(pix_coord);

    // 3. الماسك المتساوي (Grid) مع التحكم في السمك
    vec2 grid_coord = abs(pos - 0.5);
    
    // تحديد حافة الخط (0.5 - Thickness)
    float threshold_x = 0.5 - THICK_X;
    float threshold_y = 0.5 - THICK_Y;
    
    // استخدام السمك المضاف كـ Offset للـ Threshold
    float mask_x = smoothstep(threshold_x - df.x, threshold_x, grid_coord.x);
    float mask_y = smoothstep(threshold_y - df.y, threshold_y, grid_coord.y);
    
    // دمج الماسك مع التحكم في القوة (Intensity)
    float mask = 1.0 - max(mask_x * GRID_W, mask_y * GRID_H);

    // 4. الـ Subpixel المتوازن
    float x = pos.x * 3.0;
    vec3 w;
    w.r = clamp(1.0 - abs(x - 0.5), 0.0, 1.0);
    w.g = clamp(1.0 - abs(x - 1.5), 0.0, 1.0);
    w.b = clamp(1.0 - abs(x - 2.5), 0.0, 1.0);
    
    vec3 subpixel = mix(vec3(1.0), w * 1.1, SUBPIX_STR);

    // 5. النتيجة النهائية
    vec3 final = color * mask * subpixel * BRIGHTNESS_LCD;

    gl_FragColor = vec4(clamp(final, 0.0, 1.0), 1.0);
}
#endif