#version 110

/* ULTIMATE-CRT-CORE (Hybrid 012 Curve)
    - LOGIC: Integrated 2blendoverlay-fast (CRT/Scanline/Mask).
    - PERFORMANCE: 012 Zero-cost curvature logic.
    - UPDATED: Added Independent Light/Dark Mask Controls.
*/

// --- CRT PARAMETERS ---
#pragma parameter BARREL_DISTORTION "Toshiba Curve Strength" 0.15 0.0 1.0 0.02
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 5.0 0.05
#pragma parameter v_amount "Soft Vignette Intensity" 0.15 0.0 2.5 0.01
#pragma parameter OverlayMix "L1 Intensity (Scanlines)" 0.5 0.0 1.0 0.05
#pragma parameter SCAN_HARDNESS "Scanline Hardness" 8.0 2.0 20.0 0.5
#pragma parameter MASK_LIGHT "Mask Light Strength" 1.5 1.0 2.0 0.05
#pragma parameter MASK_DARK "Mask Dark Strength" 0.5 0.0 1.0 0.05
#pragma parameter png_width "L2 Mask Width" 6.0 1.0 10.0 1.0

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec4 TexCoord;
varying vec2 TEX0, screen_scale;
uniform mat4 MVPMatrix;
uniform vec2 TextureSize, InputSize;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    TEX0 = TexCoord.xy;
    screen_scale = TextureSize / InputSize;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 TEX0, screen_scale;
uniform vec2 TextureSize;
uniform sampler2D Texture;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, BRIGHT_BOOST, v_amount, OverlayMix, SCAN_HARDNESS, MASK_LIGHT, MASK_DARK, png_width;
#endif

// Helper: Overlay blending function
float overlay_f(float a, float b) {
    return (a < 0.5) ? (2.0 * a * b) : (1.0 - 2.0 * (1.0 - a) * (1.0 - b));
}

void main() {
    // 1. Setup coordinates and 012 Curvature
    vec2 p = (TEX0.xy * screen_scale) - 0.5;
    float r2 = dot(p, p);
    
    // 012 Curvature Equation
    vec2 p_curved = p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8));
    
    // 2. Branchless Bounds Check
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float check = bounds.x * bounds.y;

    // 3. Exact Game UVs
    vec2 fetch_uv = (p_curved + 0.5) / screen_scale;
    vec3 gm = texture2D(Texture, fetch_uv).rgb;

    // 4. LOTTES SCANLINES (OVERLAY MODE)
    if (OverlayMix > 0.01) {
        float dst = fract(fetch_uv.y * TextureSize.y) - 0.5;
        float scanline = exp2(-SCAN_HARDNESS * dst * dst); 
        vec3 ovl1 = vec3(overlay_f(gm.r, scanline), overlay_f(gm.g, scanline), overlay_f(gm.b, scanline));
        gm = mix(gm, clamp(ovl1, 0.0, 1.0), OverlayMix);
    }

    // 5. RGB Mask (Updated with Light/Dark logic)
    float W = floor(png_width);
    float pos = mod(gl_FragCoord.x, W) / W;
    // Calculation of mask pattern with dynamic clamps for Light and Dark
    vec3 mcol = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), MASK_DARK, MASK_LIGHT);
    gm *= mcol;

    // 6. Final Polish (Vignette & Brightness)
    gm *= (1.0 - r2 * v_amount);
    vec3 col = gm * BRIGHT_BOOST;

    // 7. Final Output (Multiplied by check for clean borders)
    gl_FragColor = vec4(clamp(col * check, 0.0, 1.0), 1.0);
}
#endif