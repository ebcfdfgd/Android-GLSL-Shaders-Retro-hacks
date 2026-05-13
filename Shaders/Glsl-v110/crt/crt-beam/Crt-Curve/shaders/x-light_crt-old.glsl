#version 110

/* 777-LITE-TURBO-V14-DYNAMIC-NO-POW
    - FEATURE: Replaced pow() with fast multiplication (Square).
    - PERFORMANCE: Optimized for 4K / High Refresh rates.
    - BEAM: Dynamic expansion still reacts to luminance.
*/

#pragma parameter BARREL_DISTORTION "Screen Curve" 0.15 0.0 1.0 0.02
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.25 1.0 2.5 0.05
#pragma parameter VIG_STR "Vignette Intensity" 0.15 0.0 2.0 0.05

// --- Dynamic Scanline Control ---
#pragma parameter SCAN_STR "Scanline Intensity" 0.40 0.0 1.0 0.05
#pragma parameter SCAN_SIZE "Scanline Size (Zoom)" 5.0 1.0 10.0 0.5
#pragma parameter SCAN_BEAM "Beam Glow (Fast React)" 1.2 0.5 3.0 0.1

// --- Advanced Mask Control ---
#pragma parameter MASK_STR "Mask Strength" 0.15 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width" 3.0 1.0 10.0 1.0

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
uniform float BARREL_DISTORTION, BRIGHT_BOOST, VIG_STR, SCAN_STR, SCAN_SIZE, SCAN_BEAM, MASK_STR, MASK_W;
#endif

void main() {
    vec2 sc = TextureSize / InputSize;
    vec2 p = (uv * sc) - 0.5;

    // 2. هندسة الكيرف (توزيع 0.2 للأفقي و 0.8 للرأسي لمنع التموج)
    float ky = BARREL_DISTORTION * 0.8; 
    vec2 p_curved;
    p_curved.x = p.x * (1.0 + (p.y * p.y) * (BARREL_DISTORTION * 0.2));
    p_curved.y = p.y * (1.0 + (p.x * p.x) * ky);
    
    // تصحيح الحجم (Overscan) لضمان ملء الشاشة ومنع ضغط البكسلات
    p_curved *= (1.0 - 0.2 * BARREL_DISTORTION);

    // 3. خدعة الـ Offset (هذا الجزء هو المسؤول عن ثبات شلال سونيك)
    vec2 texCoord = (p_curved + 0.5) / sc;
    vec2 flicker_fix = (0.5 / TextureSize) * BARREL_DISTORTION * 2.0;
    texCoord -= flicker_fix;

    // 4. فحص الحدود (بديل الـ IF لسرعة الأداء)
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float edge_mask = bounds.x * bounds.y;

    // 5. سحب العينة النهائية (عينة واحدة فقط Single Sample)
    vec3 res = texture2D(Texture, texCoord).rgb;
    res *= edge_mask; // تطبيق السواد على 

    // 3. Vignette
    res *= (1.0 - dot(p_curved, p_curved) * VIG_STR);

    // 4. DYNAMIC SCANLINES (Fast Multiplier Logic)
    if (SCAN_STR > 0.0) {
        float lum = dot(res, vec3(0.299, 0.587, 0.114));
        
        float pos_y = gl_FragCoord.y * (1.0 / SCAN_SIZE);
        float dist = abs(fract(pos_y - 0.5) - 0.5);
        
        // البديل السريع: ضرب المسافة في العرض (beam) ثم تربيعها يدوياً
        float beam_val = dist * (SCAN_BEAM + (lum * 1.5));
        float scanline = exp2(-(beam_val * beam_val)); // استخدام الضرب المباشر بدلاً من pow
        
        res *= mix(1.0, scanline, SCAN_STR);
    }

    // 5. Balanced RGB Mask
    float W = floor(MASK_W);
    float pos_x = mod(gl_FragCoord.x, W);
    
    vec3 mcol;
    float norm_x = pos_x / W;
    mcol.r = clamp(2.0 - abs(norm_x * 6.0 - 1.0), 0.6, 1.6);
    mcol.g = clamp(2.0 - abs(norm_x * 6.0 - 3.0), 0.6, 1.6);
    mcol.b = clamp(2.0 - abs(norm_x * 6.0 - 5.0), 0.6, 1.6);

    res = mix(res, res * mcol, MASK_STR);

    // 6. Final Brightness Boost
    res *= BRIGHT_BOOST;

    gl_FragColor = vec4(res, 1.0);
}
#endif