/* ULTIMATE SONIC 2026 - FINAL REMAKE ENGINE EDITION + BLOOM */

#pragma parameter HD_SMOOTH "HD: Vector Smoothing" 0.80 0.0 1.0 0.05
#pragma parameter DITHER_REM "Dither Removal Strength" 1.0 0.0 2.0 0.05
#pragma parameter SCAN_STR "Scanline: Strength" 0.30 0.0 1.0 0.05
#pragma parameter EDGE_SHINE "Light: Edge Specular" 0.45 0.0 1.0 0.05
#pragma parameter OUTLINE_STR "Detail: Outline Power" 0.20 0.0 1.0 0.05
#pragma parameter MICRO_AO "Depth: Micro-AO" 0.35 0.0 1.0 0.05
#pragma parameter AO_SKIN_PROT "Depth: AO Skin Protect" 0.60 0.0 1.0 0.05
#pragma parameter RIM_LIGHT "Light: Rim Strength" 0.9 0.0 2.0 0.05
#pragma parameter RIM_MASK_POWER "Rim Mask Threshold" 1.5 0.0 3.0 0.1
#pragma parameter SHARPEN_STR "Detail: Adaptive Sharpen" 0.5 0.0 1.0 0.05
#pragma parameter BLOOM_STR "Engine: Bloom Strength" 0.2 0.0 0.8 0.05
#pragma parameter DEPTH_FADE "Engine: Depth Fade" 0.1 0.0 0.5 0.05
#pragma parameter LUMA_ADAPT "Engine: Luma Adaptation" 0.2 0.0 0.5 0.05
#pragma parameter HIGH_COMP "Engine: Highlight Comp" 0.5 0.0 1.0 0.1
#pragma parameter VIBRANCE "Color: Vibrance" 1.25 1.0 2.0 0.10
#pragma parameter WARMTH "Color: Warmth" 0.1 -0.50 0.50 0.05
#pragma parameter BLACK_DEPTH "Color: Black Depth" 0.01 -0.10 0.20 0.01

#if defined(VERTEX)
attribute vec4 VertexCoord; attribute vec4 TexCoord; varying vec2 texCoord; uniform mat4 MVPMatrix;
void main() { gl_Position = MVPMatrix * VertexCoord; texCoord = TexCoord.xy; }

#elif defined(FRAGMENT)
precision mediump float;
varying vec2 texCoord; uniform sampler2D Texture; uniform vec2 TextureSize;
uniform float HD_SMOOTH, DITHER_REM, SCAN_STR, EDGE_SHINE, OUTLINE_STR, MICRO_AO, AO_SKIN_PROT, RIM_LIGHT, RIM_MASK_POWER, SHARPEN_STR, BLOOM_STR, DEPTH_FADE, LUMA_ADAPT, HIGH_COMP, VIBRANCE, WARMTH, BLACK_DEPTH;
const vec3 lumaWeight = vec3(0.299, 0.587, 0.114);

void main() {
    vec2 px = 1.0 / TextureSize;
    vec2 pos = texCoord * TextureSize;
    
    // [1] DITHER & SMOOTH
    vec2 f = fract(pos);
    vec3 c00 = texture2D(Texture, (floor(pos) + vec2(0.0, 0.0)) * px).rgb;
    vec3 c10 = texture2D(Texture, (floor(pos) + vec2(1.0, 0.0)) * px).rgb;
    vec3 c01 = texture2D(Texture, (floor(pos) + vec2(0.0, 1.0)) * px).rgb;
    vec3 c11 = texture2D(Texture, (floor(pos) + vec2(1.0, 1.0)) * px).rgb;
    
    vec3 res = mix(mix(c00, c10, f.x), mix(c01, c11, f.x), f.y);
    res = mix(res, (c00 + c10 + c01 + c11) * 0.25, DITHER_REM * 0.3);

    // [2] SHARPEN & DEPTH FADE
    res = mix(res, res + (res - texture2D(Texture, texCoord + px).rgb) * SHARPEN_STR, 0.5) * (1.0 - (texCoord.y * DEPTH_FADE));

    // [3] OUTLINE & RIM-LIGHT
    float y_m = dot(res, lumaWeight);
    vec3 col_r = texture2D(Texture, texCoord + vec2(px.x, 0.0)).rgb;
    vec3 col_u = texture2D(Texture, texCoord + vec2(px.x, px.y)).rgb;
    float edge = dot(abs(res - col_r) + abs(res - col_u), vec3(0.333));
    res += (edge * RIM_LIGHT * clamp(1.0 - (y_m * RIM_MASK_POWER), 0.0, 1.0));
    res -= (abs(dot(col_r, lumaWeight) - dot(col_u, lumaWeight)) * MICRO_AO * step(y_m, AO_SKIN_PROT));

    // [4] BLOOM (Box Blur Sampling)
    vec3 bloom = texture2D(Texture, texCoord + px * 1.5).rgb + texture2D(Texture, texCoord - px * 1.5).rgb;
    res += (bloom * BLOOM_STR * y_m);

    // [5] ENGINE ADAPTATION
    res = mix(res, res + (1.0 - y_m) * LUMA_ADAPT, HIGH_COMP);

    // [6] SCANLINES
    res *= mix(1.0, sin(texCoord.y * TextureSize.y * 6.283185) * 0.5 + 0.5, SCAN_STR);

    // [7] COLOR GRADE
    res = mix(vec3(dot(res, lumaWeight)), res, VIBRANCE);
    res.rb += vec2(WARMTH, -WARMTH) * 0.1;
    gl_FragColor = vec4(clamp(res - BLACK_DEPTH, 0.0, 1.0), 1.0);
}
#endif