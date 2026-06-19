#version 110

/* 777-CRT-ANALOG-MASTER + GLASS PASS (20)
    - OPTIMIZED: Clean signal processing.
    - FEATURES: Fresnel edges, Specular highlights, and Static gloss.
    - NO CURVATURE: Flat screen layout.
*/

// Glass Reflection Parameters (Pass 20)
#pragma parameter GLASS_STR "Glass Reflection Strength" 0.15 0.0 1.0 0.05
#pragma parameter BORDER_GLOSS "Edge Gloss Intensity" 0.20 0.0 1.0 0.05

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
uniform vec2 TextureSize, InputSize;
varying vec2 uv;

#ifdef PARAMETER_UNIFORM
uniform float CLR_SAT, CLR_CONT, CLR_BRIGHT, CLR_BLK_LVL, CLR_GAMMA;
uniform float GLASS_STR, BORDER_GLOSS;
#endif

void main() {
    // 1. Fetch RAW Color
    vec3 col = texture2D(Texture, uv).rgb;
    vec3 lum_coeff = vec3(0.299, 0.587, 0.114);

    // 2. Brightness & Contrast (Global)
    col += CLR_BRIGHT;
    col = (col - 0.5) * CLR_CONT + 0.5;

    // 3. Black Level
    col += CLR_BLK_LVL;

    // 4. Saturation
    float luma_sat = dot(col, lum_coeff);
    col = mix(vec3(luma_sat), col, CLR_SAT);

    // 5. Gamma Correction
    col = pow(clamp(col, 0.0, 1.0), vec3(CLR_GAMMA));

    // 6. Glass Effects (Pass 20 - Flat Logic)
    vec2 sc = TextureSize / InputSize;
    vec2 p = (uv * sc) - 0.5;
    float r2 = dot(p, p);

    // Fresnel Effect: Increase reflection intensity towards edges
    float fresnel = pow(r2 * 2.2, 2.0) * BORDER_GLOSS;

    // Specular Highlight: Simulated top-left light spot
    float spec = smoothstep(0.4, 0.0, length(p - vec2(-0.35, 0.35)));
    spec *= 0.15 * GLASS_STR;

    // Static Bloom: Subtle overall surface gloss
    float gloss = (1.0 - length(p)) * 0.05 * GLASS_STR;

    // 7. Final Composite & Output
    vec3 final_color = col + fresnel + spec + gloss;
    gl_FragColor = vec4(clamp(final_color, 0.0, 1.0), 1.0);
}
#endif