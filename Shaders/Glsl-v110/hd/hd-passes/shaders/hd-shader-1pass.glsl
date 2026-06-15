#version 110

// PARAMETERS
#pragma parameter AO_STR "Cavity AO" 1.20 0.00 4.00 0.05
#pragma parameter RIM_STR "Rim Light" 1.10 0.00 3.00 0.05
#pragma parameter SPECULAR_STR "Micro Specular" 1.00 0.00 3.00 0.05
#pragma parameter CONTRAST_STR "Contrast" 1.10 0.50 2.00 0.05
#pragma parameter SAT_BOOST "Saturation" 1.15 0.00 3.00 0.05
#pragma parameter VIBRANCE_STR "Vibrance" 1.00 0.00 3.00 0.05
#pragma parameter EXPOSURE_STR "Exposure" 1.00 0.25 2.00 0.05
#pragma parameter TONEMAP_STR "ACES" 1.00 0.00 1.00 0.05
#pragma parameter BLOOM_STR "Bloom" 0.50 0.00 3.00 0.05
#pragma parameter SOFT_BLOOM "Soft Bloom" 0.75 0.00 3.00 0.05
#pragma parameter SHARPEN_STR "Sharpness" 1.00 0.00 3.00 0.05
#pragma parameter BLACK_LEVEL "Black Level" 0.00 0.00 1.00 0.01
#pragma parameter HIGHLIGHT_COMP "Highlight RollOff" 0.50 0.00 1.00 0.01
#pragma parameter WARMTH_STR "Warmth" 0.00 -1.00 1.00 0.01
#pragma parameter TINT_STR "Tint" 0.00 -1.00 1.00 0.01
#pragma parameter VIGNETTE_STR "Vignette" 0.15 0.00 1.00 0.01
#pragma parameter OUTLINE_STR "Outline" 0.30 0.00 3.00 0.05
#pragma parameter FLARE_STR "Lens Flare" 0.30 0.00 3.00 0.05
#pragma parameter GODRAY_STR " Rays" 0.20 0.00 3.00 0.05
#pragma parameter TILTSHIFT_STR "TiltShift" 0.00 0.00 1.00 0.01
#pragma parameter MOTION_BLUR "Motion Blur" 0.00 0.00 1.00 0.01
#pragma parameter COLOR_GRAD "Color Grade" 1.00 0.00 2.00 0.05
#pragma parameter DEPTH_MASK "Depth Sim" 0.50 0.00 2.00 0.05
#pragma parameter DITHER_STR "Dither" 0.15 0.00 1.00 0.01

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
uniform mat4 MVPMatrix;

void main() {
    uv = TexCoord;
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
precision highp float;

varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize;

// Uniforms
uniform float AO_STR,RIM_STR,SPECULAR_STR,CONTRAST_STR,SAT_BOOST,VIBRANCE_STR,EXPOSURE_STR,TONEMAP_STR;
uniform float BLOOM_STR,SOFT_BLOOM,SHARPEN_STR,BLACK_LEVEL,HIGHLIGHT_COMP,WARMTH_STR,TINT_STR,VIGNETTE_STR;
uniform float OUTLINE_STR,FLARE_STR,GODRAY_STR,TILTSHIFT_STR,MOTION_BLUR,COLOR_GRAD,DEPTH_MASK,DITHER_STR;

float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 aces(vec3 x) {
    x = max(vec3(0.0), x); // حماية ACES من القيم السالبة
    return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

void main() {
    vec2 px = 1.0 / TextureSize;
    vec3 C = texture2D(Texture, uv).rgb;
    vec3 L = texture2D(Texture, uv - vec2(px.x, 0.0)).rgb;
    vec3 R = texture2D(Texture, uv + vec2(px.x, 0.0)).rgb;
    vec3 U = texture2D(Texture, uv - vec2(0.0, px.y)).rgb;
    vec3 D = texture2D(Texture, uv + vec2(0.0, px.y)).rgb;
    vec3 UL = texture2D(Texture, uv - px).rgb;
    vec3 UR = texture2D(Texture, uv + vec2(px.x, -px.y)).rgb;
    vec3 DL = texture2D(Texture, uv + vec2(-px.x, px.y)).rgb;
    vec3 DR = texture2D(Texture, uv + px).rgb;

    vec3 col = C;
    float lc = lum(C);
    float avg = (lum(L) + lum(R) + lum(U) + lum(D) + lum(UL) + lum(UR) + lum(DL) + lum(DR)) / 8.0;
    
    // AO
    float cavity = clamp(avg - lc + 0.5, 0.0, 1.0);
    col *= mix(1.0 - AO_STR * 0.5, 1.0, cavity);

    // Outline & Rim
    float edge = abs(lum(R) - lum(L)) + abs(lum(D) - lum(U));
    col = mix(col, vec3(0.0), smoothstep(0.10, 0.35, edge) * OUTLINE_STR);
    float rim = smoothstep(0.10, 0.45, edge);
    col += rim * RIM_STR * 0.20;

    // Specular
    float spec = pow(max(lc - 0.65, 0.0), 4.0);
    col += spec * SPECULAR_STR;

    // Blur & Bloom
    vec3 blur = (L + R + U + D + UL + UR + DL + DR) / 8.0;
    col += max(lum(blur) - SOFT_BLOOM, 0.0) * BLOOM_STR;
    
    // Sharpen (Clamp added to prevent artifacts)
    col = clamp(col + (col - blur) * SHARPEN_STR * 0.5, 0.0, 2.0);

    // Contrast & Exposure
    col *= EXPOSURE_STR;
    col = clamp((col - 0.5) * CONTRAST_STR + 0.5, 0.0, 2.0);

    // Vibrance & Saturation
    float sat = max(col.r, max(col.g, col.b)) - min(col.r, min(col.g, col.b));
    col = mix(vec3(lum(col)), col, 1.0 + VIBRANCE_STR * (1.0 - sat));
    col = mix(vec3(lum(col)), col, SAT_BOOST);

    // Color Tint
    col.r += WARMTH_STR * 0.08; col.b -= WARMTH_STR * 0.05;
    col.r += TINT_STR * 0.05; col.b += TINT_STR * 0.03;

    // Godrays & Flare
    vec3 god = texture2D(Texture, mix(uv, vec2(0.5, 0.2), 0.05)).rgb;
    col += max(lum(god) - 0.6, 0.0) * GODRAY_STR;
    vec3 flare = texture2D(Texture, 1.0 - uv).rgb;
    col += max(lum(flare) - 0.75, 0.0) * FLARE_STR;

    // Tiltshift & Motion Blur
    float focus = smoothstep(0.0, 0.45, abs(uv.y - 0.5));
    col = mix(col, blur, focus * TILTSHIFT_STR);
    vec3 mb = texture2D(Texture, uv + px * 2.0).rgb;
    col = mix(col, mb, MOTION_BLUR * 0.3);

    // Color Grading & Tonemap
    col = mix(col, col.bgr, COLOR_GRAD * 0.1);
    col = mix(col, aces(col), TONEMAP_STR);
    col = mix(col, col / (1.0 + col), HIGHLIGHT_COMP);

    // Finishing
    col = max(col - BLACK_LEVEL, 0.0);
    vec2 p = uv - 0.5;
    col *= mix(1.0, clamp(1.0 - dot(p, p) * 2.0, 0.0, 1.0), VIGNETTE_STR);
    col += (hash(gl_FragCoord.xy) - 0.5) * 0.01 * DITHER_STR;

    gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
#endif