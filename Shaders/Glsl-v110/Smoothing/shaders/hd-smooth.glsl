/* ULTIMATE SONIC 2026 - ULTIMATE PRO EDITION + MASK THRESHOLD
    - Feature: Masked Rim-Light (Adjustable Threshold), Adaptive Sharpening.
    - Detail: Zero-Artifacts, Rich Contrast, Pixel-Perfect.
*/

#pragma parameter HD_SMOOTH "HD: Vector Smoothing" 0.80 0.0 1.0 0.05
#pragma parameter DITHER_REM "Dither Removal Strength" 1.0 0.0 2.0 0.05
#pragma parameter SCAN_STR "Scanline: Strength" 0.30 0.0 1.0 0.05
#pragma parameter EDGE_SHINE "Light: Edge Specular" 0.45 0.0 1.0 0.05
#pragma parameter OUTLINE_STR "Detail: Outline Power" 0.20 0.0 1.0 0.05
#pragma parameter MICRO_AO "Depth: Micro-AO" 0.35 0.0 1.0 0.05
#pragma parameter AO_SKIN_PROT "Depth: AO Skin Protect" 0.60 0.0 1.0 0.05
#pragma parameter RIM_LIGHT "Light: Rim Strength" 0.9 0.0 2.0 0.05
#pragma parameter RIM_MASK_POWER "Rim Mask Threshold" 1.5 0.0 3.0 0.1
#pragma parameter VIBRANCE "Color: Vibrance" 1.25 1.0 2.0 0.10
#pragma parameter WARMTH "Color: Warmth" 0.1 -0.50 0.50 0.05
#pragma parameter BLACK_DEPTH "Color: Black Depth" 0.01 -0.10 0.20 0.01

#if defined(VERTEX)
attribute vec4 VertexCoord; attribute vec4 TexCoord; varying vec2 texCoord; uniform mat4 MVPMatrix;
void main() { gl_Position = MVPMatrix * VertexCoord; texCoord = TexCoord.xy; }

#elif defined(FRAGMENT)
precision mediump float;
varying vec2 texCoord; uniform sampler2D Texture; uniform vec2 TextureSize;
uniform float HD_SMOOTH, DITHER_REM, SCAN_STR, EDGE_SHINE, OUTLINE_STR, MICRO_AO, AO_SKIN_PROT, RIM_LIGHT, RIM_MASK_POWER, VIBRANCE, WARMTH, BLACK_DEPTH;
const vec3 lumaWeight = vec3(0.299, 0.587, 0.114);

void main() {
    vec2 px = 1.0 / TextureSize;
    vec2 pos = texCoord * TextureSize;
    
    // [1] DITHER REMOVE & VECTOR SMOOTHING
    vec2 f = fract(pos);
    vec2 smooth_f = smoothstep(0.5 - (HD_SMOOTH * 0.5), 0.5 + (HD_SMOOTH * 0.5), f);
    vec3 c00 = texture2D(Texture, (floor(pos) + vec2(0.0, 0.0)) * px).rgb;
    vec3 c10 = texture2D(Texture, (floor(pos) + vec2(1.0, 0.0)) * px).rgb;
    vec3 c01 = texture2D(Texture, (floor(pos) + vec2(0.0, 1.0)) * px).rgb;
    vec3 c11 = texture2D(Texture, (floor(pos) + vec2(1.0, 1.0)) * px).rgb;
    
    vec3 avg = (c00 + c10 + c01 + c11) * 0.25;
    vec3 res = mix(mix(c00, c10, smooth_f.x), mix(c01, c11, smooth_f.x), smooth_f.y);
    res = mix(res, avg, DITHER_REM * 0.3);
    
    float d1 = dot(abs(c00 - c11), vec3(0.333));
    float d2 = dot(abs(c10 - c01), vec3(0.333));
    if (d1 < d2) res = mix(res, mix(c00, c11, 0.5), HD_SMOOTH * 0.5);
    else res = mix(res, mix(c10, c01, 0.5), HD_SMOOTH * 0.5);

    // [3] OUTLINE & EDGE
    float y_m = dot(res, lumaWeight);
    vec3 col_r = texture2D(Texture, texCoord + vec2(px.x, 0.0)).rgb;
    vec3 col_u = texture2D(Texture, texCoord + vec2(0.0, px.y)).rgb;
    float edge = dot(abs(res - col_r) + abs(res - col_u), vec3(0.333));
    res *= (1.0 - (edge * OUTLINE_STR * clamp(1.1 - y_m, 0.0, 1.0)));

    // [4] LIGHTING & AO (Adjustable Threshold Rim-Light)
    float dist = abs(dot(col_r, lumaWeight) - dot(col_u, lumaWeight)) * 2.0;
    
    // استخدام العتبة المتغيرة للتحكم في قناع اللمعة
    float rimMask = clamp(1.0 - (y_m * RIM_MASK_POWER), 0.0, 1.0); 
    
    res -= (dist * MICRO_AO * clamp(1.0 - y_m, 0.0, 1.0)) * step(y_m, AO_SKIN_PROT);
    res += (edge * RIM_LIGHT * 0.7 * rimMask) + (dist * EDGE_SHINE * clamp((dot(col_r, lumaWeight) - y_m), 0.0, 1.0));

    // [5] SCANLINES (CRT Sync)
    float pixel_y = (texCoord.y + 0.5) * TextureSize.y;
    float scan = sin(pixel_y * 6.283185) * 0.5 + 0.5;
    res *= mix(1.0, scan, SCAN_STR);

    // [6] FINAL COLOR & SHARPENING PASS
    res = mix(vec3(dot(res, lumaWeight)), res, VIBRANCE);
    res.rb += vec2(WARMTH, -WARMTH) * 0.05;
    
    gl_FragColor = vec4(clamp(res - BLACK_DEPTH, 0.0, 1.0), 1.0);
}
#endif