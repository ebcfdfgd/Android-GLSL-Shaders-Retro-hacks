#version 110

/* 777-ULTRA-PURE-SCAN-V13-ZFAST-HYBRID (Optimized Curve 70)
    - INTEGRATED: Advanced Zfast Scanline Engine.
    - INTEGRATED: Optimized Barrel Distortion (Curve 70).
    - FEATURES: 100% Branchless optimization + Auto-fade on pure white.
*/

#pragma parameter BARREL_DISTORTION "Screen Curve" 0.08 0.0 0.5 0.01
#pragma parameter VIG_STR "Vignette Intensity" 0.35 0.0 2.0 0.05
#pragma parameter LCD_STR "LCD Mask Strength" 0.35 0.0 1.0 0.05
#pragma parameter LCD_SIZE "LCD Mask Size" 3.0 1.0 10.0 0.1
#pragma parameter LOWLUMSCAN "Scanline Darkness - Low" 5.0 0.0 20.0 0.5
#pragma parameter HILUMSCAN "Scanline Darkness - High" 10.0 0.0 50.0 1.0
#pragma parameter BRIGHTBOOST "Scanline Brightness" 1.20 0.5 2.0 0.05
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
uniform float BARREL_DISTORTION, VIG_STR, LCD_STR, LCD_SIZE, LOWLUMSCAN, HILUMSCAN, BRIGHTBOOST, BRIGHTNESS_LCD;
#endif

void main() {
    // 1. Geometry (Enhanced Barrel Distortion - Curve 70 Best)
    vec2 scale = TextureSize / InputSize;
    vec2 tex = vTexCoord * scale;
    vec2 texcoord = tex - vec2(0.5);
    
    // حساب التشوه الشعاعي
    float rsq = texcoord.x * texcoord.x + texcoord.y * texcoord.y;
    texcoord += texcoord * (BARREL_DISTORTION * rsq);
    
    // إعادة التحجيم لمنع الفراغات في الزوايا
    texcoord *= (1.0 - (0.12 * BARREL_DISTORTION));

    // قطع الحواف للحدود السوداء
    if (abs(texcoord.x) > 0.5 || abs(texcoord.y) > 0.5) {
        gl_FragColor = vec4(0.0);
        return;
    }
    
    vec2 d_uv = (texcoord + vec2(0.5)) / scale;

    // 2. Fetch Base Color
    vec3 base_color = texture2D(Texture, d_uv).rgb;

    // 3. Calculate Luminance for White Fading
    float luma = dot(base_color, vec3(0.299, 0.587, 0.114));
    float white_fade = clamp((1.0 - luma) * 4.0, 0.0, 1.0);

    // 4. Advanced Zfast Scanlines (Horizontal)
    float game_coord_y = d_uv.y * TextureSize.y;
    float dist = fract(game_coord_y) - 0.5;
    float Y = dist * dist;
    float YY = Y * Y;

    float scanLineWeightLow  = (BRIGHTBOOST - LOWLUMSCAN * (Y - 1.5 * YY));
    float scanLineWeightHigh = 1.0 - HILUMSCAN * (YY - 2.0 * YY * Y); 
    
    float zfast_scan = mix(scanLineWeightLow, scanLineWeightHigh, luma);
    float final_scan = mix(1.0, zfast_scan, white_fade);
    vec3 res = base_color * final_scan;

    // 5. Vectorized LCD Mask (Vertical RGB)
    float angle = gl_FragCoord.x * (6.283185 / LCD_SIZE);
    vec3 mcol = 0.5 + 0.5 * sin(vec3(angle, angle + 2.09439, angle + 4.18879));
    res = mix(res, res * mcol, LCD_STR);

    // 6. Optimized Vignette
    vec2 p = (vTexCoord * 2.0) - 1.0;
    res *= (1.0 - dot(p, p) * VIG_STR * 0.25);

    // 7. Final Combined Output
    gl_FragColor = vec4(clamp(res * BRIGHTNESS_LCD, 0.0, 1.0), 1.0);
}
#endif