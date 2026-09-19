#version 110

/* --- NTSC-MD-PRO TURBO (TRIANGLE-WAVE OPTIMIZED / NO-SIN) --- */

#pragma parameter SATURATION "NTSC Saturation" 1.0 0.0 2.0 0.05
#pragma parameter BRIGHTNESS "Signal Brightness" 1.0 0.0 2.0 0.05
#pragma parameter ntsc_hue "NTSC Tint (Hue Adjustment)" 0.0 -3.14 3.14 0.05
#pragma parameter rb_power "Rainbow Strength" 0.1 0.0 2.0 0.01
#pragma parameter rb_size "Rainbow Width/Scale" 4.5 0.5 10.0 0.1
#pragma parameter rb_slant "Rainbow Tilt (Manual)" 0.0 -2.0 2.0 0.05
#pragma parameter rb_detect "Rainbow Edge Detect" 0.31 0.0 1.0 0.01
#pragma parameter rb_speed "Rainbow Cycle Speed" 0.1 0.0 1.0 0.01
#pragma parameter rb_sat "Rainbow Saturation" 1.0 0.0 2.0 0.05
#pragma parameter COL_BLEED "Chroma Spread (Bleed)" 5.0 0.0 20.0 0.1
#pragma parameter red_persistence "Red Persistence (Right Smear)" 1.0 0.0 2.5 0.05
#pragma parameter fringe_str "Edge Color Fringing" 0.4 0.0 5.0 0.1
#pragma parameter ntsc_blur "NTSC Dither Blur" 0.5 0.0 1.0 0.05
#pragma parameter jail_str "MD Vertical Jailbars" 0.15 0.0 1.0 0.01
#pragma parameter jail_width "MD Jailbar Spacing" 1.5 0.5 10.0 0.1
#pragma parameter sig_noise "Signal RF Grain" 0.04 0.0 0.5 0.01
#pragma parameter JITTER "Signal Jitter (Shake)" 0.04 0.0 3.0 0.05
#pragma parameter MD_WARM "Analog Warmth" 0.05 -0.2 0.2 0.01
#pragma parameter MD_SHARP "Luma Sharpness" 0.1 0.0 2.0 0.05

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
    // تقريب لدالة الدوران بدون sin/cos
    hTrig = vec2(ntsc_hue * 0.9, 1.0 - (ntsc_hue * ntsc_hue * 0.5));
}

#elif defined(FRAGMENT)
precision highp float;

varying vec2 vTexCoord;
varying vec2 hTrig;
uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform int FrameCount;

uniform float SATURATION, BRIGHTNESS, rb_power, rb_size, rb_slant, rb_detect, rb_speed, rb_sat, COL_BLEED, red_persistence, fringe_str, ntsc_blur, jail_str, jail_width, MD_WARM, MD_SHARP, sig_noise, JITTER;

const vec3 kY = vec3(0.2989, 0.5870, 0.1140);
const vec3 kI = vec3(0.5959, -0.2744, -0.3216);
const vec3 kQ = vec3(0.2115, -0.5229, 0.3114);

// دالة المثلث السريعة (بديلة sin/cos)
vec2 triangle_wave(float x) {
    vec2 val = abs(fract(vec2(x * 0.159, x * 0.159 + 0.25)) * 2.0 - 1.0) * 2.0 - 1.0;
    return val;
}

// دالة ضجيج خطي سريع
float hash(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 ps = 1.0 / TextureSize;
    float time = float(FrameCount);
    vec2 uv = vTexCoord;

    if (JITTER > 0.0) uv.x += (hash(vec2(time, uv.y)) - 0.5) * JITTER * ps.x;

    vec3 cM = texture2D(Texture, uv).rgb;
    vec3 cL = texture2D(Texture, uv - vec2(ps.x, 0.0)).rgb;
    vec3 cR = texture2D(Texture, uv + vec2(ps.x, 0.0)).rgb;

    float yM = dot(cM, kY);
    float yL = dot(cL, kY);
    float yR = dot(cR, kY);
    
    float is_dither = abs(yM - yL) * abs(yM - yR);
    float d_mask = clamp(is_dither * 50.0, 0.0, 1.0) * clamp(1.0 - abs(yL - yR) * 5.0, 0.0, 1.0);

    vec3 col = (ntsc_blur > 0.0) ? mix(cM, (cL + cM + cR) * 0.3333, ntsc_blur * d_mask) : cM;
    float y = dot(col, kY);

    float fI = dot(col, kI) * SATURATION;
    float fQ = dot(col, kQ) * SATURATION;

    if (COL_BLEED > 0.1) {
        vec2 b_off = vec2(ps.x * COL_BLEED, 0.0);
        vec3 bcL = texture2D(Texture, uv - b_off).rgb;
        vec3 bcR = texture2D(Texture, uv + b_off).rgb;
        fI = mix(fI, (dot(bcL, kI) + dot(bcR, kI)) * 0.5 * SATURATION, 0.7);
        fQ = mix(fQ, (dot(bcL, kQ) + dot(bcR, kQ)) * 0.5 * SATURATION, 0.7);
        if (red_persistence > 0.0) fI = mix(fI, dot(bcL, kI) * SATURATION, 0.45 * red_persistence);
    }

    if (rb_power > 0.0) {
        float ang = (uv.x * TextureSize.x / rb_size) + (uv.y * TextureSize.y * rb_slant) + (time * rb_speed);
        vec2 wave = triangle_wave(ang);
        fI += wave.x * rb_power * d_mask * rb_sat;
        fQ += wave.y * rb_power * d_mask * rb_sat;
    }

    if (MD_SHARP > 0.0) y += (yM - yL) * MD_SHARP;
    if (jail_str > 0.0) y += triangle_wave(uv.x * jail_width * 100.0).x * jail_str * 0.02;
    if (sig_noise > 0.0) y += (fract(uv.x * uv.y * time * 1000.0) - 0.5) * sig_noise;
    
    if (fringe_str > 0.0) {
        fI += (yM - yR) * fringe_str * 0.5;
        fQ -= (yM - yL) * fringe_str * 0.3;
    }

    float resI = fI * hTrig.y - fQ * hTrig.x;
    float resQ = fI * hTrig.x + fQ * hTrig.y;

    vec3 res = vec3(
        y + 0.956 * resI + 0.621 * resQ,
        y - 0.272 * resI - 0.647 * resQ,
        y - 1.106 * resI + 1.703 * resQ
    );

    if (MD_WARM != 0.0) res.r += MD_WARM;
    res *= BRIGHTNESS;

    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif