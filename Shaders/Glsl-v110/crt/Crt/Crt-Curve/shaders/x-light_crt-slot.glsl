#version 110

/* 777-LITE-TURBO-V4-ULTRA-FIXED (Fixed Scanline Scale Edition)
    - FIXED: Scanline scale corrected using TextureSize to prevent giant lines.
    - INTEGRATED: Fast Pure Sine-Wave Scanline engine tied to CRT geometry.
    - MASK: Kept the ultra-fast 6x2 Slot Mask (Ultra-Lightweight Indexing).
    - SPEED: Zero-cost math, Branchless logic.
*/

#pragma parameter BARREL_DISTORTION "Screen Curve" 0.15 0.0 1.0 0.02
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.20 1.0 2.0 0.01
#pragma parameter VIG_STR "Vignette Intensity" 0.15 0.0 2.0 0.05

// --- Scanlines Control (Sine Wave) ---
#pragma parameter SCAN_STR "Scanline Intensity (0=OFF)" 0.40 0.0 1.0 0.05
#pragma parameter MASK_STR "Mask Strength" 0.20 0.0 1.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
varying vec2 screen_scale; 
uniform mat4 MVPMatrix;
uniform vec2 TextureSize, InputSize;

void main() {
    uv = TexCoord;
    screen_scale = TextureSize / InputSize; 
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 uv;
varying vec2 screen_scale;
uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, BRIGHT_BOOST, VIG_STR, SCAN_STR, MASK_STR;
#endif

void main() {
    // 1. Coordinates & Curve 
    vec2 p = (uv * screen_scale) - 0.5;
    float r2 = dot(p, p);
    vec2 p_curved = p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8));
    
    // 2. Exact Game UVs
    vec2 tex_uv = (p_curved + 0.5) / screen_scale;
    vec3 res = texture2D(Texture, tex_uv).rgb;

    // 3. Branchless Bounds Check
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float check = bounds.x * bounds.y;

    // 4. PERFECT SINE-WAVE SCANLINES (تم إصلاح المقاس هنا بالربط بـ TextureSize)
    float pixel_y = tex_uv.y * TextureSize.y;
    float scan = sin(pixel_y * 6.2831853) * 0.5 + 0.5;
    res *= mix(1.0, scan, SCAN_STR);

    // 5. Advanced 6x2 Slot Mask 
    vec3 mcol = vec3(0.0);
    int x_coord = int(mod(gl_FragCoord.x, 6.0));
    int y_coord = int(mod(gl_FragCoord.y, 2.0));
    
    int idx = x_coord - (y_coord * 3);
    
    if (idx >= 0 && idx < 3) {
        mcol[idx] = 2.0; 
    }
    
    res = mix(res, res * mcol, MASK_STR);

    // 6. Final Polish
    res *= BRIGHT_BOOST;
    res *= (1.0 - r2 * VIG_STR);

    gl_FragColor = vec4(res * check, 1.0);
}
#endif