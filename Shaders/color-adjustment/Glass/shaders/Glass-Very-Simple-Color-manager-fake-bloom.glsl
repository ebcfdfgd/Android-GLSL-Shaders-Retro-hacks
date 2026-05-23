#version 110

/* 777-CRT-ANALOG-MASTER + CENTRAL BLOOM + GLASS PASS (20)
    - PIPELINE: Radial Glow -> Signal Processing -> Glass Overlays.
    - FEATURES: Dynamic Central Bloom, Fresnel Edge, and Top-Left Specular.
    - FLAT: No curvature, pure flat glass simulation.
*/

// --- GLASS PARAMETERS (20) ---
#pragma parameter GLASS_STR "Glass Reflection Strength" 0.15 0.0 1.0 0.05
#pragma parameter BORDER_GLOSS "Edge Gloss Intensity" 0.20 0.0 1.0 0.05

// --- BLOOM PARAMETERS ---
#pragma parameter GLOW_STR "Central Glow Intensity" 0.35 0.0 1.0 0.05

// --- COLOR ADJUSTMENT PARAMETERS ---
#pragma parameter CLR_SAT "Saturation" 1.0 0.0 2.0 0.05
#pragma parameter CLR_CONT "Contrast" 1.0 0.0 2.0 0.05
#pragma parameter CLR_BRIGHT "Brightness" 0.0 -0.5 0.5 0.01
#pragma parameter CLR_BLK_LVL "Black Level" 0.0 -0.5 0.5 0.01
#pragma parameter CLR_GAMMA "Gamma Correction" 1.0 0.1 3.0 0.1

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
varying vec2 p_pos;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    uv = TexCoord;
    p_pos = TexCoord - 0.5;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;
varying vec2 uv, p_pos;

#ifdef PARAMETER_UNIFORM
uniform float GLASS_STR, BORDER_GLOSS;
uniform float GLOW_STR, CLR_SAT, CLR_CONT, CLR_BRIGHT, CLR_BLK_LVL, CLR_GAMMA;
#endif

void main() {
    // 1. RAW Color Fetch & Luma Constants
    vec3 col = texture2D(Texture, uv).rgb;
    vec3 lum_coeff = vec3(0.299, 0.587, 0.114);

    // 2. Central Radial Glow (Bloom) Logic
    float r2 = dot(p_pos, p_pos);
    float luma = dot(col, lum_coeff);
    float radial = max(0.0, 1.0 - r2 * 3.0); 
    col += (col * luma * GLOW_STR) * radial;

    // 3. Global Signal Processing (Brightness, Contrast, Black Level)
    col += CLR_BRIGHT;
    col = (col - 0.5) * CLR_CONT + 0.5;
    col += CLR_BLK_LVL;

    // 4. Saturation
    float luma_final = dot(col, lum_coeff);
    col = mix(vec3(luma_final), col, CLR_SAT);

    // 5. Gamma Correction
    col = pow(clamp(col, 0.0, 1.0), vec3(CLR_GAMMA));

    // 6. Flat Glass Effects (Pass 20 Logic)
    vec2 sc = TextureSize / InputSize;
    vec2 p_glass = (uv * sc) - 0.5;
    float r2_glass = dot(p_glass, p_glass);

    // Fresnel Effect (Edge reflection sharpness)
    float fresnel = pow(r2_glass * 2.2, 2.0) * BORDER_GLOSS;

    // Specular Highlight (Simulated bulb reflection at top-left)
    float spec = smoothstep(0.4, 0.0, length(p_glass - vec2(-0.35, 0.35)));
    spec *= 0.15 * GLASS_STR;

    // Ambient Gloss (Center-out surface glow)
    float gloss = (1.0 - length(p_glass)) * 0.05 * GLASS_STR;

    // 7. Final Composite & Safety Clamp
    vec3 final_color = col + fresnel + spec + gloss;
    gl_FragColor = vec4(clamp(final_color, 0.0, 1.0), 1.0);
}
#endif