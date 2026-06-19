#version 110

// PARAMETERS
#pragma parameter CONTRAST_STR "Contrast" 1.10 0.50 2.00 0.05
#pragma parameter SAT_BOOST "Saturation" 1.15 0.00 3.00 0.05
#pragma parameter VIBRANCE_STR "Vibrance" 1.00 0.00 3.00 0.05
#pragma parameter EXPOSURE_STR "Exposure" 1.00 0.25 2.00 0.05
#pragma parameter TONEMAP_STR "ACES" 1.00 0.00 1.00 0.05
#pragma parameter WARMTH_STR "Warmth" 0.00 -1.00 1.00 0.01
#pragma parameter TINT_STR "Tint" 0.00 -1.00 1.00 0.01
#pragma parameter COLOR_GRAD "Color Grade" 1.00 0.00 2.00 0.05
#pragma parameter BLACK_LEVEL "Black Level" 0.00 0.00 1.00 0.01
#pragma parameter HIGHLIGHT_COMP "Highlight RollOff" 0.50 0.00 1.00 0.01

#if defined(VERTEX)
attribute vec4 VertexCoord; attribute vec2 TexCoord; varying vec2 uv; uniform mat4 MVPMatrix;
void main() { uv = TexCoord; gl_Position = MVPMatrix * VertexCoord; }
#elif defined(FRAGMENT)
precision highp float;
varying vec2 uv; uniform sampler2D Texture;
uniform float CONTRAST_STR, SAT_BOOST, VIBRANCE_STR, EXPOSURE_STR, TONEMAP_STR, WARMTH_STR, TINT_STR, COLOR_GRAD, BLACK_LEVEL, HIGHLIGHT_COMP;

float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
vec3 aces(vec3 x) { x = max(vec3(0.0), x); return clamp((x*(2.51*x+0.03))/(x*(2.43*x+0.59)+0.14), 0.0, 1.0); }

void main() {
    vec3 col = texture2D(Texture, uv).rgb * EXPOSURE_STR;
    
    // Contrast
    col = (col - 0.5) * CONTRAST_STR + 0.5;
    
    // Highlight RollOff
    col = min(col, vec3(HIGHLIGHT_COMP * 2.0));
    
    // Saturation & Vibrance
    float sat = max(col.r, max(col.g, col.b)) - min(col.r, min(col.g, col.b));
    col = mix(vec3(lum(col)), col, 1.0 + VIBRANCE_STR * (1.0 - sat));
    col = mix(vec3(lum(col)), col, SAT_BOOST);
    
    // Tint & Warmth
    col.r += WARMTH_STR * 0.08; col.b -= WARMTH_STR * 0.05;
    col.r += TINT_STR * 0.05; col.b += TINT_STR * 0.03;
    
    // Black Level (تطبيق بعد التعديلات اللونية لتنظيف الظلال)
    col = max(col - BLACK_LEVEL, 0.0);
    
    // ACES & Grade
    col = mix(col, aces(col), TONEMAP_STR);
    col = mix(col, col.bgr, COLOR_GRAD * 0.1);
    
    gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
#endif