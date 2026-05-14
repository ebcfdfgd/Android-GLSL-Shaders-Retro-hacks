#version 110

/* 777-ULTRA-PURE-SCAN-V11-TURBO
    - PERFORMANCE: Replaced divisions with inverse multipliers.
    - VECTORIZATION: Combined RGB sine calculations into a single vec3 operation.
    - PRECISION: Switched to mediump for mobile GPU efficiency.
    - GEOMETRY: Optimized Barrel math with pre-calculated vectors.
*/

#pragma parameter BARREL_DISTORTION "Screen Curve" 0.12 0.0 0.5 0.01
#pragma parameter VIG_STR "Vignette Intensity" 0.35 0.0 2.0 0.05
#pragma parameter LCD_STR "LCD Mask Strength" 0.35 0.0 1.0 0.05
#pragma parameter LCD_SIZE "LCD Mask Size" 3.0 1.0 10.0 0.1
#pragma parameter SCAN_STR "Scanline Intensity" 0.30 0.0 1.0 0.05
#pragma parameter SCAN_SIZE "Scanline Size" 2.0 1.0 10.0 0.1
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
precision mediump float; // أسرع بكثير من highp على أجهزة أندرويد
#endif

varying vec2 vTexCoord;
uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, VIG_STR, LCD_STR, LCD_SIZE, SCAN_STR, SCAN_SIZE, BRIGHTNESS_LCD;
#endif

void main() {
    vec2 sc = TextureSize / InputSize;
    vec2 p = (vTexCoord * sc) - 0.5;
    vec2 d_uv;

    // 1. Optimized Geometry
    if (BARREL_DISTORTION > 0.0) {
        vec2 p2 = p * p;
        // تقليل عدد عمليات الضرب بدمج العوامل
        d_uv = p * (1.0 + p2.yx * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.9));
        d_uv = (d_uv * (1.0 - 0.15 * BARREL_DISTORTION) + 0.5) / sc;
    } else {
        d_uv = vTexCoord;
    }

    // Border Check (Early Exit)
    if (d_uv.x < 0.0 || d_uv.x > 1.0 || d_uv.y < 0.0 || d_uv.y > 1.0) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }
    vec2 Q_p = d_uv * TextureSize; // texCoord هو المتغير اللي بيسحب الصورة
    vec2 Q_i = floor(Q_p) + 0.50;
    vec2 Q_f = Q_p - Q_i;
    vec2 Q_final = (Q_i + 4.0*Q_f*Q_f*Q_f) / TextureSize;
    // ------------------------------------
    
    // سحب العينة باستخدام الإحداثيات الجديدة Q_final
    vec3 res = texture2D(Texture, Q_final).rgb;

    // 3. Ultra-Fast Scanlines (Horizontal)
    if (SCAN_STR > 0.0) {
        // تحويل القسمة لضرب باستخدام مقلوب الحجم
        float scan = 0.5 + 0.5 * sin(gl_FragCoord.y * (6.28318 / SCAN_SIZE));
        res *= mix(1.0, scan, SCAN_STR);
    }

    // 4. Vectorized LCD Mask (Vertical RGB)
    if (LCD_STR > 0.0) {
        // حساب الزاوية مرة واحدة وتوزيعها كـ Vector
        float angle = gl_FragCoord.x * (6.28318 / LCD_SIZE);
        vec3 mcol = 0.5 + 0.5 * sin(vec3(angle, angle + 2.09439, angle + 4.18879));
        res *= mix(vec3(1.0), mcol, LCD_STR);
    }

    // 5. Optimized Vignette
    if (VIG_STR > 0.0) {
        // إعادة استخدام p المحسوب في البداية لتوفير الوقت
        res *= (1.0 - dot(p, p) * VIG_STR);
    }

    // 6. Final Combined Output
    gl_FragColor = vec4(res * BRIGHTNESS_LCD, 1.0);
}
#endif