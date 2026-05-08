#version 110

/* 777-LITE-TURBO-V13-SCAN-ONLY-W
    - SCANLINES: Smart Overlay (Multiply/Screen blend).
    - MASK: EXACT CLONE OF CODE 7 (Branchless Logic with W control).
    - PERFORMANCE: Optimized for mobile.
*/

#pragma parameter BARREL_DISTORTION "Screen Curve (0=OFF)" 0.15 0.0 1.0 0.02
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.30 1.0 2.5 0.05
#pragma parameter VIG_STR "Vignette Intensity (0=OFF)" 0.35 0.0 2.0 0.05
#pragma parameter SCAN_STR "Scanline Intensity (0=OFF)" 0.30 0.0 1.0 0.05
#pragma parameter SCAN_SIZE "Scanline Size" 5.0 1.0 10.0 0.5
#pragma parameter MASK_STR "Mask Strength (0=OFF)" 0.5 0.0 1.0 0.05
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
uniform float BARREL_DISTORTION, BRIGHT_BOOST, VIG_STR, SCAN_STR, SCAN_SIZE, MASK_STR, MASK_W;
#endif

void main() {
    vec2 sc = TextureSize / InputSize;
    vec2 p = (uv * sc) - 0.5;
    vec2 p_curved;
    vec2 p2 = p * p;

    // 1. Hyper-Fast Geometry
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

    // 3. Smooth Vignette
    if (VIG_STR > 0.0) {
        float vignette = p2.x * p2.y * 15.0; 
        res *= (1.0 - clamp(vignette * VIG_STR, 0.0, 1.0));
    }

    // 4. Scanlines (Overlay Logic)
    if (SCAN_STR > 0.0) {
        float scan = abs(fract(gl_FragCoord.y * (1.0 / SCAN_SIZE) - 0.5) - 0.5) * 4.0;
        scan = clamp(scan, 0.0, 1.0);
        
        vec3 scan_ovl = (res < vec3(0.8)) ? (res * scan) : (1.0 - (1.0 - res) * (1.0 - (scan - 1.0)));
        res = mix(res, scan_ovl, SCAN_STR);
    }

    // 5. TRUE MASK_W LOGIC (EXACT CLONE FROM 7)
    if (MASK_STR > 0.0) {
        float pos = mod(gl_FragCoord.x, MASK_W) / MASK_W;
        vec3 mcol = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), 1.0 - MASK_STR, 1.0 + MASK_STR);
        res *= mcol;
    }

    // 6. FINAL STAGE
    gl_FragColor = vec4(res * BRIGHT_BOOST, 1.0);
}
#endif