/* 777-NTSC-MEGA-LITE-CLEAN (9-TAP ADVANCED PATTERN EDITION)
    - COMPONENT SPLIT: 4 Dither Taps + 5 Chroma Taps = 9 Total Fetches.
    - ENHANCEMENT: Advanced checkerboard pattern and edge protection logic.
*/

#pragma parameter NTSC_BRIGHTNESS "Signal Brightness" 1.0 0.0 2.0 0.05
#pragma parameter SATURATION "Global Saturation" 1.0 0.0 2.0 0.05
#pragma parameter COL_BLEED "Chroma Bleed Strength" 1.5 0.0 5.0 0.05
#pragma parameter rb_power "Rainbow Strength" 0.15 0.0 2.0 0.01
#pragma parameter rb_size "Rainbow Width" 3.0 0.5 10.0 0.1
#pragma parameter rb_detect "Rainbow Detection" 0.30 0.0 1.0 0.01
#pragma parameter rb_speed "Rainbow Crawl Speed" 0.5 0.0 2.0 0.05
#pragma parameter rb_tilt "Rainbow Diagonal Tilt" 0.5 -2.0 2.0 0.1
#pragma parameter de_dither "MD De-Dither Intensity" 1.0 0.0 2.0 0.1

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
uniform float NTSC_BRIGHTNESS, SATURATION, COL_BLEED, rb_power, rb_size, rb_detect, rb_speed, rb_tilt, de_dither;
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

// Ultra-fast Triangle Wave for Rainbow modulation
vec2 triangle_wave(float x) {
    vec2 val = abs(fract(vec2(x * 0.159, x * 0.159 + 0.25)) * 2.0 - 1.0) * 2.0 - 1.0;
    return val;
}

void main() {
    vec2 ps = vec2(1.0 / TextureSize.x, 0.0);
    float time = float(FrameCount);

    // =================================================================
    // 9 FETCHES ARCHITECTURE (4 DITHER TAPS + 5 CHROMA TAPS)
    // =================================================================
    
    // [A] 4 Dither Fetches (Symmetric Horizontal Array)
    float d_step = max(de_dither, 1.0);
    vec3 cL2 = texture2D(Texture, vTexCoord - ps * 2.0 * d_step).rgb;
    vec3 cL1 = texture2D(Texture, vTexCoord - ps * 1.0 * d_step).rgb;
    vec3 cR1 = texture2D(Texture, vTexCoord + ps * 1.0 * d_step).rgb;
    vec3 cR2 = texture2D(Texture, vTexCoord + ps * 2.0 * d_step).rgb;

    // [B] 5 Chroma Fetches (Center + 4 Wide-Bleed Taps)
    float c_step = max(COL_BLEED, 1.0);
    vec3 cM   = texture2D(Texture, vTexCoord).rgb;
    vec3 cbL2 = texture2D(Texture, vTexCoord - ps * 2.0 * c_step).rgb;
    vec3 cbL1 = texture2D(Texture, vTexCoord - ps * 1.0 * c_step).rgb;
    vec3 cbR1 = texture2D(Texture, vTexCoord + ps * 1.0 * c_step).rgb;
    vec3 cbR2 = texture2D(Texture, vTexCoord + ps * 2.0 * c_step).rgb;

    // =================================================================
    // ADVANCED PATTERN DETECTION & DITHER PROCESSING
    // =================================================================
    const vec3 lumaWeight = vec3(0.299, 0.587, 0.114);
    float yM  = dot(cM, lumaWeight);
    float yL1 = dot(cL1, lumaWeight);
    float yR1 = dot(cR1, lumaWeight);
    float yL2 = dot(cL2, lumaWeight);
    float yR2 = dot(cR2, lumaWeight);

    // Advanced Mesh/Checkerboard Pattern Recognition
    float pattern = abs(yM - yL1) * abs(yM - yR1) * 50.0;
    
    // Macro edge protection (Disables blending on real sharp visual edges)
    float edge_protection = clamp(1.0 - abs(yL1 - yR1) * 4.0, 0.0, 1.0);
    float dither_mask = clamp(pattern, 0.0, 1.0) * edge_protection * clamp(de_dither, 0.0, 1.0);

    // High quality 4-tap smart dither blending
    vec3 dither_avg = (cL2 + cL1 * 2.0 + cR1 * 2.0 + cR2) / 6.0;
    vec3 blended_rgb = mix(cM, dither_avg, dither_mask);
    float final_y = dot(blended_rgb, lumaWeight) * NTSC_BRIGHTNESS;

    // =================================================================
    // 5-TAP CHROMA BLEED & RAINBOW EFFECT
    // =================================================================
    vec3 yiqM  = RGB_to_YIQ * cM;
    vec3 yiqL2 = RGB_to_YIQ * cbL2;
    vec3 yiqL1 = RGB_to_YIQ * cbL1;
    vec3 yiqR1 = RGB_to_YIQ * cbR1;
    vec3 yiqR2 = RGB_to_YIQ * cbR2;

    // 5-tap smooth binomial blur for I & Q components
    float fI = (yiqL2.y + yiqL1.y * 2.0 + yiqM.y * 3.0 + yiqR1.y * 2.0 + yiqR2.y) / 9.0;
    float fQ = (yiqL2.z + yiqL1.z * 2.0 + yiqM.z * 3.0 + yiqR1.z * 2.0 + yiqR2.z) / 9.0;

    fI = mix(yiqM.y, fI, clamp(COL_BLEED, 0.0, 1.0));
    fQ = mix(yiqM.z, fQ, clamp(COL_BLEED, 0.0, 1.0));

    // Optimized Rainbow Generation using enhanced luma metrics
    if (rb_power > 0.0) {
        float edge = abs(yM - yL1) + abs(yM - yR1);
        float mask = smoothstep(rb_detect, rb_detect + 0.1, edge);
        
        float ang = (vTexCoord.x * TextureSize.x / rb_size) + (vTexCoord.y * TextureSize.y * rb_tilt) + (time * rb_speed);
        vec2 wave = triangle_wave(ang);
        
        fI += wave.x * rb_power * mask;
        fQ += wave.y * rb_power * mask;
    }

    // =================================================================
    // RECONSTRUCTION & FINAL OUTPUT
    // =================================================================
    vec3 res = YIQ_to_RGB * vec3(final_y, fI * SATURATION, fQ * SATURATION);

    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif