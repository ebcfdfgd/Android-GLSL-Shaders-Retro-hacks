#version 110

/* 777-NEON-ARCADE-FULL-CONTROL
    - FEATURES: Individual Hue, Saturation, and Value for each of the 4 colors.
    - MATH: Branchless execution with per-color HSV optimization.
*/

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

// --- بارامترات التحكم المنفصلة ---
#pragma parameter NEON_ON "Enable Neon Mode" 1.0 0.0 1.0 1.0
#pragma parameter INVERT "Invert Neon Logic" 1.0 0.0 1.0 1.0
#pragma parameter GLOW_STR "Neon Glow Strength" 0.6 0.0 2.0 0.05

// Color 1 (High)
#pragma parameter HUE_1 "C1 Hue" 60.0 0.0 360.0 5.0
#pragma parameter SAT_1 "C1 Saturation" 1.0 0.0 1.5 0.05
#pragma parameter VAL_1 "C1 Brightness" 1.0 0.0 1.5 0.05

// Color 2
#pragma parameter HUE_2 "C2 Hue" 30.0 0.0 360.0 5.0
#pragma parameter SAT_2 "C2 Saturation" 1.0 0.0 1.5 0.05
#pragma parameter VAL_2 "C2 Brightness" 0.8 0.0 1.5 0.05

// Color 3 (Red Zone)
#pragma parameter HUE_3 "C3 Hue" 300.0 0.0 360.0 5.0
#pragma parameter SAT_3 "C3 Saturation" 1.0 0.0 1.5 0.05
#pragma parameter VAL_3 "C3 Brightness" 0.6 0.0 1.5 0.05

// Color 4 (Low)
#pragma parameter HUE_4 "C4 Hue" 340.0 0.0 360.0 5.0
#pragma parameter SAT_4 "C4 Saturation" 1.0 0.0 1.5 0.05
#pragma parameter VAL_4 "C4 Brightness" 0.1 0.0 1.5 0.05

#ifdef PARAMETER_UNIFORM
uniform float NEON_ON, INVERT, GLOW_STR;
uniform float HUE_1, SAT_1, VAL_1;
uniform float HUE_2, SAT_2, VAL_2;
uniform float HUE_3, SAT_3, VAL_3;
uniform float HUE_4, SAT_4, VAL_4;
#endif

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
    vec3 raw_col = texture2D(Texture, uv).rgb;
    float luma = dot(raw_col, vec3(0.299, 0.587, 0.114));
    luma = mix(luma, 1.0 - luma, INVERT);

    // [تعديل] كل لون يأخذ بارامتراته الخاصة الآن
    vec3 c1 = hsv2rgb(HUE_1, SAT_1, VAL_1);
    vec3 c2 = hsv2rgb(HUE_2, SAT_2, VAL_2);
    vec3 c3 = hsv2rgb(HUE_3, SAT_3, VAL_3);
    vec3 c4 = hsv2rgb(HUE_4, SAT_4, VAL_4); 

    vec3 col = mix(c4, c3, step(0.25, luma));
    col = mix(col, c2, step(0.50, luma));
    col = mix(col, c1, step(0.75, luma));

    float glow_luma = dot(col, vec3(0.299, 0.587, 0.114));
    vec3 neon_final = col + (col * glow_luma * glow_luma * GLOW_STR * 5.0);

    gl_FragColor = vec4(mix(raw_col, neon_final, NEON_ON), 1.0);
}
#endif