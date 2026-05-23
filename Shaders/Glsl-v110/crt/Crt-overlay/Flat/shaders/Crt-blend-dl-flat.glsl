#version 110

/* ULTIMATE-CRT-CORE (Flat Version)
    - LOGIC: Integrated 2blendoverlay-fast (CRT/Scanline/Mask).
    - PERFORMANCE: Zero-cost flat display.
    - UPDATED: Curvature and Vignette removed.
*/

// --- CRT PARAMETERS ---
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 5.0 0.05
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
uniform float BRIGHT_BOOST, OverlayMix, SCAN_HARDNESS, MASK_LIGHT, MASK_DARK, png_width;
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

    // 3. RGB Mask
    float W = floor(png_width);
    float pos = mod(gl_FragCoord.x, W) / W;
    vec3 mcol = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), MASK_DARK, MASK_LIGHT);
    gm *= mcol;

    // 4. Final Polish (Brightness)
    vec3 col = gm * BRIGHT_BOOST;

    // 5. Final Output
    gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
#endif