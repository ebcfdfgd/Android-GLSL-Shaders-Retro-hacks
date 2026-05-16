#version 110
#extension GL_OES_standard_derivatives : enable

/* 777-PURE-DYNAMIC-V20-PIXEL-SYNC
    - SYNC: Scanlines now locked to vTexCoord.y (Game Pixels).
    - MASK: LCD pixels remain static on the screen for realism.
    - PERFORMANCE: Chain-multiplication replaces pow() for 4K/Mobile.
    - OPTIMIZED: High-performance light-reactive logic.
*/

#pragma parameter LCD_STR "LCD Mask Strength" 0.35 0.0 1.0 0.05
#pragma parameter LCD_SIZE "LCD Mask Size" 3.0 1.0 10.0 0.1
#pragma parameter SCAN_STR "Scanline Intensity" 0.35 0.0 1.0 0.05
#pragma parameter SCAN_BEAM "Beam Glow (Fast React)" 1.2 0.5 3.0 0.1
#pragma parameter BRIGHTNESS_LCD "Brightness Boost" 1.30 1.0 2.5 0.05

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
uniform vec2 TextureSize; // ضروري لربط الخطوط بحجم اللعبة

#ifdef PARAMETER_UNIFORM
uniform float LCD_STR, LCD_SIZE, SCAN_STR, SCAN_BEAM, BRIGHTNESS_LCD;
#endif

void main() {
    // 1. Sampling the source texture
    vec3 res = texture2D(Texture, vTexCoord).rgb;
    
    // حساب سطوع البكسل (Luminance)
    float lum = dot(res, vec3(0.299, 0.587, 0.114));

    // 2. PIXEL-SYNCED SCANLINES (Horizontal)
    if (SCAN_STR > 0.0) {
        // الربط بالبكسل: نستخدم vTexCoord.y مضروبة في عدد خطوط اللعبة
        float scan_pos = vTexCoord.y * TextureSize.y * 6.28318;
        
        // إزاحة الطور بمقدار 1.57 (PI/2) لتوسيط الخط الأسود بين البكسلات
        float s_wave = sin(scan_pos - 1.5708) * 0.5 + 0.5;
        
        float beam_f = SCAN_BEAM + (lum * 1.5);
        float dynamic_scan = s_wave * s_wave; // تربيع أساسي
        
        // Chain Multiplication (بديل pow)
        if(beam_f > 1.2) dynamic_scan *= s_wave;
        if(beam_f > 2.0) dynamic_scan *= s_wave;
        
        res *= mix(1.0, dynamic_scan, SCAN_STR);
    }

    // 3. FAST LCD MASK (Vertical RGB - Screen Space)
    if (LCD_STR > 0.0) {
        float mask_pos = gl_FragCoord.x * (6.28318 / LCD_SIZE);
        
        // إنشاء الموجات الثلاث للألوان (RGB)
        vec3 waves = vec3(
            sin(mask_pos) * 0.5 + 0.5,
            sin(mask_pos + 2.09439) * 0.5 + 0.5,
            sin(mask_pos + 4.18879) * 0.5 + 0.5
        );
        
        // تربيع الموجات لزيادة حدة الفصل بين ألوان الـ RGB
        vec3 mcol = waves * waves; 
        
        res *= mix(vec3(1.0), mcol, LCD_STR);
    }

    // 4. Final Output with Brightness Correction
    gl_FragColor = vec4(clamp(res * BRIGHTNESS_LCD, 0.0, 1.0), 1.0);
}
#endif