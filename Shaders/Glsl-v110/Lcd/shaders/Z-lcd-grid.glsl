#version 110
#extension GL_OES_standard_derivatives : enable

/* 777-ULTRA-PURE-LCD-V2
    - CLEANED: Removed G_STR for direct RGB logic.
    - OPTIMIZED: Unified sine-wave calculation.
    - RESULT: Lighter and faster execution.
*/

#pragma parameter LCD_STR "LCD Mask Strength" 0.35 0.0 1.0 0.05
#pragma parameter LCD_SIZE "LCD Mask Size" 6.75 1.0 10.0 0.05
#pragma parameter BRIGHTNESS_LCD "Brightness Boost" 1.25 1.0 2.5 0.05

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
uniform float LCD_STR, LCD_SIZE, BRIGHTNESS_LCD;
#endif

void main() {
    // 1. Standard Coordinates
    vec2 uv = vTexCoord;

    // 2. Sampling
    vec3 color = texture2D(Texture, uv).rgb;

    // 3. Smart LCD Mask (Balanced RGB)
    vec2 pos = gl_FragCoord.xy / LCD_SIZE;
    
    // معادلة موحدة للألوان الثلاثة بدون تمييز للأخضر
    vec3 mcol = vec3(
        0.5 + 0.5 * sin(pos.x * 6.28318),
        0.5 + 0.5 * sin(pos.x * 6.28318 + 2.09439),
        0.5 + 0.5 * sin(pos.x * 6.28318 + 4.18879)
    );

    // تطبيق الماسك والتظليل الأفقي في خطوة واحدة
    vec3 mask = mix(vec3(1.0), mcol * (0.95 + 0.05 * sin(pos.y * 6.28318)), LCD_STR);

    // 4. Final Output
    gl_FragColor = vec4(clamp(color * mask * BRIGHTNESS_LCD, 0.0, 1.0), 1.0);
}
#endif