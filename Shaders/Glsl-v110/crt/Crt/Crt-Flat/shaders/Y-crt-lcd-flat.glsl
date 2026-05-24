#version 110
#extension GL_OES_standard_derivatives : enable

/* 777-ULTRA-PURE-SCAN-V12
    - FIXED: Scanline is strictly 1:1 pixel-locked with game resolution (No zoom).
    - RETAINED: LCD Mask keeps its independent 'LCD_SIZE' zoom parameter for screen scaling.
    - OPTIMIZED: Branchless approach, auto-fade on pure white.
*/

#pragma parameter LCD_STR "LCD Mask Strength" 0.35 0.0 1.0 0.05
#pragma parameter LCD_SIZE "LCD Mask Size" 3.0 1.0 10.0 0.1
#pragma parameter SCAN_STR "Scanline Intensity" 0.30 0.0 1.0 0.05
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

// RetroArch standard uniform to get game resolution
uniform vec2 TextureSize;

#ifdef PARAMETER_UNIFORM
uniform float LCD_STR, LCD_SIZE, SCAN_STR, BRIGHTNESS_LCD;
#endif

void main() {
    // 1. Sampling the source texture
    vec3 base_color = texture2D(Texture, vTexCoord).rgb;
    vec3 res = base_color;

    // 2. Check for bright/white areas to fade out the effect
    float luma = dot(base_color, vec3(0.299, 0.587, 0.114));
    
    // Dynamic strength modifiers: fades to 0.0 as color approaches pure white
    float white_fade = clamp((1.0 - luma) * 4.0, 0.0, 1.0); 
    float current_scan_str = SCAN_STR * white_fade;
    float current_lcd_str = LCD_STR * white_fade;

    // 3. Fixed 1:1 Scanlines (Horizontal) - Pixel-Perfect with Game Resolution
    float game_coord_y = vTexCoord.y * TextureSize.y;
    float scan_pos = game_coord_y * 6.283185;
    float scan = 0.5 + 0.5 * sin(scan_pos);
    res *= mix(1.0, scan, current_scan_str);

    // 4. Custom-Sized LCD Mask (Vertical RGB) - Uses gl_FragCoord & Slider for Zoom
    float mask_pos = gl_FragCoord.x * (6.283185 / LCD_SIZE);
    vec3 mcol = vec3(
        0.5 + 0.5 * sin(mask_pos),
        0.5 + 0.5 * sin(mask_pos + 2.094395),
        0.5 + 0.5 * sin(mask_pos + 4.188790)
    );
    res *= mix(vec3(1.0), mcol, current_lcd_str);

    // 5. Final Output with Brightness Correction
    gl_FragColor = vec4(clamp(res * BRIGHTNESS_LCD, 0.0, 1.0), 1.0);
}
#endif