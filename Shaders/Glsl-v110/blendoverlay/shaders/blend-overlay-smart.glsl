#version 110

/* LIGHT-ULTIMATE (Toshiba V3XEL Turbo - 5050 DNA)
    - PERFORMANCE: Branchless bounds checking and optimized math.
    - LOGIC: High-speed Smart Overlay (L2) with White Visibility Boost.
*/

// --- PARAMETERS ---
#pragma parameter BARREL_DISTORTION "Curve 0 Strength" 0.15 0.0 1.0 0.02
#pragma parameter v_amount "Soft Vignette Intensity" 0.25 0.0 2.5 0.01
// L2: Fixed to Smart Overlay
#pragma parameter OverlayMix2 "L2 Intensity (Smart Overlay)" 1.0 0.0 1.0 0.05
#pragma parameter LUTWidth2 "L2 Width" 6.0 1.0 1024.0 1.0
#pragma parameter LUTHeight2 "L2 Height" 4.0 1.0 1024.0 1.0

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
uniform vec2 OutputSize, TextureSize, InputSize;
uniform sampler2D Texture, overlay2;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION,v_amount,  OverlayMix2, LUTWidth2, LUTHeight2;
#endif

// Essential function for Overlay math
float overlay_f(float a, float b) {
    return (a < 0.5) ? (2.0 * a * b) : (1.0 - 2.0 * (1.0 - a) * (1.0 - b));
}

void main() {
    // 1. Setup coordinates and Curve 0 logic (r2)
    vec2 p = (TEX0.xy * screen_scale) - 0.5;
    float r2 = dot(p, p);
    
    // High-speed Curve 0 equation with 0.2/0.8 distribution
    vec2 p_curved = p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8));
    
    // Branchless bounds checking using step for FPS boost
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float check = bounds.x * bounds.y;

    // 2. Direct Sampling
    vec2 fetch_uv = (p_curved + 0.5) / screen_scale;
    vec3 gm = texture2D(Texture, fetch_uv).rgb;

    

    // Fixed coordinates for layers
    vec2 mP = TEX0.xy * screen_scale;
    
    // 5. Layer 2 (L2): Smart Overlay with White Visibility Boost
    if (OverlayMix2 > 0.01) {
        vec2 maskUV2 = vec2(fract(mP.x * OutputSize.x / max(LUTWidth2, 1.0)), 
                            fract(mP.y * OutputSize.y / max(LUTHeight2, 1.0)));
        vec3 m2 = texture2D(overlay2, maskUV2).rgb;
        
        // Standard Overlay math
        vec3 ovl2 = vec3(overlay_f(gm.r, m2.r), overlay_f(gm.g, m2.g), overlay_f(gm.b, m2.b));
        
        // Calculate the luminance of the base image (gm)
        float base_lum = dot(gm, vec3(0.299, 0.587, 0.114));
        
        // Force 20% of the raw texture to show on pure white areas
        ovl2 = mix(ovl2, m2, base_lum * 0.2);
        
        gm = mix(gm, clamp(ovl2, 0.0, 1.0), OverlayMix2);
    }
gm *= clamp(1.0 - (r2 * v_amount), 0.0, 1.0);

    // 6. Final output 
    gl_FragColor = vec4(clamp(gm * check, 0.0, 1.0), 1.0);
}
#endif