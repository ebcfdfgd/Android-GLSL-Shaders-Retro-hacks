#version 110
#extension GL_OES_standard_derivatives : enable

/* 777-ULTRA-PURE-SCAN-V13-ZFAST-LIGHT
    - INTEGRATED: Advanced Zfast Scanline Engine (High/Low Luminance Weights).
    - FIXED: Scanline is strictly 1:1 pixel-locked with game resolution (No zoom).
    - RETAINED: LCD Mask keeps its independent 'LCD_SIZE' zoom parameter for screen scaling.
    - OPTIMIZED: Completely Branchless, auto-fade on pure white.
*/

#pragma parameter LCD_STR "LCD Mask Strength" 0.35 0.0 1.0 0.05
#pragma parameter LCD_SIZE "LCD Mask Size" 3.0 1.0 10.0 0.1
#pragma parameter LOWLUMSCAN "Scanline Darkness - Low" 5.0 0.0 20.0 0.5
#pragma parameter HILUMSCAN "Scanline Darkness - High" 10.0 0.0 50.0 1.0
#pragma parameter BRIGHTBOOST "Scanline Brightness" 1.20 0.5 2.0 0.05
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
uniform float LCD_STR, LCD_SIZE, LOWLUMSCAN, HILUMSCAN, BRIGHTBOOST, BRIGHTNESS_LCD;
#endif

void main() {
    // 1. Sampling the source texture
    vec3 base_color = texture2D(Texture, vTexCoord).rgb;

    // 2. Calculate Luminance for White Fading & Zfast Weights
    float luma = dot(base_color, vec3(0.299, 0.587, 0.114));
    
    // عامل التلاشي عند اللون الأبيض (يقترب من 0.0 عند الأبيض الصريح لمنع التشويه)
    float white_fade = clamp((1.0 - luma) * 4.0, 0.0, 1.0); 

    // 3. Advanced Zfast Scanlines (Horizontal) - Pixel-Perfect (No Zoom)
    float game_coord_y = vTexCoord.y * TextureSize.y;
    float f_y = fract(game_coord_y); 
    float dist = (f_y - 0.5);
    float Y = dist * dist;
    float YY = Y * Y;

    // حساب أوزان الإضاءة العالية والمنخفضة لمحرك Zfast
    float scanLineWeightLow  = (BRIGHTBOOST - LOWLUMSCAN * (Y - 1.5 * YY));
    float scanLineWeightHigh = 1.0 - HILUMSCAN * (YY - 2.0 * YY * Y); 
    
    // دمج الإضاءتين بناءً على سطوع المشهد لتحديد عمق الخط تلقائياً
    float zfast_scan = mix(scanLineWeightLow, scanLineWeightHigh, luma);
    
    // تطبيق الفيد النقي عند الأبيض: يختفي السكانلاين تماماً ويصبح 1.0 فوق المساحات البيضاء الساطعة
    float final_scan = mix(1.0, zfast_scan, white_fade);
    vec3 res = base_color * final_scan;

    // 4. Custom-Sized LCD Mask (Vertical RGB) - Uses gl_FragCoord & Slider for Zoom
    float mask_pos = gl_FragCoord.x * (6.283185 / LCD_SIZE);
    vec3 mcol = vec3(
        0.5 + 0.5 * sin(mask_pos),
        0.5 + 0.5 * sin(mask_pos + 2.094395),
        0.5 + 0.5 * sin(mask_pos + 4.188790)
    );
    res *= mix(vec3(1.0), mcol, LCD_STR);

    // 5. Final Output with Brightness Correction
    gl_FragColor = vec4(clamp(res * BRIGHTNESS_LCD, 0.0, 1.0), 1.0);
}
#endif