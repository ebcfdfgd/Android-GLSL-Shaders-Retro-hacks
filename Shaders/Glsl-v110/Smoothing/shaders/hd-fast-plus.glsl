/* ULTIMATE SONIC 2026 - OPTIMIZED WITH CRT SCANLINES */

#pragma parameter dither_str "Dither Removal Strength" 0.8 0.0 1.0 0.05
#pragma parameter SCAN_STR "Scanline: Strength" 0.20 0.0 1.0 0.05
#pragma parameter OUTLINE_STR "Detail: Outline Power" 0.20 0.0 1.0 0.05
#pragma parameter MICRO_AO "Depth: Micro-AO" 0.35 0.0 1.0 0.05
#pragma parameter AO_SKIN_PROT "Depth: AO Skin Protect" 0.60 0.0 1.0 0.05
#pragma parameter RIM_LIGHT "Light: Rim Strength" 0.65 0.0 2.0 0.05
#pragma parameter RIM_MASK_POWER "Rim Mask Threshold" 1.5 0.0 3.0 0.1
#pragma parameter LUMA_ADAPT "Engine: Luma Adaptation" 0.2 0.0 0.5 0.05
#pragma parameter HIGH_COMP "Engine: Highlight Comp" 0.5 0.0 1.0 0.1
#pragma parameter VIBRANCE "Color: Vibrance" 1.40 1.0 2.0 0.10
#pragma parameter WARMTH "Color: Warmth" 0.2 -0.50 0.50 0.05

#pragma parameter CINEMA_EXPOSURE "ACES: Exposure" 1.20 0.5 2.0 0.05
#pragma parameter AMBIENT_INJECT "ACES: Ambient Injection" 0.0 0.0 1.0 0.05
#pragma parameter CINEMA_CONTRAST "ACES: Shadow Contrast" 0.0 0.0 2.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord; attribute vec4 TexCoord; varying vec2 texCoord; uniform mat4 MVPMatrix;
void main() { gl_Position = MVPMatrix * VertexCoord; texCoord = TexCoord.xy; }

#elif defined(FRAGMENT)
precision mediump float;
varying vec2 texCoord; uniform sampler2D Texture; uniform vec2 TextureSize;
uniform float dither_str, SCAN_STR, OUTLINE_STR, MICRO_AO, AO_SKIN_PROT, RIM_LIGHT, RIM_MASK_POWER, VIBRANCE, WARMTH, HIGH_COMP, LUMA_ADAPT;
uniform float CINEMA_EXPOSURE, AMBIENT_INJECT, CINEMA_CONTRAST;

const vec3 lumaWeight = vec3(0.299, 0.587, 0.114);

void main() {
    vec2 px = 1.0 / TextureSize;
    vec3 center = texture2D(Texture, texCoord).rgb;
    vec3 col_r = texture2D(Texture, texCoord + vec2(px.x, 0.0)).rgb;
    vec3 col_u = texture2D(Texture, texCoord + vec2(0.0, px.y)).rgb;
    
    vec3 res = mix(center, (center + col_r) * 0.5, dither_str);
    float y_m = dot(res, lumaWeight);

    // [2] OUTLINE & LIGHTING
    float edge = dot(abs(res - col_r) + abs(res - col_u), vec3(0.333));
    float outlineMask = smoothstep(0.0, 0.5, edge) * clamp(1.1 - y_m, 0.0, 1.0);
    res /= (1.0 + (outlineMask * OUTLINE_STR * 1.5));

    float dist = abs(dot(col_r, lumaWeight) - dot(col_u, lumaWeight)) * 2.0;
    float rimMask = clamp(1.0 - (y_m * RIM_MASK_POWER), 0.0, 1.0); 
    res -= (dist * MICRO_AO * clamp(1.0 - y_m, 0.0, 1.0)) * step(y_m, AO_SKIN_PROT);
    res += (edge * RIM_LIGHT * 0.7 * rimMask);

    // [3] ENGINE & ACES EXTENSIONS
    res = mix(res, res + (1.0 - y_m) * LUMA_ADAPT, HIGH_COMP);

    if (AMBIENT_INJECT > 0.0) {
        vec3 ambientColor = mix(res * vec3(0.45, 0.38, 0.58), res * vec3(1.22, 0.58, 0.38), y_m);
        res = mix(res, ambientColor, AMBIENT_INJECT);
    }

    if (CINEMA_CONTRAST > 0.0) {
        res *= (1.0 + CINEMA_CONTRAST * 0.5); 
    }

    // [4] CRT SCANLINES
    float scanline = mod(gl_FragCoord.y, 2.0);
    res -= (scanline * SCAN_STR * 0.4);

    // [5] FINAL
    res *= CINEMA_EXPOSURE;
    res = mix(vec3(dot(res, lumaWeight)), res, VIBRANCE);
    res.rb += vec2(WARMTH, -WARMTH) * 0.05;
    
    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif