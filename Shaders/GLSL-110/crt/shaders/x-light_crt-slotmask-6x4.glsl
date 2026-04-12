#version 110

/* 777-LITE-TURBO-V2-ZERO-LOAD
    - BYPASS LOGIC: If value is 0, GPU cycles are saved.
    - CUSTOM MASK: 6x4 logic only runs if MASK_STR > 0.
    - OPTIMIZED: Skip geometry math if BARREL_DISTORTION is 0.
*/

#pragma parameter BARREL_DISTORTION "Screen Curve (0=OFF)" 0.15 0.0 0.3 0.01
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.05 1.0 2.5 0.05
#pragma parameter VIG_STR "Vignette Intensity (0=OFF)" 0.15 0.0 2.0 0.05

// --- Scanlines Control ---
#pragma parameter SCAN_STR "Scanline Intensity (0=OFF)" 0.35 0.0 1.0 0.05
#pragma parameter SCAN_SIZE "Scanline Size (Zoom)" 5.0 1.0 10.0 0.5

// --- Advanced Mask Control ---
#pragma parameter MASK_TYPE "Mask Type: 0.Balanced|1.6x4 Custom" 0.0 0.0 1.0 1.0
#pragma parameter MASK_STR "Mask Strength (0=OFF)" 0.15 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width (Option 0 only)" 3.0 1.0 10.0 1.0

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
uniform float BARREL_DISTORTION, BRIGHT_BOOST, VIG_STR, SCAN_STR, SCAN_SIZE, MASK_STR, MASK_W, MASK_TYPE;
#endif

void main() {
    vec2 sc = TextureSize / InputSize;
    vec2 p = (uv * sc) - 0.5;
    vec2 p_curved;

    // 1. Geometry Bypass: Skip math if curvature is 0
    if (BARREL_DISTORTION > 0.0) {
        float ky = BARREL_DISTORTION * 0.8; 
        p_curved.x = p.x * (1.0 + (p.y * p.y) * (BARREL_DISTORTION * 0.2));
        p_curved.y = p.y * (1.0 + (p.x * p.x) * ky);
        p_curved *= (1.0 - 0.1 * BARREL_DISTORTION);
    } else {
        p_curved = p;
    }

    if (abs(p_curved.x) > 0.5 || abs(p_curved.y) > 0.5) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // 2. Sample & Brightness
    vec3 res = texture2D(Texture, (p_curved + 0.5) / sc).rgb;
    res *= BRIGHT_BOOST;

    // 3. Vignette Bypass
    if (VIG_STR > 0.0) {
        res *= (1.0 - dot(p_curved, p_curved) * VIG_STR);
    }

    // 4. Scanlines Bypass
    if (SCAN_STR > 0.0) {
        float scanline = sin(gl_FragCoord.y * (6.28318 / SCAN_SIZE)) * 0.5 + 0.5;
        res *= mix(1.0, scanline, SCAN_STR);
    }

    // 5. Mask System Bypass
    if (MASK_STR > 0.0) {
        vec3 mcol = vec3(1.0);

        if (MASK_TYPE < 0.5) {
            // الخيار 0: الماسك الأصلي
            float W = floor(MASK_W + 0.001);
            float pos = mod(gl_FragCoord.x, W);
            mcol.r = clamp(2.0 - abs((pos / W) * 6.0 - 1.0), 0.6, 1.6);
            mcol.g = clamp(2.0 - abs((pos / W) * 6.0 - 3.0), 0.6, 1.6);
            mcol.b = clamp(2.0 - abs((pos / W) * 6.0 - 5.0), 0.6, 1.6);
        } 
        else {
            // الخيار 1: ماسك 6x4 مخصص
            int px = int(mod(gl_FragCoord.x, 6.0));
            int py = int(mod(gl_FragCoord.y, 4.0));
            mcol = vec3(0.0); 

            if (py == 0 || py == 2) {
                if (px % 3 == 0) mcol = vec3(1.0, 0.0, 0.0);
                else if (px % 3 == 1) mcol = vec3(0.0, 1.0, 0.0);
                else mcol = vec3(0.0, 0.0, 1.0);
            }
            else if (py == 1) {
                if (px >= 3) {
                    if (px == 3) mcol = vec3(1.0, 0.0, 0.0);
                    else if (px == 4) mcol = vec3(0.0, 1.0, 0.0);
                    else mcol = vec3(0.0, 0.0, 1.0);
                }
            }
            else if (py == 3) {
                if (px < 3) {
                    if (px == 0) mcol = vec3(1.0, 0.0, 0.0);
                    else if (px == 1) mcol = vec3(0.0, 1.0, 0.0);
                    else mcol = vec3(0.0, 0.0, 1.0);
                }
            }
            mcol *= 1.8; 
        }
        res = mix(res, res * mcol, MASK_STR);
    }

    gl_FragColor = vec4(res, 1.0);
}
#endif