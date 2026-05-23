#version 110

/* LIGHT-ULTIMATE (Toshiba V3XEL Turbo - 5050 DNA)
    - PERFORMANCE: Ultra-optimized (Zero-Curve, Zero-Vignette).
    - LOGIC: Smart Multiply with static-optimized transparency.
*/

// --- PARAMETERS ---
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 5.0 0.05
#pragma parameter OverlayMix2 "L2 Intensity (Smart Multiply)" 0.5 0.0 1.0 0.05
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

void main() {
    // 1. Direct Sampling
    vec3 gm = texture2D(Texture, TEX0.xy).rgb;

    // 2. Layer 2 (L2): Smart Multiply (Natural behavior)
    if (OverlayMix2 > 0.01) {
        vec2 maskUV2 = vec2(fract(TEX0.x * OutputSize.x / max(LUTWidth2, 1.0)), 
                            fract(TEX0.y * OutputSize.y / max(LUTHeight2, 1.0)));
        vec3 m2 = texture2D(overlay2, maskUV2).rgb;
        
        // حساب السطوع
        float lum = dot(m2, vec3(0.299, 0.587, 0.114));
        
        // Smart Multiply: القيم ثابتة 0.3 للعتبة و 0.2 للإضاءة
        vec3 smart_mult = mix(gm * m2, gm * (1.0 - (1.0 - m2) * 0.3), lum);
        vec3 final_l2 = mix(smart_mult, m2, lum * 0.2);
        
        gm = mix(gm, clamp(final_l2, 0.0, 1.0), OverlayMix2);
    }

    // 3. Final output
    gl_FragColor = vec4(clamp(gm * BRIGHT_BOOST, 0.0, 1.0), 1.0);
}
#endif