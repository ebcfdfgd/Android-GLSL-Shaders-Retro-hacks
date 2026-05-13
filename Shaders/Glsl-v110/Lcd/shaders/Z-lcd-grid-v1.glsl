#version 110
#extension GL_OES_standard_derivatives : enable

/* 777-ULTRA-PURE-LCD-V6 (SCREEN-SOLID)
    - FIXED: Mask follows screen pixels (gl_FragCoord) to prevent Moiré.
    - STYLE: Solid RGB blocks for sharp micro-LCD look.
    - RESULT: Clean, stable, and wave-free mask.
*/

#pragma parameter LCD_STR "LCD Mask Strength" 0.45 0.0 1.0 0.05
#pragma parameter LCD_SIZE "LCD Mask Zoom" 3.0 3.0 9.0 3.0
#pragma parameter BRIGHTNESS_LCD "Brightness Boost" 1.1 1.0 2.5 0.05
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

#ifdef PARAMETER_UNIFORM
uniform float LCD_STR, LCD_SIZE, BRIGHTNESS_LCD, SCAN_LINE;
#endif

void main() {
    // 1. الربط ببكسل الشاشة (gl_FragCoord) لمنع التموج
    vec2 pos = gl_FragCoord.xy / LCD_SIZE;

    // 2. سحب اللون الأصلي
    vec3 color = texture2D(Texture, vTexCoord).rgb;

    // 3. بناء الألوان الصريحة (Solid RGB)
    // التقسيم هنا بكسل ببيكسل على الشاشة لضمان النظافة
    float x_mod = mod(pos.x, 1.0);
    vec3 mcol;
    
    // أعمدة ألوان صريحة وقاطعة
    mcol.r = step(0.0, x_mod) * step(x_mod, 0.333);
    mcol.g = step(0.333, x_mod) * step(x_mod, 0.666);
    mcol.b = step(0.666, x_mod) * step(x_mod, 1.0);

    // 4. شبكة أفقية صريحة (Scanlines)
    float y_mod = mod(pos.y, 1.0);
    float grid_y = (y_mod > 0.15) ? 1.0 : (1.0 - SCAN_LINE);
    
    // دمج الماسك
    vec3 mask = mix(vec3(1.0), mcol * grid_y, LCD_STR);

    // 5. السطوع النهائي (Auto-Compensation)
    vec3 final_color = color * mask * (BRIGHTNESS_LCD + (LCD_STR * 0.35));

    gl_FragColor = vec4(clamp(final_color, 0.0, 1.0), 1.0);
}
#endif