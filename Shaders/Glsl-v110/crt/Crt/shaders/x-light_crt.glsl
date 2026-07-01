#version 110

/* 777-LITE-TURBO-V2-PERFECT-BALANCE (Backported to 110)
    - Position Fix: Brightness Boost moved to the final stage for better color retention.
    - Logic: Smooth Interpolation for balanced RGB phosphors + Curve 20 Integration.
    - Optimization: 100% Branchless Boundary Check.
*/

#pragma parameter BARREL_DISTORTION "Curve 0 Strength" 0.15 0.0 1.0 0.02
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.17 1.0 2.0 0.01
#pragma parameter VIG_STR "Vignette Intensity" 0.15 0.0 2.0 0.05

// --- Scanlines Control ---
#pragma parameter SCAN_STR "Scanline Intensity" 0.30 0.0 1.0 0.05

// --- Advanced Mask Control ---
#pragma parameter MASK_STR "Mask Strength" 0.15 0.0 1.0 0.05


#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
uniform mat4 MVPMatrix;

void main() {
    uv = TexCoord;
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, BRIGHT_BOOST, VIG_STR, SCAN_STR, MASK_STR;
#else
#define BARREL_DISTORTION 0.15
#define BRIGHT_BOOST 1.17
#define VIG_STR 0.15
#define SCAN_STR 0.30
#define MASK_STR 0.15
#endif

void main() {
    vec2 sc = TextureSize / InputSize;
    vec2 p = (uv * sc) - 0.5;

    // 1. Curve 20 Integration (Geometry - Fast r2 Barrel Distortion)
    float r2 = dot(p, p);
    vec2 p_curved = p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8));

    // فحص الحدود الرقمي الذكي (Branchless Check) لرفع الـ FPS والتخلص من الـ if
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float check = bounds.x * bounds.y;

    // 2. Sample (Pure Color)
    vec2 final_uv = (p_curved + 0.5) / sc;
vec2 Q_p = final_uv * TextureSize;
vec2 Q_i = floor(Q_p) + 0.50;
vec2 Q_f = Q_p - Q_i;
vec2 Q_final = (Q_i + 4.0*Q_f*Q_f*Q_f) / TextureSize;

vec3 res = texture2D(Texture, Q_final).rgb;
    res *= check; // تطبيق قص الحواف السوداء تلقائياً وبسرعة

    // 3. Vignette
    res *= (1.0 - dot(p_curved, p_curved) * VIG_STR);

    // 4. Scanlines
    {
        // ربط فيزيائي ببكسل اللعبة المنحني
        float pixel_y = (p_curved.y + 0.5) * InputSize.y;
        
        // إنشاء موجة السكان لاين (خط لكل بكسل لعبة)
        float scan = sin(pixel_y * 6.283185) * 0.5 + 0.5;
        
        // عملية ضرب مباشر (بدون أوفرلاي)
        res *= mix(1.0, scan, SCAN_STR);
    }

    // 5. Balanced RGB Mask
    vec3 mcol = vec3(0.0);
    mcol[int(mod(gl_FragCoord.x, 3.0))] = 1.0;

    // ضرب النتيجة في بكسل الصورة بناءً على القوة المختارة
    res *= mix(vec3(1.0), mcol, MASK_STR);

    // 6. Final Brightness Boost (Moved here)
    res *= BRIGHT_BOOST;

    gl_FragColor = vec4(res, 1.0);
}
#endif