#version 110

/* 777-LITE-TURBO-V2-PERFECT-BALANCE (Backported to 110)
    - Position Fix: Brightness Boost moved to the final stage for better color retention.
    - Logic: Smooth Interpolation for balanced RGB phosphors.
*/

#pragma parameter BARREL_DISTORTION "Screen Curve" 0.15 0.0 1.0 0.02
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
#endif

void main() {
    vec2 sc = TextureSize / InputSize;
    vec2 p = (uv * sc) - 0.5;

    // 1. Simple Curve (Geometry)
    float ky = BARREL_DISTORTION * 0.8; 
    vec2 p_curved;
    p_curved.x = p.x * (1.0 + (p.y * p.y) * (BARREL_DISTORTION * 0.2));
    p_curved.y = p.y * (1.0 + (p.x * p.x) * ky);
    p_curved *= (1.0 - 0.1 * BARREL_DISTORTION);

    if (abs(p_curved.x) > 0.5 || abs(p_curved.y) > 0.5) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // 2. Sample (Pure Color)
    vec3 res = texture2D(Texture, (p_curved + 0.5) / sc).rgb;

    // 3. Vignette
    res *= (1.0 - dot(p_curved, p_curved) * VIG_STR);

    // 4. Scanlines
    {
    // ربط فيزيائي ببكسل اللعبة المنحني
    // (p_curved.y + 0.5) يحول الإحداثيات من (-0.5, 0.5) إلى (0, 1)
    float pixel_y = (p_curved.y + 0.5) * InputSize.y;
    
    // إنشاء موجة السكان لاين (خط لكل بكسل لعبة)
    float scan = sin(pixel_y * 6.283185) * 0.5 + 0.5;
    
    // عملية ضرب مباشر (بدون أوفرلاي)
    // mix(1.0, scan, SCAN_STR) تعني: 1.0 عند قوة صفر، و scan عند القوة الكاملة
    res *= mix(1.0, scan, SCAN_STR);
}

    // 5. Balanced RGB Mask
    vec3 mcol = vec3(0.0);
mcol[int(mod(gl_FragCoord.x, 3.0))] = 1.0;

// 2. اضرب النتيجة في بكسل الصورة بناءً على القوة المختارة
res *= mix(vec3(1.0), mcol, MASK_STR);

    // 6. Final Brightness Boost (Moved here)
    res *= BRIGHT_BOOST;

    gl_FragColor = vec4(res, 1.0);
}
#endif