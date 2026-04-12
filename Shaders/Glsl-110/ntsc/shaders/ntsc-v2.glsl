#version 110

/*
    NTSC-MD-PRO: Mega Drive Analog Engine (Backported to 110)
    - Optimization: Zero Value = Feature Kill Switch.
    - Improved performance for mobile hardware.
*/

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord.xy;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 vTexCoord;
uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform int FrameCount;

// --- PARAMETERS ---
#pragma parameter PHASE_MODE "Phase Mode: 0:Manual, 1:2-Phase, 2:3-Phase" 0.0 0.0 2.0 1.0
#pragma parameter rb_power "Rainbow Strength" 0.1 0.0 2.0 0.01
#pragma parameter rb_size "Rainbow Width/Scale" 4.5 0.5 10.0 0.1
#pragma parameter rb_slant "Rainbow Tilt/Rotation" 0.0 -2.0 2.0 0.05
#pragma parameter rb_detect "Rainbow Edge Detect" 0.31 0.0 1.0 0.01
#pragma parameter rb_speed "Rainbow Cycle Speed" 0.1 0.0 1.0 0.01
#pragma parameter rb_phase "Rainbow Phase Shift" 0.0 0.0 6.28 0.1
#pragma parameter rb_sat "Rainbow Saturation" 1.0 0.0 2.0 0.05

#pragma parameter COL_BLEED "Chroma Spread (Bleed)" 3.0 0.0 20.0 0.1
#pragma parameter black_bleed "Black Level Smear" 0.2 0.0 1.0 0.01
#pragma parameter fringe_str "Edge Color Fringing" 0.4 0.0 5.0 0.1
#pragma parameter tv_mist "Signal Blur (Mist)" 0.0 0.0 5.0 0.1

#pragma parameter de_dither "MD De-Dither Intensity" 1.0 0.0 2.0 0.1
#pragma parameter jail_str "MD Vertical Jailbars" 0.15 0.0 1.0 0.01
#pragma parameter jail_width "MD Jailbar Spacing" 1.5 0.5 10.0 0.1
#pragma parameter NOISE_STR "Analog Signal Noise" 0.04 0.0 2.0 0.01
#pragma parameter JITTER "Signal Jitter (Shake)" 0.04 0.0 3.0 0.05

#pragma parameter MD_WARM "Analog Warmth" 0.05 -0.2 0.2 0.01
#pragma parameter MD_SHARP "Luma Sharpness" 0.1 0.0 2.0 0.05
#pragma parameter ntsc_hue "NTSC Tint (Hue)" 0.0 -3.14 3.14 0.05

#ifdef PARAMETER_UNIFORM
uniform float PHASE_MODE, rb_power, rb_size, rb_slant, rb_detect, rb_speed, rb_phase, rb_sat;
uniform float COL_BLEED, black_bleed, fringe_str, de_dither, jail_str, jail_width;
uniform float MD_WARM, MD_SHARP, ntsc_hue, tv_mist, NOISE_STR, JITTER;
#endif

const mat3 RGBtoYIQ = mat3(0.2989, 0.5959, 0.2115, 0.5870, -0.2744, -0.5229, 0.1140, -0.3216, 0.3114);
const mat3 YIQtoRGB = mat3(1.0, 1.0, 1.0, 0.956, -0.2720, -1.1060, 0.6210, -0.6474, 1.7046);

float rand(vec2 co) { 
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453); 
}

