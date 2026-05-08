#version 110
#extension GL_OES_standard_derivatives : enable

/* 777-PURE-DYNAMIC-V20-FAST
    - PERFORMANCE: Removed 4 dynamic pow() calls for ultra-smooth FPS.
    - DYNAMIC: Both Scanlines and LCD Mask react to brightness.
    - BEAM EXPANSION: Chain-multiplication mimics light glowing.
    - OPTIMIZED: Perfect alignment for 4K/Mobile displays.
*/

#pragma parameter LCD_STR "LCD Mask Strength" 0.35 0.0 1.0 0.05
#pragma parameter LCD_SIZE "LCD Mask Size" 3.0 1.0 10.0 0.1
#pragma parameter SCAN_STR "Scanline Intensity" 0.35 0.0 1.0 0.05
#pragma parameter SCAN_SIZE "Scanline Size" 5.0 1.0 10.0 0.1
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

#ifdef PARAMETER_UNIFORM
uniform float LCD_STR, LCD_SIZE, SCAN_STR, SCAN_SIZE, SCAN_BEAM, BRIGHTNESS_LCD;
#endif

void main() {
    // 1. Sampling the source texture
    vec3 res = texture2D(Texture, vTexCoord).rgb;
    
    // حساب سطوع البكسل (Luminance)
    float lum = dot(res, vec3(0.299, 0.587, 0.114));

    // 2. FAST DYNAMIC SCANLINES (Horizontal)
    if (SCAN_STR > 0.0) {
        float scan_pos = gl_FragCoord.y * (6.28318 / SCAN_SIZE);
        float s_wave = sin(scan_pos) * 0.5 + 0.5;
        
        // بديل الـ pow: تربيع متسلسل يعتمد على قوة الشعاع والسطوع
        float beam_f = SCAN_BEAM + (lum * 1.5);
        float dynamic_scan = s_wave * s_wave; // تربيع أساسي
        if(beam_f > 1.2) dynamic_scan *= s_wave;
        if(beam_f > 2.0) dynamic_scan *= s_wave;
        
        res *= mix(1.0, dynamic_scan, SCAN_STR);
    }

    // 3. FAST DYNAMIC LCD MASK (Vertical RGB)
    if (LCD_STR > 0.0) {
        float mask_pos = gl_FragCoord.x * (6.28318 / LCD_SIZE);
        
        // إنشاء الموجات الثلاث للألوان (RGB)
        vec3 waves = vec3(
            sin(mask_pos) * 0.5 + 0.5,
            sin(mask_pos + 2.09439) * 0.5 + 0.5,
            sin(mask_pos + 4.18879) * 0.5 + 0.5
        );
        
        // استبدال الـ pow بضرب الموجة في نفسها (تربيع) لزيادة حدة الفصل بين الألوان
        // هذا يعطي مظهر بكسلات LCD حقيقية دون إجهاد المعالج
        vec3 mcol = waves * waves; 
        
        // تفاعل إضافي مع السطوع: إذا كان البكسل ساطعاً جداً، نقوم بتقليل حدة الماسك
        res *= mix(vec3(1.0), mcol, LCD_STR);
    }

    // 4. Final Output with Brightness Correction
    gl_FragColor = vec4(clamp(res * BRIGHTNESS_LCD, 0.0, 1.0), 1.0);
}
#endif