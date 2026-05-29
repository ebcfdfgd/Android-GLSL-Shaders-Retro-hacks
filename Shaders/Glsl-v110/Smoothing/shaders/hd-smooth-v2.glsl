/* ULTIMATE SONIC 2026 - FINAL REMAKE ENGINE EDITION + BLOOM */

#pragma parameter HD_SMOOTH "HD: Vector Smoothing" 0.80 0.0 1.0 0.05
#pragma parameter DITHER_REM "Dither Removal Strength" 1.0 0.0 2.0 0.05
#pragma parameter SCAN_STR "Scanline: Strength" 0.30 0.0 1.0 0.05
#pragma parameter OUTLINE_STR "Detail: Outline Power" 0.20 0.0 1.0 0.05
#pragma parameter MICRO_AO "Depth: Micro-AO" 0.35 0.0 1.0 0.05
#pragma parameter AO_SKIN_PROT "Depth: AO Skin Protect" 0.60 0.0 1.0 0.05
#pragma parameter RIM_LIGHT "Light: Rim Strength" 0.9 0.0 2.0 0.05
#pragma parameter RIM_MASK_POWER "Rim Mask Threshold" 1.5 0.0 3.0 0.1
#pragma parameter SHARPEN_STR "Detail: Adaptive Sharpen" 0.5 0.0 10.0 0.1
#pragma parameter BLOOM_STR "Engine: Bloom Strength" 0.2 0.0 0.8 0.05
#pragma parameter DEPTH_FADE "Engine: Depth Fade" 0.1 0.0 0.5 0.05
#pragma parameter LUMA_ADAPT "Engine: Luma Adaptation" 0.2 0.0 0.5 0.05
#pragma parameter HIGH_COMP "Engine: Highlight Comp" 0.5 0.0 1.0 0.1
#pragma parameter VIBRANCE "Color: Vibrance" 1.25 1.0 2.0 0.10
#pragma parameter WARMTH "Color: Warmth" 0.1 -0.50 0.50 0.05
#pragma parameter ACES_EXPOSURE "ACES: Cinematic Exposure" 1.25 0.50 2.0 0.05
#pragma parameter CINEMA_CONTRAST "ACES: Shadow Contrast" 1.15 1.00 2.0 0.05
#pragma parameter AMBIENT_INJECT "ACES: Ambient Injection" 0.60 0.00 1.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord; attribute vec4 TexCoord; varying vec2 texCoord; uniform mat4 MVPMatrix;
void main() { gl_Position = MVPMatrix * VertexCoord; texCoord = TexCoord.xy; }

#elif defined(FRAGMENT)
precision mediump float;
varying vec2 texCoord; uniform sampler2D Texture; uniform vec2 TextureSize;
uniform float HD_SMOOTH, DITHER_REM, SCAN_STR, OUTLINE_STR, MICRO_AO, AO_SKIN_PROT, RIM_LIGHT, RIM_MASK_POWER, SHARPEN_STR, BLOOM_STR, DEPTH_FADE, LUMA_ADAPT, HIGH_COMP, VIBRANCE, WARMTH;
uniform float ACES_EXPOSURE, CINEMA_CONTRAST, AMBIENT_INJECT;
const vec3 lumaWeight = vec3(0.299, 0.587, 0.114);

vec3 ACESFilm(vec3 x) {
    float a = 2.51; float b = 0.03; float c = 2.43; float d = 0.59; float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

void main() {
    vec2 px = 1.0 / TextureSize;
    vec2 pos = texCoord * TextureSize;
    
    // DITHER & SMOOTH
    vec2 f = fract(pos);
    vec3 c00 = texture2D(Texture, (floor(pos) + vec2(0.0, 0.0)) * px).rgb;
    vec3 c10 = texture2D(Texture, (floor(pos) + vec2(1.0, 0.0)) * px).rgb;
    vec3 c01 = texture2D(Texture, (floor(pos) + vec2(0.0, 1.0)) * px).rgb;
    vec3 c11 = texture2D(Texture, (floor(pos) + vec2(1.0, 1.0)) * px).rgb;
    vec3 res = mix(mix(c00, c10, f.x), mix(c01, c11, f.x), f.y);
    res = mix(res, (c00 + c10 + c01 + c11) * 0.25, DITHER_REM * 0.3);

    // SHARPEN & DEPTH FADE
    res = mix(res, res + (res - texture2D(Texture, texCoord + px).rgb) * SHARPEN_STR, 0.5) * (1.0 - (texCoord.y * DEPTH_FADE));

    // OUTLINE & RIM-LIGHT
    float y_m = dot(res, lumaWeight);
    vec3 col_r = texture2D(Texture, texCoord + vec2(px.x, 0.0)).rgb;
    vec3 col_u = texture2D(Texture, texCoord + vec2(px.x, px.y)).rgb;
    float edge = dot(abs(res - col_r) + abs(res - col_u), vec3(0.333));
    res += (edge * RIM_LIGHT * clamp(1.0 - (y_m * RIM_MASK_POWER), 0.0, 1.0));
    res -= (abs(dot(col_r, lumaWeight) - dot(col_u, lumaWeight)) * MICRO_AO * step(y_m, AO_SKIN_PROT));

    // BLOOM
    vec3 bloom = texture2D(Texture, texCoord + px * 1.5).rgb + texture2D(Texture, texCoord - px * 1.5).rgb;
    vec3 bloomTarget = bloom * max(0.0, y_m - 0.35);
    res += (bloomTarget * BLOOM_STR * 2.5 * y_m);

    // ENGINE ADAPTATION
    res = mix(res, res + (1.0 - y_m) * LUMA_ADAPT, HIGH_COMP);

    // AMBIENT INJECTION
    vec3 sunsetTone = vec3(1.22, 0.58, 0.38);
    vec3 shadowTone = vec3(0.45, 0.38, 0.58);
    vec3 mixedInjected = mix(res * shadowTone, res * sunsetTone, y_m);
    res = mix(res, mixedInjected, AMBIENT_INJECT);

    // CONTRAST & ACES
    res = pow(max(res, 0.0), vec3(CINEMA_CONTRAST));
    res = ACESFilm(res * ACES_EXPOSURE);

    // SCANLINES
    float scanline = mod(gl_FragCoord.y, 2.0);
    res -= (scanline * SCAN_STR * 0.4);

    // COLOR GRADE
    res = mix(vec3(dot(res, lumaWeight)), res, VIBRANCE);
    res.r += WARMTH * 0.15;
    res.g += WARMTH * 0.03;
    res.b -= WARMTH * 0.06;
    
    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif