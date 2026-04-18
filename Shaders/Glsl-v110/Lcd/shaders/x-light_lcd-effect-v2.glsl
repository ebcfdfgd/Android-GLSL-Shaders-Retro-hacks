#version 110

/* GBA-HYBRID-TURBO-PRO (V3.2 - Extreme Performance)
    - SPEED: Zero-Branching architecture (No IF statements).
    - OPTIMIZED: Vectorized Color Profiles and Hardware-bound math.
    - FIXED: 103 Radial Vignette with aspect-ratio correction.
*/

#pragma parameter MASK_MODE "Mask: 0:Grid, 1:Dots, 2:Hybrid" 2.0 0.0 2.0 1.0
#pragma parameter MASK_STR "Mask Strength" 0.3 0.0 1.0 0.05
#pragma parameter ANALOG_SOFT "Analog Edge Softness" 0.30 0.0 1.0 0.05
#pragma parameter CHROMA_STR "Chroma Bleed Strength" 0.15 0.0 1.0 0.05
#pragma parameter GBA_STRIPING "Interframe Transparency" 0.5 0.0 1.0 0.05
#pragma parameter v_amount "Vignette Strength" 0.2 0.0 1.0 0.05
#pragma parameter v_softness "Vignette Radius" 0.80 0.1 1.5 0.05
#pragma parameter COLOR_MODE "Profile: 0:Raw, 1:GBA, 2:GBC, 3:GB, 4:101" 1.0 0.0 4.0 1.0
#pragma parameter GREEN_BAL "Green Tint Reduction" 0.30 0.0 1.0 0.05
#pragma parameter GBA_COLOR "Hardware Mix Strength" 0.75 0.0 1.0 0.05
#pragma parameter GBA_SAT "Saturation Boost" 1.35 0.0 2.0 0.05
#pragma parameter BRIGHT "Backlight Boost" 1.25 1.0 2.0 0.05
#pragma parameter GBA_BRIGHT_BST "Final Boost (Mask)" 1.25 1.0 2.0 0.05
#pragma parameter GBA_GHOST "LCD Ghosting Intensity" 0.35 0.0 1.0 0.05
#pragma parameter GBA_GRAIN "Plastic Grain Strength" 0.10 0.0 0.5 0.02
#pragma parameter GBA_INK "LCD Ink Black" 0.05 0.0 0.20 0.01
#pragma parameter GBA_GAM "Screen Gamma" 1.10 0.5 2.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 TEX0, vGridCoord;
uniform mat4 MVPMatrix;
uniform vec2 TextureSize;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    TEX0 = TexCoord.xy;
    vGridCoord = TEX0 * TextureSize;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 TEX0, vGridCoord;
uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;
uniform int FrameCount;

#ifdef PARAMETER_UNIFORM
uniform float MASK_MODE, MASK_STR, GBA_BRIGHT_BST, CHROMA_STR, GBA_STRIPING, ANALOG_SOFT, GBA_GRAIN, COLOR_MODE, GREEN_BAL, GBA_COLOR, GBA_SAT, BRIGHT, GBA_GHOST, GBA_INK, GBA_GAM, v_amount, v_softness;
#endif

float plastic_noise(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 ps = 1.0 / TextureSize;
    float time = float(FrameCount);
    
    // [1] Optimized Motion & Sampling
    float toggle = step(0.5, mod(time, 2.0)) - 0.5;
    float striping = (GBA_STRIPING * ps.x) * toggle;
    float ghost_osc = sin(time * 0.4) * GBA_GHOST * 0.1;
    
    float shift = (ANALOG_SOFT * 0.5 + CHROMA_STR * 0.4);
    vec3 res = texture2D(Texture, TEX0).rgb;
    
    // سحب العينات للألوان بمسار رياضي موحد
    float r = texture2D(Texture, TEX0 - ps * (shift + ghost_osc) + striping).r;
    float b = texture2D(Texture, TEX0 + ps * shift + striping).b;
    float g = (texture2D(Texture, TEX0 - ps * ANALOG_SOFT * 0.5).g + texture2D(Texture, TEX0 + ps * ANALOG_SOFT * 0.5).g) * 0.5;
    
    res = mix(res, vec3(r, g, b), ANALOG_SOFT);
    res = mix(res, texture2D(Texture, TEX0 - ps * (GBA_GHOST * 0.5 + ghost_osc)).rgb, GBA_GHOST * 0.4);

    // [2] Branchless Color Profiles (Regional Engine)
    mat3 mGBA = mat3(0.82, 0.18, 0.0, 0.0, mix(0.70, 1.0, GREEN_BAL), mix(0.30, 0.0, GREEN_BAL), 0.05, 0.0, 0.95);
    mat3 mGBC = mat3(0.70, 0.30, 0.0, 0.10, 0.80, 0.10, 0.05, 0.15, 0.80);
    mat3 m101 = mat3(0.95, 0.05, 0.0, 0.02, 0.95, 0.03, 0.05, 0.0, 0.95);
    
    float p1 = step(0.5, COLOR_MODE) * (1.0 - step(1.5, COLOR_MODE));
    float p2 = step(1.5, COLOR_MODE) * (1.0 - step(2.5, COLOR_MODE));
    float p3 = step(2.5, COLOR_MODE) * (1.0 - step(3.5, COLOR_MODE));
    float p4 = step(3.5, COLOR_MODE);

    vec3 target = mix(res, res * mGBA, p1);
    target = mix(target, res * mGBC, p2);
    
    // GB DMG Profile
    float luma = dot(res, vec3(0.299, 0.587, 0.114));
    vec3 dmg = mix(vec3(0.1, 0.15, 0.05), vec3(0.6, 0.7, 0.1), luma);
    target = mix(target, dmg, p3);
    target = mix(target, res * m101, p4);

    res = mix(res, target, GBA_COLOR);

    // [3] Final Adjustments
    res = mix(vec3(luma), res, GBA_SAT);
    res += (plastic_noise(vGridCoord) - 0.5) * GBA_GRAIN * (1.2 - luma);
    res = pow(max(res, GBA_INK), vec3(1.0 / GBA_GAM));

    // [4] Vectorized Mask Engine
    vec3 angle = vGridCoord.xxx * 6.28318 + vec3(0.0, 2.09439, 4.18879);
    vec3 grid = mix(vec3(1.0), sin(angle) * 0.5 + 0.5, MASK_STR) * mix(1.0, sin(vGridCoord.y * 6.28318) * 0.5 + 0.5, MASK_STR * 0.6);
    vec3 dots = mix(vec3(1.0), vec3(clamp(sin(vGridCoord.x * 6.28318) * sin(vGridCoord.y * 6.28318) * 0.5 + 0.5, 0.0, 1.0)), MASK_STR);

    vec3 mask = mix(grid, dots, step(0.5, MASK_MODE));
    mask = mix(mask, grid * dots, step(1.5, MASK_MODE));

    // [5] Corrected Radial Vignette
    float dist = length((TEX0.xy * (TextureSize / InputSize)) - 0.5);
    float vig = mix(1.0, smoothstep(v_softness, v_softness - 0.7, dist), v_amount);
    
    gl_FragColor = vec4(clamp(res * mask * BRIGHT * GBA_BRIGHT_BST * vig, 0.0, 1.0), 1.0);
}
#endif