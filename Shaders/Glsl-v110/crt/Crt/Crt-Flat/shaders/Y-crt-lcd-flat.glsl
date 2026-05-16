#version 110
#extension GL_OES_standard_derivatives : enable

/* 777-ULTRA-PURE-SCAN-V8
    - SEPARATED: Independent sliders for Scanline and LCD sizes.
    - LOGIC: Classic Pure Multiply for both effects.
    - PERFORMANCE: Optimized trig calculations.
*/

#pragma parameter LCD_STR "LCD Mask Strength" 0.35 0.0 1.0 0.05
#pragma parameter LCD_SIZE "LCD Mask Size" 3.0 1.0 10.0 0.1
#pragma parameter SCAN_STR "Scanline Intensity" 0.30 0.0 1.0 0.05
#pragma parameter SCAN_SIZE "Scanline Size" 2.0 1.0 10.0 0.1
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

#ifdef PARAMETER_UNIFORM
uniform float LCD_STR, LCD_SIZE, SCAN_STR, SCAN_SIZE, BRIGHTNESS_LCD;
#endif

void main() {
    // 1. Sampling the source texture
    vec3 res = texture2D(Texture, vTexCoord).rgb;

    // 2. Independent Scanlines (Horizontal)
    if (SCAN_STR > 0.0) {
        // حساب التردد بناءً على SCAN_SIZE المنفصل
        float scan_pos = gl_FragCoord.y * (6.28318 / SCAN_SIZE);
        float scan = 0.5 + 0.5 * sin(scan_pos);
        res *= mix(1.0, scan, SCAN_STR);
    }

    // 3. Independent LCD Mask (Vertical RGB)
    if (LCD_STR > 0.0) {
        // حساب التردد بناءً على LCD_SIZE المنفصل
        float mask_pos = gl_FragCoord.x * (6.28318 / LCD_SIZE);
        vec3 mcol = vec3(
            0.5 + 0.5 * sin(mask_pos),
            0.5 + 0.5 * sin(mask_pos + 2.09439),
            0.5 + 0.5 * sin(mask_pos + 4.18879)
        );
        res *= mix(vec3(1.0), mcol, LCD_STR);
    }

    // 4. Final Output with Brightness Correction
    gl_FragColor = vec4(clamp(res * BRIGHTNESS_LCD, 0.0, 1.0), 1.0);
}
#endif