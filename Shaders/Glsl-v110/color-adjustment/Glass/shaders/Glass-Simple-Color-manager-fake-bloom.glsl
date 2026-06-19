#version 110

/* 777-CRT-ANALOG-MASTER + CENTRAL GLOW + GLASS OVERLAY
    - COMBINED: Matrix Color + Central Radial Glow + Flat Glass Reflection.
    - FEATURES: Fresnel edges, Specular highlight, and Ambient gloss.
    - REMOVED: Curvature and Boundary clipping.
*/

// Glass Reflection Parameters (From Pass 20)
#pragma parameter GLASS_STR "Glass Reflection Strength" 0.15 0.0 1.0 0.05
#pragma parameter BORDER_GLOSS "Edge Gloss Intensity" 0.20 0.0 1.0 0.05

// Central Glow Parameter
#pragma parameter GLOW_STR "Central Glow Intensity" 0.3 0.0 1.0 0.05

// Color Adjustment Parameters
#pragma parameter CLR_SAT "Saturation" 1.0 0.0 2.0 0.05
#pragma parameter CLR_CONT "Contrast" 1.0 0.0 2.0 0.05
#pragma parameter CLR_BRIGHT "Brightness" 0.0 -0.5 0.5 0.01
#pragma parameter CLR_BLK_LVL "Black Level" 0.0 -0.5 0.5 0.01
#pragma parameter CLR_GAMMA "Gamma Correction" 1.0 0.1 3.0 0.1

// Matrix Parameters (3x3)
#pragma parameter rr "Red -> Red" 1.0 -2.0 2.0 0.05
#pragma parameter rg "Green -> Red" 0.0 -2.0 2.0 0.05
#pragma parameter rb "Blue -> Red" 0.0 -2.0 2.0 0.05
#pragma parameter gr "Red -> Green" 0.0 -2.0 2.0 0.05
#pragma parameter gg "Green -> Green" 1.0 -2.0 2.0 0.05
#pragma parameter gb "Blue -> Green" 0.0 -2.0 2.0 0.05
#pragma parameter br "Red -> Blue" 0.0 -2.0 2.0 0.05
#pragma parameter bg "Green -> Blue" 0.0 -2.0 2.0 0.05
#pragma parameter bb "Blue -> Blue" 1.0 -2.0 2.0 0.05

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
varying vec2 uv;
varying vec2 p_pos;

#ifdef PARAMETER_UNIFORM
uniform float GLASS_STR, BORDER_GLOSS, GLOW_STR;
uniform float CLR_SAT, CLR_CONT, CLR_BRIGHT, CLR_BLK_LVL, CLR_GAMMA;
uniform float rr, rg, rb, gr, gg, gb, br, bg, bb;
#endif

void main() {
    // [1] Initial Color Fetch & Matrix Transform
    vec3 col = texture2D(Texture, uv).rgb;

    mat3 color_matrix = mat3(rr, gr, br, rg, gg, bg, rb, gb, bb);
    col = col * color_matrix;

    // [2] Central Radial Glow Logic
    float r2 = dot(p_pos, p_pos);
    float luma_glow = dot(col, vec3(0.299, 0.587, 0.114));
    float radial = max(0.0, 1.0 - r2 * 3.0); 
    col += (col * luma_glow * GLOW_STR) * radial;

    // [3] Basic Color Grading
    col += CLR_BRIGHT;
    col = (col - 0.5) * CLR_CONT + 0.5;
    col += CLR_BLK_LVL;

    float luma_final = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(vec3(luma_final), col, CLR_SAT);

    // [4] Gamma Correction
    col = pow(clamp(col, 0.0, 1.0), vec3(CLR_GAMMA));

    // [5] Flat Glass Overlays (Pass 20 Physics)
    vec2 sc = TextureSize / InputSize;
    vec2 p_glass = (uv * sc) - 0.5;
    float r2_glass = dot(p_glass, p_glass);

    // Fresnel (Edge reflection) - Uses pow for edge sharpness
    float fresnel = pow(r2_glass * 2.2, 2.0) * BORDER_GLOSS;

    // Specular Highlight (Simulated bulb reflection)
    float spec = smoothstep(0.4, 0.0, length(p_glass - vec2(-0.35, 0.35)));
    spec *= 0.15 * GLASS_STR;

    // Ambient Gloss (Subtle overall glass feeling)
    float gloss = (1.0 - length(p_glass)) * 0.05 * GLASS_STR;

    // Final Composite: Grading + Reflection Layers
    vec3 final_color = col + fresnel + spec + gloss;

    gl_FragColor = vec4(final_color, 1.0);
}
#endif