void main() {
    vec2 ps = 1.0 / TextureSize;
    float time = float(FrameCount);
    vec2 uv = vTexCoord;

    // 1. JITTER & Mist (Kill Switch)
    if (JITTER > 0.0) uv.x += (rand(vec2(time, uv.y)) - 0.5) * JITTER * ps.x;
    if (tv_mist > 0.0) uv.x += sin(time * 0.1) * tv_mist * 0.0005;

    // 2. Fetch & De-Dither (Kill Switch)
    vec3 main_c = texture2D(Texture, uv).rgb;
    vec3 col = main_c;
    vec3 cL = main_c;
    vec3 cR = main_c;

    if (de_dither > 0.0) {
        cL = texture2D(Texture, uv - vec2(ps.x * de_dither, 0.0)).rgb;
        cR = texture2D(Texture, uv + vec2(ps.x * de_dither, 0.0)).rgb;
        col = mix(main_c, (cL + cR) * 0.5, 0.3); 
    }

    // 3. Signal Analysis (YIQ)
    vec3 yiq = col * RGBtoYIQ;
    float lumaL = (de_dither > 0.0) ? (cL * RGBtoYIQ).r : yiq.r;
    float lumaR = (de_dither > 0.0) ? (cR * RGBtoYIQ).r : yiq.r;

    // 4. Rainbow Effect (Kill Switch)
    vec2 rb_vec = vec2(0.0);
    if (rb_power > 0.0) {
        float p_slant = rb_slant; 
        float p_speed = rb_speed;
        if (PHASE_MODE > 0.5 && PHASE_MODE < 1.5) { p_slant = 0.0; p_speed = 0.5; }
        else if (PHASE_MODE > 1.5) { p_slant = 1.0; p_speed = 0.33; }

        float edge = abs(yiq.r - lumaL) + abs(yiq.r - lumaR);
        float rb_mask = smoothstep(rb_detect, rb_detect + 0.1, edge);
        float ang = (uv.x * TextureSize.x / rb_size) + (uv.y * TextureSize.y * p_slant) + (time * p_speed) + rb_phase;
        rb_vec = vec2(sin(ang), cos(ang)) * rb_power * rb_mask * rb_sat;
    }

    // 5. Chroma Bleed (Kill Switch)
    vec2 chroma = yiq.gb;
    if (COL_BLEED > 0.0) {
        float b_off = ps.x * COL_BLEED;
        vec2 chrL = (texture2D(Texture, uv - vec2(b_off, 0.0)).rgb * RGBtoYIQ).gb;
        vec2 chrR = (texture2D(Texture, uv + vec2(b_off, 0.0)).rgb * RGBtoYIQ).gb;
        chroma = (yiq.gb + chrL + chrR) * 0.333; 
    }

    // 6. Luma Processing (Kill Switches for Sharp, Black Smear, Jailbars, Noise)
    float y = yiq.r;
    if (MD_SHARP > 0.0) y += (yiq.r - lumaL) * MD_SHARP; 
    if (black_bleed > 0.0) y -= black_bleed * smoothstep(0.3, 0.0, y) * 0.2; 
    
    if (jail_str > 0.0) {
        float jail = sin(uv.x * TextureSize.x * jail_width) * jail_str;
        y += jail * 0.15;
    }

    if (NOISE_STR > 0.0) y += (rand(uv + time * 0.01) - 0.5) * NOISE_STR;

    // 7. Final Assembly (Hue Kill Switch Logic)
    float fI = chroma.x + rb_vec.x;
    float fQ = chroma.y + rb_vec.y;
    
    if (fringe_str > 0.0) {
        fI += (yiq.r - lumaR) * fringe_str * 0.5;
        fQ -= (yiq.r - lumaL) * fringe_str * 0.3;
    }
    
    if (ntsc_hue != 0.0) {
        float cA = cos(ntsc_hue); float sA = sin(ntsc_hue);
        vec2 rotated_iq = vec2(fI * cA - fQ * sA, fI * sA + fQ * cA);
        fI = rotated_iq.x; fQ = rotated_iq.y;
    }

    vec3 final_rgb = vec3(y, fI, fQ) * YIQtoRGB;

    if (MD_WARM != 0.0) final_rgb.r += MD_WARM;

    gl_FragColor = vec4(clamp(final_rgb, 0.0, 1.0), 1.0);
}
#endif