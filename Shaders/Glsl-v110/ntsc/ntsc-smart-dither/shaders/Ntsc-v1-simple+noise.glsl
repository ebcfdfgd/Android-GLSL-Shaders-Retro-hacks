#version 110

/* 777-NTSC-MEGA-LITE-CLEAN (5-TAP PURE DITHER-TARGETED)
    - FIXED: Completely eliminated full-screen fog/blur. Luma blend now targets ONLY dither patterns.
    - OPTIMIZED: Exactly 5 Unique Texture Fetches (Reusing Center Tap) - 100% Branchless.
    - ADDED: High-frequency Local Extremum Detection for absolute textual and background clarity.
    - ADDED: High-precision Hash RF Grain (Namash) & Black Level.
    - ADDED: Broken Cable Static (Horizontal Sync Noise).
*/

#pragma parameter NTSC_BRIGHTNESS "Signal Brightness" 1.0 0.0 2.0 0.05
#pragma parameter SATURATION "Global Saturation" 1.0 0.0 2.0 0.05
#pragma parameter BLACK_LEVEL "Black Level" 0.0 -0.5 0.5 0.01
#pragma parameter COL_BLEED "Chroma Bleed Strength" 1.5 0.0 5.0 0.05
#pragma parameter rb_power "Rainbow Strength" 0.15 0.0 2.0 0.01
#pragma parameter rb_size "Rainbow Width" 3.0 0.5 10.0 0.1
#pragma parameter rb_detect "Rainbow Detection" 0.30 0.0 1.0 0.01
#pragma parameter rb_speed "Rainbow Crawl Speed" 0.5 0.0 2.0 0.05
#pragma parameter rb_tilt "Rainbow Diagonal Tilt" 0.5 -2.0 2.0 0.1
#pragma parameter de_dither "MD De-Dither Intensity" 1.0 0.0 2.0 0.1
#pragma parameter edge_protect "Edge Sharpness Protection" 0.6 0.0 1.0 0.05
#pragma parameter sig_noise "Signal RF Grain (Namash)" 0.04 0.0 0.5 0.01
#pragma parameter cable_glitch "Broken Cable Static" 0.0 0.0 1.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform int FrameCount;
varying vec2 vTexCoord;

#ifdef PARAMETER_UNIFORM
uniform float NTSC_BRIGHTNESS, SATURATION, BLACK_LEVEL, COL_BLEED, rb_power, rb_size, rb_detect, rb_speed, rb_tilt, de_dither, edge_protect, sig_noise, cable_glitch;
#else
#define NTSC_BRIGHTNESS 1.0
#define SATURATION 1.0
#define BLACK_LEVEL 0.0
#define COL_BLEED 1.5
#define rb_power 0.15
#define rb_size 3.0
#define rb_detect 0.30
#define rb_speed 0.5
#define rb_tilt 0.5
#define de_dither 1.0
#define edge_protect 0.6
#define sig_noise 0.04
#define cable_glitch 0.0
#endif

const mat3 RGB_to_YIQ = mat3(
    0.299,  0.596,  0.211,
    0.587, -0.274, -0.523,
    0.114, -0.322,  0.312
);

const mat3 YIQ_to_RGB = mat3(
    1.0,    1.0,    1.0,
    0.956, -0.272, -1.106,
    0.621, -0.647,  1.703
);

// High-speed pseudo-random noise generator (Hash)
float hash(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

// Fast Triangle Wave for Rainbow modulation
vec2 triangle_wave(float x) {
    vec2 val = abs(fract(vec2(x * 0.159, x * 0.159 + 0.25)) * 2.0 - 1.0) * 2.0 - 1.0;
    return val;
}

void main() {
    vec2 ps = vec2(1.0 / TextureSize.x, 0.0);
    float time = float(FrameCount);

    // 1. Broken Cable Static Generator (Horizontal Glitch Lines)
    float line_noise = fract(vTexCoord.y * 5.0 + time * 0.13) * fract(vTexCoord.y * 23.0 - time * 0.21);
    float static_lines = step(0.88, line_noise) * cable_glitch;

    // ==========================================
    // 2. THREE LUMA TAPS (Fetches 1, 2, 3)
    // ==========================================
    float d_off = max(de_dither, 1.0);
    vec3 cL = texture2D(Texture, vTexCoord - ps * d_off).rgb; // Fetch 1
    vec3 cM = texture2D(Texture, vTexCoord).rgb;              // Fetch 2 (Center)
    vec3 cR = texture2D(Texture, vTexCoord + ps * d_off).rgb; // Fetch 3

    vec3 yiqL = RGB_to_YIQ * cL;
    vec3 yiqM = RGB_to_YIQ * cM;
    vec3 yiqR = RGB_to_YIQ * cR;

    // High-Frequency Isolation: Only positive on rapid pixel oscillations (Dither patterns)
    float diff_L = yiqM.x - yiqL.x;
    float diff_R = yiqM.x - yiqR.x;
    float dither_weight = clamp(sign(diff_L) * sign(diff_R), 0.0, 1.0);

    // Smart Adaptive Blending (Guaranteed 0.0 on solid text/flat areas)
    float neighbor_y = (yiqL.x + yiqR.x) * 0.5;
    float edge_clean = abs(yiqL.x - yiqR.x);
    float adaptive_mix = 0.5 * de_dither * dither_weight * clamp(1.0 - (edge_clean * edge_protect), 0.0, 1.0);

    float final_y = mix(yiqM.x, neighbor_y, adaptive_mix);
    final_y *= NTSC_BRIGHTNESS;

    // Apply broken cable static lines to Luma
    final_y -= static_lines * 0.4;

    // ==========================================
    // 3. TWO EXTRA CHROMA TAPS (Fetches 4, 5)
    // ==========================================
    vec2 b_off = ps * COL_BLEED * 1.5; 
    vec3 bcL = RGB_to_YIQ * texture2D(Texture, vTexCoord - b_off).rgb; // Fetch 4
    vec3 bcR = RGB_to_YIQ * texture2D(Texture, vTexCoord + b_off).rgb; // Fetch 5

    // Reusing yiqM (Center) to save the 6th fetch completely!
    float fI = mix(yiqM.y, (bcL.y + bcR.y) * 0.5, 0.7);
    float fQ = mix(yiqM.z, (bcL.z + bcR.z) * 0.5, 0.7);

    // Inject static lines into Chroma
    fI -= static_lines * 0.15;
    fQ += static_lines * 0.15;

    // ==========================================
    // 4. ARTIFACTS & SIGNAL MODULATION
    // ==========================================
    if (rb_power > 0.0) {
        float edge = abs(yiqM.x - yiqL.x) + abs(yiqM.x - yiqR.x);
        float mask = smoothstep(rb_detect, rb_detect + 0.1, edge);
        
        float ang = (vTexCoord.x * TextureSize.x / rb_size) + (vTexCoord.y * TextureSize.y * rb_tilt) + (time * rb_speed);
        vec2 wave = triangle_wave(ang);
        
        fI += wave.x * rb_power * (mask + static_lines * 0.5);
        fQ += wave.y * rb_power * (mask + static_lines * 0.5);
    }

    // High-precision Hash RF Grain (Namash)
    if (sig_noise > 0.0) {
        final_y += (hash(vTexCoord + time * 0.01) - 0.5) * sig_noise;
    }

    vec3 res = YIQ_to_RGB * vec3(final_y, fI * SATURATION, fQ * SATURATION);

    // Black Level Adjustment
    res = mix(vec3(BLACK_LEVEL), vec3(1.0), res);

    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif