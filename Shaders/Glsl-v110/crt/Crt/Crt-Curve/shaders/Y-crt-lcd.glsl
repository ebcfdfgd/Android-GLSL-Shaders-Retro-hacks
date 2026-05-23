#version 110

/* 777-ULTRA-PURE-SCAN-V12-TURBO
    - OPTIMIZED: Completely Branchless (Zero dynamic 'if' statements for extreme GPU performance).
    - FIXED: Scanline is strictly 1:1 pixel-locked with game resolution (No zoom) and follows barrel distortion.
    - RETAINED: LCD Mask keeps its independent 'LCD_SIZE' parameter for viewport grid scaling.
    - FEATURE: Scanlines automatically fade out to 0.0 on pure white colors.
*/

#pragma parameter BARREL_DISTORTION "Screen Curve" 0.12 0.0 0.5 0.01
#pragma parameter VIG_STR "Vignette Intensity" 0.35 0.0 2.0 0.05
#pragma parameter LCD_STR "LCD Mask Strength" 0.35 0.0 1.0 0.05
#pragma parameter LCD_SIZE "LCD Mask Size" 3.0 1.0 10.0 0.1
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
precision mediump float;
#endif

varying vec2 vTexCoord;
uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, VIG_STR, LCD_STR, LCD_SIZE, SCAN_STR, BRIGHTNESS_LCD;
#endif

void main() {
    vec2 sc = TextureSize / InputSize;
    vec2 p = (vTexCoord * sc) - 0.5;
    
    // 1. Optimized Geometry (Branchless Barrel)
    vec2 p2 = p * p;
    vec2 d_uv_barrel = p * (1.0 + p2.yx * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.9));
    d_uv_barrel = (d_uv_barrel * (1.0 - 0.15 * BARREL_DISTORTION) + 0.5) / sc;
    
    // Smoothly mix between original UV and Barrel UV based on BARREL_DISTORTION strength
    vec2 d_uv = mix(vTexCoord, d_uv_barrel, step(0.001, BARREL_DISTORTION));

    // 2. Fetch color
    vec3 base_color = texture2D(Texture, d_uv).rgb;

    // 3. Dynamic Fade on White Check
    float luma = dot(base_color, vec3(0.299, 0.587, 0.114));
    float white_fade = clamp((1.0 - luma) * 4.0, 0.0, 1.0);
    float current_scan_str = SCAN_STR * white_fade;

    // 4. Ultra-Fast Game-Synced Scanlines (Horizontal) - Pixel-Perfect (No Zoom)
    float game_coord_y = d_uv.y * TextureSize.y;
    float scan = 0.5 + 0.5 * sin(game_coord_y * 6.283185);
    vec3 res = mix(base_color, base_color * scan, current_scan_str);

    // 5. Vectorized LCD Mask (Vertical RGB) - Uses Viewport Pixels & LCD_SIZE
    float angle = gl_FragCoord.x * (6.283185 / LCD_SIZE);
    vec3 mcol = 0.5 + 0.5 * sin(vec3(angle, angle + 2.09439, angle + 4.18879));
    res = mix(res, res * mcol, LCD_STR);

    // 6. Optimized Vignette (Branchless)
    res *= (1.0 - dot(p, p) * VIG_STR);

    // 7. Branchless Border Check (Masks out coordinates outside 0.0 - 1.0)
    vec2 border = step(vec2(0.0), d_uv) * step(d_uv, vec2(1.0));
    res *= border.x * border.y;

    // 8. Final Combined Output
    gl_FragColor = vec4(res * BRIGHTNESS_LCD, 1.0);
}
#endif