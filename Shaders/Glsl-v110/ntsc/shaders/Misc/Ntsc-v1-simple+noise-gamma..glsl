#version 110

/* 777-NTSC-MEGA-LITE-CLEAN (TRIANGLE-WAVE OPTIMIZED)
    - FIXED: Removed sin/cos for performance where possible.
    - OPTIMIZED: Triangle wave for Rainbow effect.
    - ADDED: High-precision Hash RF Grain (Namash) & Black Level.
    - ADDED: Broken Cable Static (Horizontal Sync Noise).
    - ADDED: NTSC Hue Rotation & Gamma Correction.
*/

#pragma parameter NTSC_BRIGHTNESS "Signal Brightness" 1.0 0.0 2.0 0.05
#pragma parameter SATURATION "Global Saturation" 1.0 0.0 2.0 0.05
#pragma parameter BLACK_LEVEL "Black Level" 0.0 -0.5 0.5 0.01
#pragma parameter ntsc_hue "NTSC Color Hue" 0.0 -3.14 3.14 0.05
#pragma parameter NTSC_GAMMA "Signal Gamma" 1.0 0.1 3.0 0.05
#pragma parameter COL_BLEED "Chroma Bleed Strength" 1.5 0.0 5.0 0.05
#pragma parameter rb_power "Rainbow Strength" 0.15 0.0 2.0 0.01
#pragma parameter rb_size "Rainbow Width" 3.0 0.5 10.0 0.1
#pragma parameter rb_detect "Rainbow Detection" 0.30 0.0 1.0 0.01
#pragma parameter rb_speed "Rainbow Crawl Speed" 0.5 0.0 2.0 0.05
#pragma parameter rb_tilt "Rainbow Diagonal Tilt" 0.5 -2.0 2.0 0.1
#pragma parameter de_dither "MD De-Dither Intensity" 1.0 0.0 2.0 0.1
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
uniform float NTSC_BRIGHTNESS, SATURATION, BLACK_LEVEL, ntsc_hue, NTSC_GAMMA, COL_BLEED, rb_power, rb_size, rb_detect, rb_speed, rb_tilt, de_dither, sig_noise, cable_glitch;
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

    vec3 cM = texture2D(Texture, vTexCoord).rgb;
    float d_off = max(de_dither, 1.0);
    vec3 cL = texture2D(Texture, vTexCoord - ps * d_off).rgb;
    vec3 cR = texture2D(Texture, vTexCoord + ps * d_off).rgb;

    vec3 yiqM = RGB_to_YIQ * cM;
    vec3 yiqL = RGB_to_YIQ * cL;
    vec3 yiqR = RGB_to_YIQ * cR;

    float final_y = (de_dither > 0.0) ? mix(yiqM.x, (yiqL.x + yiqR.x) * 0.5, 0.5 * de_dither) : yiqM.x;
    final_y *= NTSC_BRIGHTNESS;

    // Apply broken cable static lines to Luma
    final_y -= static_lines * 0.4;

    float fI = yiqM.y;
    float fQ = yiqM.z;

    // Inject static lines into Chroma
    fI -= static_lines * 0.15;
    fQ += static_lines * 0.15;

    if (COL_BLEED > 0.0) {
        vec2 b_off = ps * COL_BLEED * 1.5; 
        vec3 bcL = RGB_to_YIQ * texture2D(Texture, vTexCoord - b_off).rgb;
        vec3 bcR = RGB_to_YIQ * texture2D(Texture, vTexCoord + b_off).rgb;
        fI = mix(fI, (bcL.y + bcR.y) * 0.5, 0.7);
        fQ = mix(fQ, (bcL.z + bcR.z) * 0.5, 0.7);
    }

    if (rb_power > 0.0) {
        float edge = abs(yiqM.x - yiqL.x) + abs(yiqM.x - yiqR.x);
        float mask = smoothstep(rb_detect, rb_detect + 0.1, edge);
        
        float ang = (vTexCoord.x * TextureSize.x / rb_size) + (vTexCoord.y * TextureSize.y * rb_tilt) + (time * rb_speed);
        vec2 wave = triangle_wave(ang);
        
        // Cable glitch amplifies the rainbow artifacts on edges
        fI += wave.x * rb_power * (mask + static_lines * 0.5);
        fQ += wave.y * rb_power * (mask + static_lines * 0.5);
    }

    // High-precision Hash RF Grain (Namash)
    if (sig_noise > 0.0) {
        final_y += (hash(vTexCoord + time * 0.01) - 0.5) * sig_noise;
    }

    // NTSC Hue Control rotation matrix calculation
    float h_sin = sin(ntsc_hue);
    float h_cos = cos(ntsc_hue);
    float resI = (fI * h_cos - fQ * h_sin) * SATURATION;
    float resQ = (fI * h_sin + fQ * h_cos) * SATURATION;

    vec3 res = YIQ_to_RGB * vec3(final_y, resI, resQ);

    // Black Level Adjustment
    res = mix(vec3(BLACK_LEVEL), vec3(1.0), res);

    // Gamma Correction
    res = pow(max(res, vec3(0.0)), vec3(1.0 / NTSC_GAMMA));

    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif