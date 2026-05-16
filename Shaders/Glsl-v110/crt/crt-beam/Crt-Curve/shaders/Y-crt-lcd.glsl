#version 110

/* 777-ULTRA-DYNAMIC-TURBO-V17-PIXEL-SYNC
    - SYNC: Scanlines now locked to TextureSize.y (Game Pixels).
    - GEOMETRY: Scanlines bend naturally with the Barrel Distortion.
    - PERFORMANCE: Vectorized RGB & Beam logic for Mobile/4K GPUs.
    - PRECISION: mediump for maximum FPS on Android/Low-end.
*/

#pragma parameter BARREL_DISTORTION "Screen Curve" 0.12 0.0 0.5 0.01
#pragma parameter VIG_STR "Vignette Intensity" 0.35 0.0 2.0 0.05
#pragma parameter LCD_STR "LCD Mask Strength" 0.35 0.0 1.0 0.05
#pragma parameter LCD_SIZE "LCD Mask Size" 3.0 1.0 10.0 0.1
#pragma parameter SCAN_STR "Scanline Intensity" 0.35 0.0 1.0 0.05
#pragma parameter SCAN_BEAM "Beam Glow (Fast React)" 1.2 0.5 3.0 0.1
#pragma parameter BRIGHTNESS_LCD "Brightness Boost" 1.30 1.0 2.5 0.05

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
uniform float BARREL_DISTORTION, VIG_STR, LCD_STR, LCD_SIZE, SCAN_STR, SCAN_BEAM, BRIGHTNESS_LCD;
#endif

void main() {
    vec2 sc = TextureSize / InputSize;
    vec2 p = (vTexCoord * sc) - 0.5;
    vec2 d_uv;

    // 1. Optimized Geometry (Vectorized)
    if (BARREL_DISTORTION > 0.0) {
        vec2 p2 = p * p;
        d_uv = p * (1.0 + p2.yx * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.9));
        // نحفظ الإحداثيات المنحنية قبل تحويلها لـ UV Sampling لإستخدامها في السكانلاين
        d_uv = (d_uv * (1.0 - 0.15 * BARREL_DISTORTION) + 0.5);
    } else {
        d_uv = vTexCoord * sc;
    }

    // Border Check (using 0.0 to 1.0 range)
    if (d_uv.x < 0.0 || d_uv.x > 1.0 || d_uv.y < 0.0 || d_uv.y > 1.0) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // 2. Fetch color (Sampling normalized UV)
    vec3 res = texture2D(Texture, d_uv / sc).rgb;

    // 3. FAST DYNAMIC SCANLINES (Pixel-Synced)
    if (SCAN_STR > 0.0) {
        float lum = dot(res, vec3(0.299, 0.587, 0.114));
        
        // الربط بالبكسل: d_uv.y هنا تمثل مكان البكسل الفعلي في اللعبة
        float pos_y = d_uv.y * TextureSize.y;
        float dist = abs(fract(pos_y - 0.5) - 0.5);
        
        float beam_calc = dist * (SCAN_BEAM + (lum * 1.5));
        float scan = exp2(-(beam_calc * beam_calc)); 
        
        res *= mix(1.0, scan, SCAN_STR);
    }

    // 4. Vectorized LCD Mask (Screen-Space)
    if (LCD_STR > 0.0) {
        float angle = gl_FragCoord.x * (6.28318 / LCD_SIZE);
        vec3 mcol = 0.5 + 0.5 * sin(vec3(angle, angle + 2.09439, angle + 4.18879));
        res *= mix(vec3(1.0), mcol, LCD_STR);
    }

    // 5. Optimized Vignette
    if (VIG_STR > 0.0) {
        res *= (1.0 - dot(p, p) * VIG_STR);
    }

    // 6. Final Combined Output
    gl_FragColor = vec4(res * BRIGHTNESS_LCD, 1.0);
}
#endif