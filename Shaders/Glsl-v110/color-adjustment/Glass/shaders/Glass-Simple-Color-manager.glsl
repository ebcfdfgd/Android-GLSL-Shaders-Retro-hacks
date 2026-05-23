#version 110

/* 777-CRT-ANALOG-MASTER + GLASS PASS (NO CURVE)
    - Color Matrix -> Adjustments -> Gamma.
    - Added: Fresnel edges, Specular highlight, and Ambient gloss.
    - Removed: Curvature and Boundary clipping.
*/

// Glass Reflection Parameters (From Pass 20)
#pragma parameter GLASS_STR "Glass Reflection Strength" 0.15 0.0 1.0 0.05
#pragma parameter BORDER_GLOSS "Edge Gloss Intensity" 0.20 0.0 1.0 0.05

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
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    uv = TexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;
varying vec2 uv;

#ifdef PARAMETER_UNIFORM
uniform float GLASS_STR, BORDER_GLOSS;
uniform float CLR_SAT, CLR_CONT, CLR_BRIGHT, CLR_BLK_LVL, CLR_GAMMA;
uniform float rr, rg, rb, gr, gg, gb, br, bg, bb;
#endif

void main() {
    // [1] Color Matrix & Grading Logic
    vec3 col = texture2D(Texture, uv).rgb;

    mat3 color_matrix = mat3(
        rr, gr, br,
        rg, gg, bg,
        rb, gb, bb
    );
    col = col * color_matrix;

    col += CLR_BRIGHT;
    col = (col - 0.5) * CLR_CONT + 0.5;
    col += CLR_BLK_LVL;

    vec3 lum_coeff = vec3(0.299, 0.587, 0.114);
    float luma = dot(col, lum_coeff);
    col = mix(vec3(luma), col, CLR_SAT);

    col = pow(clamp(col, 0.0, 1.0), vec3(CLR_GAMMA));

    // [2] Glass Reflection Logic (Pass 20 - Flat)
    vec2 sc = TextureSize / InputSize;
    vec2 p = (uv * sc) - 0.5;
    float r2 = dot(p, p);

    // Fresnel Effect (Reflection intensity on edges)
    float fresnel = pow(r2 * 2.2, 2.0) * BORDER_GLOSS;

    // Specular Highlight (Light spot on top-left)
    float spec = smoothstep(0.4, 0.0, length(p - vec2(-0.35, 0.35)));
    spec *= 0.15 * GLASS_STR;

    // Ambient Gloss (Center-out glow)
    float gloss = (1.0 - length(p)) * 0.05 * GLASS_STR;

    // Final Composite
    vec3 final_color = col + fresnel + spec + gloss;

    gl_FragColor = vec4(final_color, 1.0);
}
#endif