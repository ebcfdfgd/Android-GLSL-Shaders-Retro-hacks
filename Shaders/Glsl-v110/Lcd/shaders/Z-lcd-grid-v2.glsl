#version 110
#extension GL_OES_standard_derivatives : enable

/* 777-ULTRA-PURE-LCD-V4 (PIXEL-LOCKED)
   - FIXED: Mask follows game pixels (TextureSize) instead of screen.
   - RESULT: No shimmering, no screen-space artifacts.
   - COMPATIBILITY: Perfect for GBA/GBC handheld emulation.
*/

#pragma parameter LCD_STR "LCD Mask Strength" 0.45 0.0 1.0 0.05
#pragma parameter LCD_SIZE "LCD Mask Zoom" 1.0 1.0 10.0 0.1
#pragma parameter BRIGHTNESS_LCD "Brightness Boost" 1.35 1.0 2.5 0.05
#pragma parameter SCAN_LINE "Horizontal Scan Dim" 0.10 0.0 0.50 0.01

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec4 TexCoord;
varying vec2 vTexCoord;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord.xy;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 vTexCoord;
uniform sampler2D Texture;
uniform vec2 TextureSize;

#ifdef PARAMETER_UNIFORM
uniform float LCD_STR, LCD_SIZE, BRIGHTNESS_LCD, SCAN_LINE;
#endif

void main() {
    // 1. ربط الإحداثيات ببكسل اللعبة مباشرة (TextureSize)
    // قسمنا على LCD_SIZE عشان لو حبيت تكبّر شكل البكسل "داخلياً"
    vec2 pos = (vTexCoord * TextureSize.xy) / LCD_SIZE;

    // 2. سحب العينة (Raw Pixel)
    vec3 color = texture2D(Texture, vTexCoord).rgb;

    // 3. بناء الـ RGB Subpixels ملتحمة مع البكسل
    float angle = pos.x * 6.28318;
    vec3 mcol = vec3(
        0.5 + 0.5 * sin(angle),
        0.5 + 0.5 * sin(angle + 2.09439),
        0.5 + 0.5 * sin(angle + 4.18879)
    );

    // 4. خطوط العرض (Grid) مربوطة بطول البكسل
    float grid_y = 0.95 + SCAN_LINE * sin(pos.y * 6.28318);
    
    // دمج الماسك
    vec3 mask = mix(vec3(1.0), mcol * grid_y, LCD_STR);

    // 5. تعويض السطوع النهائي
    vec3 final_color = color * mask * (BRIGHTNESS_LCD + (LCD_STR * 0.20));

    gl_FragColor = vec4(clamp(final_color, 0.0, 1.0), 1.0);
}
#endif