#version 110

/* NTSC-MD-PRO TURBO (Manual Edition)
    - Fix: Removed Auto Phase Modes, strictly Manual control.
    - Logic: Independent Chroma Fetching for true Bleed effect.
    - Optimization: Enhanced pattern recognition to keep edges sharp.
*/

// --- PARAMETERS ---
#pragma parameter rb_power "Rainbow Strength" 0.1 0.0 2.0 0.01
#pragma parameter rb_size "Rainbow Width/Scale" 4.5 0.5 10.0 0.1
#pragma parameter rb_slant "Rainbow Tilt (Manual)" 0.0 -2.0 2.0 0.05
#pragma parameter rb_detect "Rainbow Edge Detect" 0.31 0.0 1.0 0.01
#pragma parameter rb_speed "Rainbow Cycle Speed" 0.1 0.0 1.0 0.01
#pragma parameter rb_sat "Rainbow Saturation" 1.0 0.0 2.0 0.05
#pragma parameter COL_BLEED "Chroma Spread (Bleed)" 5.0 0.0 20.0 0.1
#pragma parameter red_persistence "Red Persistence (Right Smear)" 1.0 0.0 2.5 0.05
#pragma parameter black_bleed "Black Level Smear" 0.2 0.0 1.0 0.01
#pragma parameter fringe_str "Edge Color Fringing" 0.4 0.0 5.0 0.1
#pragma parameter ntsc_blur "NTSC Dither Blur" 0.5 0.0 1.0 0.05
#pragma parameter jail_str "MD Vertical Jailbars" 0.15 0.0 1.0 0.01
#pragma parameter jail_width "MD Jailbar Spacing" 1.5 0.5 10.0 0.1
#pragma parameter NOISE_STR "Analog Signal Noise" 0.04 0.0 2.0 0.01
#pragma parameter JITTER "Signal Jitter (Shake)" 0.04 0.0 3.0 0.05
#pragma parameter MD_WARM "Analog Warmth" 0.05 -0.2 0.2 0.01
#pragma parameter MD_SHARP "Luma Sharpness" 0.1 0.0 2.0 0.05
#pragma parameter ntsc_hue "NTSC Tint (Hue Adjustment)" 0.0 -3.14 3.14 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord;
varying vec2 hTrig; 
uniform mat4 MVPMatrix;
uniform float ntsc_hue;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord.xy;
    hTrig = vec2(sin(ntsc_hue), cos(ntsc_hue));
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision mediump float;
#endif

varying vec2 vTexCoord;
varying vec2 hTrig;
uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform int FrameCount;

#ifdef PARAMETER_UNIFORM
uniform float rb_power, rb_size, rb_slant, rb_detect, rb_speed, rb_sat;
uniform float COL_BLEED, red_persistence, black_bleed, fringe_str, ntsc_blur, jail_str, jail_width;
uniform float MD_WARM, MD_SHARP, ntsc_hue, NOISE_STR, JITTER;
#endif

const vec3 kY = vec3(0.2989, 0.5870, 0.1140);
const vec3 kI = vec3(0.5959, -0.2744, -0.3216);
const vec3 kQ = vec3(0.2115, -0.5229, 0.3114);

float fast_rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.98, 78.23))) * 437.5);
}

void main() {
    vec2 ps = 1.0 / TextureSize;
    float time = mod(float(FrameCount), 1024.0);
    vec2 uv = vTexCoord;

    if (JITTER > 0.0) uv.x += (fast_rand(vec2(time, uv.y)) - 0.5) * JITTER * ps.x;

    // --- 1. SMART ADAPTIVE BLUR (LOGIC 1001) ---
    vec3 cM = texture2D(Texture, uv).rgb;
    vec3 cL = texture2D(Texture, uv - vec2(ps.x, 0.0)).rgb;
    vec3 cR = texture2D(Texture, uv + vec2(ps.x, 0.0)).rgb;

    float yM = dot(cM, kY);
    float yL = dot(cL, kY);
    float yR = dot(cR, kY);
    
    float is_dither = abs(yM - yL) * abs(yM - yR);
    float d_mask = clamp(is_dither * 50.0, 0.0, 1.0);
    d_mask *= clamp(1.0 - abs(yL - yR) * 5.0, 0.0, 1.0);

    vec3 col = cM;
    if (ntsc_blur > 0.0) {
        vec3 avg = (cL + cM + cR) * 0.3333;
        col = mix(cM, avg, ntsc_blur * d_mask);
    }
    float y = dot(col, kY);

    // --- 2. CHROMA BLEED ENGINE ---
    float fI = dot(col, kI);
    float fQ = dot(col, kQ);

    if (COL_BLEED > 0.1) {
        vec2 b_off = vec2(ps.x * COL_BLEED, 0.0);
        vec3 bcL = texture2D(Texture, uv - b_off).rgb;
        vec3 bcR = texture2D(Texture, uv + b_off).rgb;
        
        fI = mix(fI, (dot(bcL, kI) + dot(bcR, kI)) * 0.5, 0.7);
        fQ = mix(fQ, (dot(bcL, kQ) + dot(bcR, kQ)) * 0.5, 0.7);

        if (red_persistence > 0.0) {
            fI = mix(fI, dot(bcL, kI), 0.45 * red_persistence);
        }
    }

    // --- 3. RAINBOW (MANUAL ONLY) ---
    if (rb_power > 0.0) {
        // تم إلغاء شروط PHASE_MODE والاعتماد على rb_slant و rb_speed مباشرة
        float ang = (uv.x * TextureSize.x / rb_size) + (uv.y * TextureSize.y * rb_slant) + (time * rb_speed);
        fI += sin(ang) * rb_power * d_mask * rb_sat;
        fQ += cos(ang) * rb_power * d_mask * rb_sat;
    }

    // --- 4. LUMA DETAILS ---
    if (MD_SHARP > 0.0) y += (yM - yL) * MD_SHARP;
    if (jail_str > 0.0) y += sin(uv.x * TextureSize.x * jail_width) * jail_str * 0.02;
    if (NOISE_STR > 0.0) y += (fast_rand(uv + time * 0.01) - 0.5) * NOISE_STR;

    if (fringe_str > 0.0) {
        fI += (yM - yR) * fringe_str * 0.5;
        fQ -= (yM - yL) * fringe_str * 0.3;
    }

    // --- 5. FINAL ROTATION & ASSEMBLY ---
    float resI = fI * hTrig.y - fQ * hTrig.x;
    float resQ = fI * hTrig.x + fQ * hTrig.y;

    vec3 res = vec3(
        y + 0.956 * resI + 0.621 * resQ,
        y - 0.272 * resI - 0.647 * resQ,
        y - 1.106 * resI + 1.703 * resQ
    );

    if (MD_WARM != 0.0) res.r += MD_WARM;
    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif