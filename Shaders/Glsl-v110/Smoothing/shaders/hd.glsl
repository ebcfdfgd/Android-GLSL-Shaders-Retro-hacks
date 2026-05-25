/* ULTIMATE SONIC 2026 - SMART DITHER + MASKED RIM EDITION
    - Feature: Smart Dither 16 + Adaptive Rim Masking (No White Blobs).
    - Detail: Outline, Lighting, and Micro-AO preserved.
*/

#pragma parameter ntsc_blur "Smart Dither Intensity" 0.5 0.0 1.0 0.05
#pragma parameter SCAN_STR "Scanline: Strength" 0.20 0.0 1.0 0.05
#pragma parameter EDGE_SHINE "Light: Edge Specular" 0.45 0.0 1.0 0.05
#pragma parameter OUTLINE_STR "Detail: Outline Power" 0.20 0.0 1.0 0.05
#pragma parameter MICRO_AO "Depth: Micro-AO" 0.35 0.0 1.0 0.05
#pragma parameter AO_SKIN_PROT "Depth: AO Skin Protect" 0.60 0.0 1.0 0.05
#pragma parameter RIM_LIGHT "Light: Rim Strength" 0.65 0.0 2.0 0.05
#pragma parameter RIM_MASK_POWER "Rim Mask Threshold" 1.5 0.0 3.0 0.1
#pragma parameter VIBRANCE "Color: Vibrance" 1.40 1.0 2.0 0.10
#pragma parameter WARMTH "Color: Warmth" 0.0 -0.50 0.50 0.05
#pragma parameter BLACK_DEPTH "Color: Black Depth" 0.01 -0.10 0.20 0.01

#if defined(VERTEX)
attribute vec4 VertexCoord; attribute vec4 TexCoord; varying vec2 texCoord; uniform mat4 MVPMatrix;
void main() { gl_Position = MVPMatrix * VertexCoord; texCoord = TexCoord.xy; }

#elif defined(FRAGMENT)
precision mediump float;
varying vec2 texCoord; uniform sampler2D Texture; uniform vec2 TextureSize;
uniform float ntsc_blur, SCAN_STR, EDGE_SHINE, OUTLINE_STR, MICRO_AO, AO_SKIN_PROT, RIM_LIGHT, RIM_MASK_POWER, VIBRANCE, WARMTH, BLACK_DEPTH;
const vec3 lumaWeight = vec3(0.299, 0.587, 0.114);

void main() {
    vec2 px = 1.0 / TextureSize;
    vec3 cM = texture2D(Texture, texCoord).rgb;
    vec3 cL = texture2D(Texture, texCoord - vec2(px.x, 0.0)).rgb;
    vec3 cR = texture2D(Texture, texCoord + vec2(px.x, 0.0)).rgb;
    
    float yM = dot(cM, lumaWeight);
    float d_mask = clamp(abs(yM - dot(cL, lumaWeight)) * abs(yM - dot(cR, lumaWeight)) * 50.0, 0.0, 1.0);
    vec3 res = mix(cM, (cL + cM + cR) * 0.333, ntsc_blur * d_mask);

    // [3] OUTLINE & EDGE
    float y_m = dot(res, lumaWeight);
    vec3 col_r = texture2D(Texture, texCoord + vec2(px.x, 0.0)).rgb;
    vec3 col_u = texture2D(Texture, texCoord + vec2(0.0, px.y)).rgb;
    float edge = dot(abs(res - col_r) + abs(res - col_u), vec3(0.333));
    res *= (1.0 - (edge * OUTLINE_STR * clamp(1.1 - y_m, 0.0, 1.0)));

    // [4] LIGHTING & AO WITH ADAPTIVE MASK
    float dist = abs(dot(col_r, lumaWeight) - dot(col_u, lumaWeight)) * 2.0;
    
    // هنا قمنا بدمج العتبة (Threshold) للتحكم في ظهور الـ Rim
    float rimMask = clamp(1.0 - (y_m * RIM_MASK_POWER), 0.0, 1.0); 
    
    res -= (dist * MICRO_AO * clamp(1.0 - y_m, 0.0, 1.0)) * step(y_m, AO_SKIN_PROT);
    res += (edge * RIM_LIGHT * 0.7 * rimMask) + (dist * EDGE_SHINE * clamp((dot(col_r, lumaWeight) - y_m), 0.0, 1.0));

    // [5] SCANLINES
    float scan = sin(texCoord.y * TextureSize.y * 6.28) * 0.5 + 0.5;
    res -= scan * SCAN_STR * 0.3;

    // [6] FINAL COLOR
    res = mix(vec3(dot(res, lumaWeight)), res, VIBRANCE);
    res.rb += vec2(WARMTH, -WARMTH) * 0.05;
    gl_FragColor = vec4(clamp(res - BLACK_DEPTH, 0.0, 1.0), 1.0);
}
#endif