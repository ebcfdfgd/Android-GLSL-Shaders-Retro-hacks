/* NTSC MEGA LITE - ANALOG NOISE + MD JAILBARS (Optimized)
   - Feature: MD Vertical Jailbars added.
   - Fix: Independent Chroma Bleed logic.
*/

#version 110

#pragma parameter ntsc_hue "NTSC Color Hue (Cyan Fix)" 0.0 -3.14 3.14 0.05
#pragma parameter COL_BLEED "Chroma Bleed Strength" 1.5 0.0 5.0 0.05
#pragma parameter rb_power "Rainbow Strength" 0.15 0.0 2.0 0.01
#pragma parameter rb_size "Rainbow Width" 3.0 0.5 10.0 0.1
#pragma parameter rb_detect "Rainbow Detection" 0.30 0.0 1.0 0.01
#pragma parameter rb_speed "Rainbow Crawl Speed (0=OFF)" 0.5 0.0 2.0 0.05
#pragma parameter rb_tilt "Rainbow Diagonal Tilt" 0.5 -2.0 2.0 0.1
#pragma parameter de_dither "MD De-Dither Intensity" 1.0 0.0 2.0 0.1
#pragma parameter analog_noise "Analog Signal Noise" 0.05 0.0 5.50 0.01
#pragma parameter JAIL_STR "MD Vertical Jailbars" 0.10 0.0 1.0 0.01
#pragma parameter JAIL_WIDTH "Jailbar Spacing" 2.0 0.5 10.0 0.1

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord;
varying vec2 hTrig; 
uniform mat4 MVPMatrix;
uniform float ntsc_hue;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord;
    hTrig = vec2(sin(ntsc_hue), cos(ntsc_hue));
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision mediump float;
#endif

uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform int FrameCount;
varying vec2 vTexCoord;
varying vec2 hTrig;

#ifdef PARAMETER_UNIFORM
uniform float COL_BLEED, rb_power, rb_size, rb_detect, rb_speed, rb_tilt, de_dither, analog_noise, JAIL_STR, JAIL_WIDTH;
#endif

const vec3 kY = vec3(0.2989, 0.5870, 0.1140);
const vec3 kI = vec3(0.5959, -0.2744, -0.3216);
const vec3 kQ = vec3(0.2115, -0.5229, 0.3114);

float rand(vec2 co, float seed) {
    return fract(sin(dot(co.xy + seed, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 ps = vec2(1.0 / TextureSize.x, 0.0);
    float time_seed = mod(float(FrameCount), 60.0);

    // 1. DITHER & LUMA SAMPLES
    vec3 cM = texture2D(Texture, vTexCoord).rgb;
    float d_off = max(de_dither, 1.0);
    vec3 cL = texture2D(Texture, vTexCoord - ps * d_off).rgb;
    vec3 cR = texture2D(Texture, vTexCoord + ps * d_off).rgb;

    float yM = dot(cM, kY);
    float yL = dot(cL, kY);
    float yR = dot(cR, kY);
    float final_y = (de_dither > 0.0) ? mix(yM, (yL + yR) * 0.5, 0.5 * de_dither) : yM;

    // 2. CHROMA BLEED
    float fI = dot(cM, kI);
    float fQ = dot(cM, kQ);

    if (COL_BLEED > 0.0) {
        vec2 b_off = ps * COL_BLEED * 1.5; 
        vec3 bcL = texture2D(Texture, vTexCoord - b_off).rgb;
        vec3 bcR = texture2D(Texture, vTexCoord + b_off).rgb;
        
        float i_bleed = (dot(bcL, kI) + dot(bcR, kI)) * 0.5;
        float q_bleed = (dot(bcL, kQ) + dot(bcR, kQ)) * 0.5;
        
        fI = mix(fI, i_bleed, 0.7);
        fQ = mix(fQ, q_bleed, 0.7);
    }

    // 3. RAINBOW ARTIFACTS
    if (rb_power > 0.0) {
        float edge = abs(yM - yL) + abs(yM - yR);
        float mask = smoothstep(rb_detect, rb_detect + 0.1, edge);
        float ang = (vTexCoord.x * TextureSize.x / rb_size) + (vTexCoord.y * TextureSize.y * rb_tilt) + (float(FrameCount) * rb_speed);
        fI += sin(ang) * rb_power * mask;
        fQ += cos(ang) * rb_power * mask;
    }

    // 4. ANALOG SIGNAL NOISE & JAILBARS
    if (analog_noise > 0.0) {
        final_y += (rand(vTexCoord, time_seed) - 0.5) * analog_noise;
    }
    
    // MD Vertical Jailbars
    if (JAIL_STR > 0.0) {
        final_y += sin(vTexCoord.x * TextureSize.x * JAIL_WIDTH) * JAIL_STR * 0.05;
    }

    // 5. HUE SHIFTING
    float resI = fI * hTrig.y - fQ * hTrig.x;
    float resQ = fI * hTrig.x + fQ * hTrig.y;

    // 6. FINAL ASSEMBLY (YIQ to RGB)
    vec3 res = vec3(
        final_y + 0.956 * resI + 0.621 * resQ,
        final_y - 0.272 * resI - 0.647 * resQ,
        final_y - 1.106 * resI + 1.703 * resQ
    );

    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif