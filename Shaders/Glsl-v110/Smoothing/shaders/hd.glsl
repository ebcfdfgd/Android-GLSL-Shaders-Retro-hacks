/* ULTIMATE SONIC 2026 - TWO-TAP DITHER + ZERO-FETCH BLOOM */

#pragma parameter dither_str "Dither Removal Strength" 0.8 0.0 1.0 0.05
#pragma parameter SCAN_STR "Scanline: Strength" 0.20 0.0 1.0 0.05
#pragma parameter EDGE_SHINE "Light: Edge Specular" 0.45 0.0 1.0 0.05
#pragma parameter OUTLINE_STR "Detail: Outline Power" 0.20 0.0 1.0 0.05
#pragma parameter MICRO_AO "Depth: Micro-AO" 0.35 0.0 1.0 0.05
#pragma parameter AO_SKIN_PROT "Depth: AO Skin Protect" 0.60 0.0 1.0 0.05
#pragma parameter RIM_LIGHT "Light: Rim Strength" 0.65 0.0 2.0 0.05
#pragma parameter RIM_MASK_POWER "Rim Mask Threshold" 1.5 0.0 3.0 0.1
#pragma parameter BLOOM_STR "Engine: Bloom Strength" 0.2 0.0 0.8 0.05
#pragma parameter LUMA_ADAPT "Engine: Luma Adaptation" 0.2 0.0 0.5 0.05
#pragma parameter HIGH_COMP "Engine: Highlight Comp" 0.5 0.0 1.0 0.1
#pragma parameter VIBRANCE "Color: Vibrance" 1.40 1.0 2.0 0.10
#pragma parameter WARMTH "Color: Warmth" 0.2 -0.50 0.50 0.05
#pragma parameter BLACK_DEPTH "Color: Black Depth" 0.01 -0.10 0.20 0.01

#if defined(VERTEX)
attribute vec4 VertexCoord; attribute vec4 TexCoord; varying vec2 texCoord; uniform mat4 MVPMatrix;
void main() { gl_Position = MVPMatrix * VertexCoord; texCoord = TexCoord.xy; }

#elif defined(FRAGMENT)
precision mediump float;
varying vec2 texCoord; uniform sampler2D Texture; uniform vec2 TextureSize;
uniform float dither_str, SCAN_STR, EDGE_SHINE, OUTLINE_STR, MICRO_AO, AO_SKIN_PROT, RIM_LIGHT, RIM_MASK_POWER, BLOOM_STR, VIBRANCE, WARMTH, BLACK_DEPTH,HIGH_COMP,LUMA_ADAPT;
const vec3 lumaWeight = vec3(0.299, 0.587, 0.114);

void main() {
    vec2 px = 1.0 / TextureSize;
    
    // [1] TWO-TAP DITHER REMOVAL (عينة واحدة جانبية + الأصلية)
    vec3 center = texture2D(Texture, texCoord).rgb;
    vec3 neighbor = texture2D(Texture, texCoord + vec2(px.x, 0.0)).rgb;
    vec3 res = mix(center, (center + neighbor) * 0.5, dither_str);

    // [2] BLOOM (Local High-Intensity Glow)
    float luma = dot(res, lumaWeight);
    res += (res * luma * BLOOM_STR);

    // [3] OUTLINE & EDGE
    float y_m = dot(res, lumaWeight);
    vec3 col_r = texture2D(Texture, texCoord + vec2(px.x, 0.0)).rgb;
    vec3 col_u = texture2D(Texture, texCoord + vec2(0.0, px.y)).rgb;
    float edge = dot(abs(res - col_r) + abs(res - col_u), vec3(0.333));
    res *= (1.0 - (edge * OUTLINE_STR * clamp(1.1 - y_m, 0.0, 1.0)));

    // [4] LIGHTING & AO
    float dist = abs(dot(col_r, lumaWeight) - dot(col_u, lumaWeight)) * 2.0;
    float rimMask = clamp(1.0 - (y_m * RIM_MASK_POWER), 0.0, 1.0); 
    res -= (dist * MICRO_AO * clamp(1.0 - y_m, 0.0, 1.0)) * step(y_m, AO_SKIN_PROT);
    res += (edge * RIM_LIGHT * 0.7 * rimMask) + (dist * EDGE_SHINE * clamp((dot(col_r, lumaWeight) - y_m), 0.0, 1.0));

    // [5] ENGINE ADAPTATION
    res = mix(res, res + (1.0 - y_m) * LUMA_ADAPT, HIGH_COMP);

    // [5] SCANLINES
    float scan = sin(texCoord.y * TextureSize.y * 6.28) * 0.5 + 0.5;
    res -= scan * SCAN_STR * 0.3;

    // [6] FINAL COLOR
    res = mix(vec3(dot(res, lumaWeight)), res, VIBRANCE);
    res.rb += vec2(WARMTH, -WARMTH) * 0.05;
    gl_FragColor = vec4(clamp(res - BLACK_DEPTH, 0.0, 1.0), 1.0);
}
#endif