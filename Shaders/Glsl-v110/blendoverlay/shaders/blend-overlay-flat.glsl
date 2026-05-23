#version 110

/* LIGHT-ULTIMATE (Toshiba V3XEL Turbo - 5050 DNA)
    - PERFORMANCE: Ultra-optimized, zero-vignette, zero-curve.
    - LOGIC: High-speed Smart Overlay (L2) with White Visibility Boost.
*/

// --- PARAMETERS ---
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 5.0 0.05

// L2: Fixed to Smart Overlay
#pragma parameter OverlayMix2 "L2 Intensity (Smart Overlay)" 0.0 0.0 1.0 0.05
#pragma parameter LUTWidth2 "L2 Width" 3.0 1.0 1024.0 1.0
#pragma parameter LUTHeight2 "L2 Height" 0.0 1.0 1024.0 1.0

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
uniform vec2 OutputSize;
uniform sampler2D Texture, overlay2;

#ifdef PARAMETER_UNIFORM
uniform float BRIGHT_BOOST, OverlayMix2, LUTWidth2, LUTHeight2;
#endif

// Essential function for Overlay math
float overlay_f(float a, float b) {
    return (a < 0.5) ? (2.0 * a * b) : (1.0 - 2.0 * (1.0 - a) * (1.0 - b));
}

void main() {
    // 1. Direct Sampling
    vec3 gm = texture2D(Texture, TEX0.xy).rgb;

    // 2. Layer 2 (L2): Smart Overlay with White Visibility Boost
    if (OverlayMix2 > 0.01) {
        vec2 maskUV2 = vec2(fract(TEX0.x * OutputSize.x / max(LUTWidth2, 1.0)), 
                            fract(TEX0.y * OutputSize.y / max(LUTHeight2, 1.0)));
        vec3 m2 = texture2D(overlay2, maskUV2).rgb;
        
        // Standard Overlay math
        vec3 ovl2 = vec3(overlay_f(gm.r, m2.r), overlay_f(gm.g, m2.g), overlay_f(gm.b, m2.b));
        
        // Calculate the luminance of the base image (gm)
        float base_lum = dot(gm, vec3(0.299, 0.587, 0.114));
        
        // Force 20% of the raw texture to show on pure white areas
        ovl2 = mix(ovl2, m2, base_lum * 0.20);
        
        gm = mix(gm, clamp(ovl2, 0.0, 1.0), OverlayMix2);
    }

    // 3. Final output
    gl_FragColor = vec4(clamp(gm * BRIGHT_BOOST, 0.0, 1.0), 1.0);
}
#endif