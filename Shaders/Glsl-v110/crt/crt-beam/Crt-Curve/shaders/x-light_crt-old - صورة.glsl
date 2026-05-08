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

    // 1. Geometry (Screen Curve)
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
vec3 R = vec3(1.0, 0.0, 0.0), G = vec3(0.0, 1.0, 0.0), B = vec3(0.0, 0.0, 1.0), K = vec3(0.0);
    
    int c = int(mod(gl_FragCoord.x, 6.0)); // عمود من 6 بكسلات
    int r = int(mod(gl_FragCoord.y, 2.0)); // صف من بكسلين
    
    vec3 mcol;
    if (r == 0) {
        // السطر الأول: أحمر، أخضر، أزرق، أسود، أسود، أسود
        mcol = (c == 0) ? R : (c == 1) ? G : (c == 2) ? B : K;
    } else {
        // السطر الثاني: أسود، أسود، أسود، أحمر، أخضر، أزرق
        mcol = (c == 3) ? R : (c == 4) ? G : (c == 5) ? B : K;
    }

    res = mix(res, res * mcol, MASK_STR);

    // 6. Final Brightness Boost
    res *= BRIGHT_BOOST;

    gl_FragColor = vec4(res, 1.0);
}
#endif