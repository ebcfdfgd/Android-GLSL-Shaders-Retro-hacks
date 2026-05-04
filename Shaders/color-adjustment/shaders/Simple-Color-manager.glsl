#version 110

/* 777-CRT-ANALOG-MASTER (MATRIX ONLY - CLEAN)
    - OPTIMIZED: Removed Gain Adjustment parameters.
    - READY: Custom 9x9 RGB Matrix control.
*/

// Color Adjustment Parameters
#pragma parameter CLR_SAT "Saturation" 1.0 0.0 2.0 0.05
#pragma parameter CLR_CONT "Contrast" 1.0 0.0 2.0 0.05
#pragma parameter CLR_BRIGHT "Brightness" 0.0 -0.5 0.5 0.05
#pragma parameter CLR_BLK_LVL "Black Level" 0.0 -0.5 0.5 0.05
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
varying vec2 uv;

uniform float CLR_SAT, CLR_CONT, CLR_BRIGHT, CLR_BLK_LVL, CLR_GAMMA;
uniform float rr, rg, rb, gr, gg, gb, br, bg, bb;

void main() {
    vec3 col = texture2D(Texture, uv).rgb;
    vec3 lum_coeff = vec3(0.299, 0.587, 0.114);

    // 1. Custom RGB Matrix (Color Profile)
    vec3 new_col;
    new_col.r = col.r * rr + col.g * rg + col.b * rb;
    new_col.g = col.r * gr + col.g * gg + col.b * gb;
    new_col.b = col.r * br + col.g * bg + col.b * bb;
    col = new_col;

    // 2. Safety Clamp
    col = clamp(col, 0.0, 1.0);

    // 3. Brightness & Contrast
    col += CLR_BRIGHT;
    col = (col - 0.5) * CLR_CONT + 0.5;

    // 4. Black Level
    col += CLR_BLK_LVL;

    // 5. Saturation
    float luma_sat = dot(col, lum_coeff);
    col = mix(vec3(luma_sat), col, CLR_SAT);

    // 6. Gamma Correction
    col = pow(clamp(col, 0.0, 1.0), vec3(CLR_GAMMA));

    // 7. Output
    gl_FragColor = vec4(col, 1.0);
}
#endif