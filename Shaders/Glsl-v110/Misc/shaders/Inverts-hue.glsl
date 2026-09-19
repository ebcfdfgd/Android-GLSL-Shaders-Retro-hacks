#version 110

/*  
    PURE-COLOR-INVERTER WITH HUE
    - PURPOSE: Pure mathematical color inversion with adjustable Hue shift.
    - HOW IT WORKS: Inverts RGB channels instantly and shifts the Hue of the result.
*/

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord;
uniform mat4 MVPMatrix;
void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord.xy;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 vTexCoord;
uniform sampler2D Texture;

// --- Control Parameter ---
#pragma parameter INV_HUE "Invert Hue Shift" 0.0 0.0 360.0 5.0

#ifdef PARAMETER_UNIFORM
uniform float INV_HUE;
#endif

vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = c.g < c.b ? vec4(c.bg, K.wz) : vec4(c.gb, K.xy);
    vec4 q = c.r < p.x ? vec4(p.xyw, c.r) : vec4(c.r, p.yzx);
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(float h, float s, float v) {
    h = h / 60.0;
    float i = floor(h);
    float f = h - i;
    float p = v * (1.0 - s);
    float q = v * (1.0 - s * f);
    float t = v * (1.0 - s * (1.0 - f));
    vec3 res = vec3(v, t, p) * step(abs(h-0.0), 0.5) +
               vec3(q, v, p) * step(abs(h-1.0), 0.5) +
               vec3(p, v, t) * step(abs(h-2.0), 0.5) +
               vec3(p, q, v) * step(abs(h-3.0), 0.5) +
               vec3(t, p, v) * step(abs(h-4.0), 0.5) +
               vec3(v, p, q) * step(abs(h-5.0), 0.5);
    return res;
}

void main() {
    // 1. Read core pixel color
    vec3 core_col = texture2D(Texture, vTexCoord).rgb;
    
    // 2. Pure mathematical color inversion
    vec3 inverted_col = vec3(1.0) - core_col;

    // 3. Convert to HSV, shift Hue only, and convert back to RGB
    vec3 hsv = rgb2hsv(inverted_col);
    float shifted_hue = mod((hsv.x * 360.0) + INV_HUE, 360.0);
    vec3 final_col = hsv2rgb(shifted_hue, hsv.y, hsv.z);

    // 4. Output final color
    gl_FragColor = vec4(final_col, 1.0);
}
#endif