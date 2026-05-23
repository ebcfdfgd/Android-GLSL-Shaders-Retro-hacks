#version 110

/* ULTIMATE-CRT-CORE (Flat Version)
    - LOGIC: Integrated 2blendoverlay-fast (CRT/Scanline/Mask).
    - PERFORMANCE: Zero-cost flat display.
    - UPDATED: Dark/Light controls removed, added MASK_STRENGTH.
*/

// --- CRT PARAMETERS ---
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 5.0 0.05
#pragma parameter OverlayMix "L1 Intensity (Scanlines)" 0.5 0.0 1.0 0.05
#pragma parameter SCAN_HARDNESS "Scanline Hardness" 8.0 2.0 20.0 0.5
#pragma parameter MASK_STRENGTH "Mask Strength" 0.5 0.0 1.0 0.05
#pragma parameter png_width "L2 Mask Width" 6.0 1.0 10.0 1.0

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec4 TexCoord;
varying vec2 TEX0;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    TEX0 = TexCoord.xy;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 TEX0;
uniform vec2 TextureSize;
uniform sampler2D Texture;

#ifdef PARAMETER_UNIFORM
uniform float BRIGHT_BOOST, OverlayMix, SCAN_HARDNESS, MASK_STRENGTH, png_width;
#endif

// Helper: Overlay blending function
float overlay_f(float a, float b) {
    return (a < 0.5) ? (2.0 * a * b) : (1.0 - 2.0 * (1.0 - a) * (1.0 - b));
}

void main() {
    // 1. Setup coordinates (Direct mapping)
    vec2 fetch_uv = TEX0.xy;
    vec3 gm = texture2D(Texture, fetch_uv).rgb;

    // 2. LOTTES SCANLINES (OVERLAY MODE)
    if (OverlayMix > 0.01) {
        float dst = fract(fetch_uv.y * TextureSize.y) - 0.5;
        float scanline = exp2(-SCAN_HARDNESS * dst * dst); 
        vec3 ovl1 = vec3(overlay_f(gm.r, scanline), overlay_f(gm.g, scanline), overlay_f(gm.b, scanline));
        gm = mix(gm, clamp(ovl1, 0.0, 1.0), OverlayMix);
    }

    // 3. RGB Mask (Updated with MASK_STRENGTH)
    float W = floor(png_width);
    float pos = mod(gl_FragCoord.x, W) / W;
    vec3 mcol = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), 0.0, 1.0);
    // دمج الماسك مع الصورة بناءً على القوة المختارة
    gm *= mix(vec3(1.0), mcol, MASK_STRENGTH);

    // 4. Final Polish (Brightness)
    vec3 col = gm * BRIGHT_BOOST;

    // 5. Final Output
    gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
#endif