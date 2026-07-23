/* =====================================================
   PURE MATH CRT - ULTRA LIGHTWEIGHT v4.1 (Fixed & Anti-Moiré)
   Optimized: Clamping logic added for stability
   Integrated with Smooth Texture Interpolation
===================================================== */
#version 110

// --- PARAMETERS ---
#pragma parameter CURVATURE "CRT Curvature 1:1" 0.15 0.0 1.0 0.01
#pragma parameter VIG_STRENGTH "Vignette Strength" 0.5 0.0 2.0 0.1
#pragma parameter BRIGHTNESS "Brightness Boost" 1.4 1.0 3.0 0.02
#pragma parameter GAMMA "Gamma Curve Depth" 0.4 0.0 2.0 0.05
#pragma parameter SCAN_LINES "Scanline Count" 1080.0 240.0 1440.0 10.0
#pragma parameter SCAN_FADE "Scanline Fade on Brights" 0.8 0.0 1.0 0.05
#pragma parameter MASK_SIZE "Mask Triads Count" 640.0 320.0 1080.0 10.0
#pragma parameter MASK_STRENGTH "Mask Darkness" 0.7 0.0 1.0 0.05

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
precision highp float;
varying vec2 uv;
uniform sampler2D Texture;

uniform vec2 TextureSize;
uniform vec2 InputSize;

uniform float CURVATURE;
uniform float VIG_STRENGTH;
uniform float BRIGHTNESS;
uniform float GAMMA;
uniform float SCAN_LINES;
uniform float SCAN_FADE;
uniform float MASK_SIZE;
uniform float MASK_STRENGTH;

void main() {
    // 1. PERFECT CENTERED CURVATURE
    vec2 sc = TextureSize / InputSize;
    vec2 p = (uv * sc) - 0.5; 
    
    float r2 = (p.x * p.x) + (p.y * p.y);
    vec2 p_curved = p * (1.0 + r2 * CURVATURE * 2.0);
    p_curved = p_curved / (1.0 + CURVATURE * 0.6);

    vec2 warped_uv = (p_curved + 0.5) / sc;
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float edge_mask = bounds.x * bounds.y;

    // --- SMOOTH TEXTURE FETCH (Interpolation) ---
    vec2 Q_p = warped_uv * TextureSize;
    vec2 Q_i = floor(Q_p) + 0.50;
    vec2 Q_f = Q_p - Q_i;
    vec2 Q_final = (Q_i + 4.0*Q_f*Q_f*Q_f) / TextureSize;
    vec3 res = texture2D(Texture, Q_final).rgb;

    // Vignette
    float vignette = 1.0 - (r2 * VIG_STRENGTH * 2.0);
    res = res * vignette;

    // Apply Brightness
    res = res * BRIGHTNESS;

    // 2. SCANLINE BEAM & FADE (Anti-Moiré Clamped)
    float y_pos = warped_uv.y * SCAN_LINES;
    float scan_phase = fract(y_pos);
    
    // Smooth calculation with clamp to prevent black-flicker (Moiré)
    float scan_beam = 4.0 * scan_phase * (1.0 - scan_phase);
    scan_beam = clamp(scan_beam, 0.25, 1.0); 
    
    float luma = (res.r + res.g + res.b) * 0.333;
    scan_beam = scan_beam + (1.0 - scan_beam) * luma * SCAN_FADE;
    res = res * scan_beam;

    // 3. SONY TRINITRON MASK (Anti-Moiré Clamped)
    float x_pos = warped_uv.x * MASK_SIZE;
    
    // Clamping the mask phases to keep values stable and eliminate vibration
    vec3 mask;
    mask.r = clamp(4.0 * fract(x_pos) * (1.0 - fract(x_pos)), 0.3, 1.0);
    mask.g = clamp(4.0 * fract(x_pos + 0.333) * (1.0 - fract(x_pos + 0.333)), 0.3, 1.0);
    mask.b = clamp(4.0 * fract(x_pos + 0.666) * (1.0 - fract(x_pos + 0.666)), 0.3, 1.0);
    
    mask = mask * MASK_STRENGTH + (1.0 - MASK_STRENGTH); 
    res = res * mask;

    // 4. GAMMA S-CURVE
    vec3 s_curve = res * res * (vec3(3.0) - vec3(2.0) * res);
    res = res * (1.0 - GAMMA) + s_curve * GAMMA;

    // Apply edge mask
    res = res * edge_mask;

    gl_FragColor = vec4(res, 1.0);
}
#endif