/* 777-CRT-ANALOG-MASTER (RAW SIGNAL - CLEAN)
    - OPTIMIZED: Removed RGB Channel manipulation.
    - REMOVED: Bloom processing.
    - READY: Global signal processing only.
*/

// Color Adjustment Parameters (Global Signal Only)
#pragma parameter CLR_SAT "Saturation" 1.0 0.0 2.0 0.05
#pragma parameter CLR_CONT "Contrast" 1.0 0.0 2.0 0.05
#pragma parameter CLR_BRIGHT "Brightness" 0.0 -0.5 0.5 0.05
#pragma parameter CLR_BLK_LVL "Black Level" 0.0 -0.5 0.5 0.05
#pragma parameter CLR_GAMMA "Gamma Correction" 1.0 0.1 3.0 0.1

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

void main() {
    vec3 col = texture2D(Texture, uv).rgb;
    vec3 lum_coeff = vec3(0.299, 0.587, 0.114);

    // 1. Brightness & Contrast (Global)
    col += CLR_BRIGHT;
    col = (col - 0.5) * CLR_CONT + 0.5;

    // 2. Black Level (Global Adjustment)
    col += CLR_BLK_LVL;

    // 3. Saturation (Luminance based, not channel based)
    float luma_sat = dot(col, lum_coeff);
    col = mix(vec3(luma_sat), col, CLR_SAT);

    // 4. Gamma Correction
    col = pow(clamp(col, 0.0, 1.0), vec3(CLR_GAMMA));

    // 5. Safety Clamp & Output
    gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
#endif