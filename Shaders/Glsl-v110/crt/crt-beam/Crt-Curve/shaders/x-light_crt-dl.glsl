#version 110

/* 777-LITE-TURBO-V14-NO-POW
    - OPTIMIZATION: Replaced pow() with direct multiplication (Fast 4K).
    - DYNAMIC: Scanline thickness still reacts to pixel brightness.
    - PERFORMANCE: Ultra-lightweight logic for high-refresh screens.
*/

#pragma parameter BARREL_DISTORTION "Screen Curve" 0.15 0.0 1.0 0.02
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.30 1.0 2.5 0.05
#pragma parameter VIG_STR "Vignette Intensity" 0.35 0.0 2.0 0.05

// --- Dynamic Scanline Control ---
#pragma parameter SCAN_STR "Scanline Intensity" 0.40 0.0 1.0 0.05
#pragma parameter SCAN_SIZE "Scanline Size (Zoom)" 5.0 1.0 10.0 0.5
#pragma parameter SCAN_BEAM "Beam Width (Fast React)" 1.5 0.5 3.0 0.1

// --- Mask Parameters ---
#pragma parameter MASK_DARK "Mask Dark Level" 0.5 0.0 1.0 0.05
#pragma parameter MASK_LIGHT "Mask Light Level" 1.5 0.0 2.0 0.05
#pragma parameter MASK_W "Mask Width (3=RGB)" 3.0 1.0 6.0 1.0

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
precision lowp float;
#endif

varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, BRIGHT_BOOST, VIG_STR, SCAN_STR, SCAN_SIZE, SCAN_BEAM, MASK_DARK, MASK_LIGHT, MASK_W;
#endif

void main() {
    vec2 sc = TextureSize / InputSize;
    vec2 p = (uv * sc) - 0.5;
    vec2 p_curved;
    vec2 p2 = p * p;

    // 1. Geometry
    if (BARREL_DISTORTION > 0.0) {
        p_curved = p * (1.0 + vec2(p2.y * (BARREL_DISTORTION * 0.2), p2.x * (BARREL_DISTORTION * 0.8)));
        p_curved *= (1.0 - 0.1 * BARREL_DISTORTION);
    } else {
        p_curved = p;
    }

    if (abs(p_curved.x) > 0.5 || abs(p_curved.y) > 0.5) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // 2. Sampling
    vec3 res = texture2D(Texture, (p_curved + 0.5) / sc).rgb;

    // 3. Vignette
    if (VIG_STR > 0.0) {
        res *= (1.0 - clamp(p2.x * p2.y * 15.0 * VIG_STR, 0.0, 1.0));
    }

    // 4. FAST DYNAMIC SCANLINES (No Pow Version)
    if (SCAN_STR > 0.0) {
        float lum = dot(res, vec3(0.299, 0.587, 0.114));
        
        float pos_y = gl_FragCoord.y * (1.0 / SCAN_SIZE);
        float dist = abs(fract(pos_y - 0.5) - 0.5);
        
        // السحر البديل: نستخدم الضرب المباشر بدلاً من pow
        // dist * beam يعطينا النعومة، والسطوع يقلل التأثير
        float beam = SCAN_BEAM + lum * 1.5;
        float v = dist * beam;
        float scan = exp2(-v * v); // هنا التغيير: v * v بدلاً من pow
        
        res *= mix(1.0, scan, SCAN_STR);
    }

    // 5. TRUE RGB MASK
    float pos_x = mod(gl_FragCoord.x, MASK_W) / MASK_W;
    vec3 mcol = clamp(2.0 - abs(pos_x * 6.0 - vec3(1.0, 3.0, 5.0)), MASK_DARK, MASK_LIGHT);
    res *= mcol;

    // 6. FINAL OUTPUT
    gl_FragColor = vec4(res * BRIGHT_BOOST, 1.0);
}
#endif