/* ULTIMATE SONIC 2026 - PURE NATURAL (ULTRA-LIGHT GAMMA + BLOOM EDITION) */
#pragma parameter OUTLINE_STR "Detail: Outline Power" 0.70 0.0 1.0 0.05
#pragma parameter MICRO_AO "MICRO AO" 0.70 0.0 1.0 0.05
#pragma parameter RIM_LIGHT "Light: Rim Strength" 0.7 0.0 2.0 0.05
#pragma parameter SPEC_STR "Light: Specular Intensity" 0.2 0.0 2.0 0.05
#pragma parameter BLOOM_STR "Bloom Strength" 0.3 0.0 1.0 0.05
#pragma parameter BLOOM_THRES "Bloom Threshold" 0.6 0.0 1.0 0.05
#pragma parameter LUMA_ADAPT "Engine: Luma Adaptation" 0.05 0.0 0.5 0.01
#pragma parameter WARMTH "Color: Warmth" 0.2 -0.50 0.50 0.05
#pragma parameter VIBRANCE "Color: Vibrance" 1.1 -1.0 2.0 0.10
#pragma parameter C_BLK_LVL "Black Level" 0.05 -0.2 0.2 0.01
#pragma parameter C_WHT_LVL "White Level" 1.05 0.0 1.5 0.01
#pragma parameter GAMMA_BOOST "Gamma Boost" 0.0 -0.5 1.5 0.01

#if defined(VERTEX)
attribute vec4 VertexCoord; attribute vec4 TexCoord; varying vec2 texCoord; uniform mat4 MVPMatrix;
void main() { gl_Position = MVPMatrix * VertexCoord; texCoord = TexCoord.xy; }

#elif defined(FRAGMENT)
precision mediump float;
varying vec2 texCoord; uniform sampler2D Texture; uniform vec2 TextureSize;
uniform float GAMMA_BOOST, C_BLK_LVL, C_WHT_LVL, OUTLINE_STR, MICRO_AO, RIM_LIGHT, SPEC_STR, VIBRANCE, WARMTH, LUMA_ADAPT, BLOOM_STR, BLOOM_THRES;

const vec3 lumaWeight = vec3(0.299, 0.587, 0.114);

void main() {
    vec2 px = 1.0 / TextureSize;
    
    // [1] PURE CENTER PIXEL & SAMPLES
    vec3 center = texture2D(Texture, texCoord).rgb;
    vec3 col_r = texture2D(Texture, texCoord + vec2(px.x, 0.0)).rgb;
    vec3 col_u = texture2D(Texture, texCoord + vec2(0.0, px.y)).rgb;
    vec3 res = center; 

    // [2] OUTLINE & EDGE
    float y_m = dot(res, lumaWeight);
    float edge = dot(abs(res - col_r) + abs(res - col_u), vec3(0.333));
    res *= (1.0 - edge * OUTLINE_STR);
    
    // [3] LIGHTING & AO
    float dist = abs(dot(col_r, lumaWeight) - dot(col_u, lumaWeight)) * 2.0;
    
    // AO
    res -= (dist * MICRO_AO * clamp(1.0 - y_m, 0.0, 1.0));

    // Rim
    res += (edge * RIM_LIGHT);
    
    // Specular & Directional
    float spec = y_m * y_m * y_m * SPEC_STR;
    res += spec;

    // [4] ZERO-FETCH BLOOM (Using existing samples)
    vec3 bloom_sample = (center + col_r + col_u) * 0.333;
    float bloom_luma = dot(bloom_sample, lumaWeight);
    // Linear threshold calculation
    float bloom_mask = clamp((bloom_luma - BLOOM_THRES) / (1.0 - BLOOM_THRES + 0.001), 0.0, 1.0);
    res += bloom_sample * bloom_mask * BLOOM_STR;

    // [5] ENGINE ADAPTATION
    res = res + (1.0 - y_m) * LUMA_ADAPT;

    // [6] FINAL COLOR
    res = max(vec3(0.0), res - C_BLK_LVL); 
    res = res * (1.0 / max(0.001, C_WHT_LVL));
    res += (res - dot(res, lumaWeight)) * (VIBRANCE - 1.0);
    res.rb += vec2(WARMTH, -WARMTH) * 0.05;
    
    // Fast hardware-friendly Gamma approximation
    res *= (1.0 + GAMMA_BOOST * (1.0 - res));
    
    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif