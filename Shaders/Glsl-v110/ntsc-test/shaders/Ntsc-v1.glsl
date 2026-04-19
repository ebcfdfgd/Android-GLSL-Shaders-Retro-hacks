#version 110

/* NTSC-V1-TURBO (Performance Edition + Artifacts)
    - STRIPPED: Branching logic (no IFs) for maximum GPU throughput.
    - FEATURES: Retained all original features + Jailbars & Noise.
    - OPTIMIZED: Branchless integration for GLES 2.0.
*/

#pragma parameter ntsc_hue "NTSC Color Hue (Cyan Fix)" 0.0 -3.14 3.14 0.05
#pragma parameter COL_BLEED "Chroma Bleed Strength" 1.5 0.0 5.0 0.05
#pragma parameter red_persistence "Red Persistence (Right Only)" 1.2 0.0 5.0 0.05
#pragma parameter rb_power "Rainbow Strength" 0.15 0.0 2.0 0.01
#pragma parameter rb_size "Rainbow Width" 3.0 0.5 10.0 0.1
#pragma parameter rb_detect "Rainbow Detection" 0.30 0.0 1.0 0.01
#pragma parameter rb_speed "Rainbow Crawl Speed (0=OFF)" 0.5 0.0 2.0 0.05
#pragma parameter rb_tilt "Rainbow Diagonal Tilt" 0.5 -2.0 2.0 0.1
#pragma parameter de_dither "MD De-Dither Intensity" 1.0 0.0 2.0 0.1
#pragma parameter analog_noise "Analog Signal Noise" 0.05 0.0 0.50 0.01
#pragma parameter tv_mist "TV Signal Mist (Softness)" 0.15 0.0 1.0 0.05
#pragma parameter jail_str "MD Vertical Jailbars" 0.15 0.0 1.0 0.01
#pragma parameter jail_width "MD Jailbar Spacing" 1.5 0.5 10.0 0.1

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
uniform float COL_BLEED, red_persistence, rb_power, rb_size, rb_detect, rb_speed, rb_tilt, de_dither, analog_noise, tv_mist;
uniform float jail_str, jail_width;
#endif

const vec3 kY = vec3(0.2989, 0.5870, 0.1140);
const vec3 kI = vec3(0.5959, -0.2744, -0.3216);
const vec3 kQ = vec3(0.2115, -0.5229, 0.3114);

float rand(vec2 co, float seed) {
    return fract(sin(dot(co.xy + seed, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 ps = vec2(1.0 / TextureSize.x, 0.0);
    float time = float(FrameCount);
    float time_seed = mod(time, 60.0);

    // 1. DITHER & LUMA SAMPLES
    vec3 cM = texture2D(Texture, vTexCoord).rgb;
    float d_off = max(de_dither, 1.0);
    vec3 cL = texture2D(Texture, vTexCoord - ps * d_off).rgb;
    vec3 cR = texture2D(Texture, vTexCoord + ps * d_off).rgb;

    float yM = dot(cM, kY);
    float yL = dot(cL, kY);
    float yR = dot(cR, kY);
    
    // Branchless Luma Processing
    float final_y = mix(yM, (yL + yR) * 0.5, 0.5 * de_dither * step(0.001, de_dither));
    float mist_avg = (yL + yM + yR) * 0.33333;
    final_y = mix(final_y, mist_avg, tv_mist * step(0.001, tv_mist));

    // 2. CHROMA ENGINE
    float fI = dot(cM, kI);
    float fQ = dot(cM, kQ);

    vec2 b_off = ps * COL_BLEED * 1.5; 
    vec3 bcL = texture2D(Texture, vTexCoord - b_off).rgb;
    vec3 bcR = texture2D(Texture, vTexCoord + b_off).rgb;
    
    float iL = dot(bcL, kI);
    float qL = dot(bcL, kQ);
    float iR = dot(bcR, kI);
    float qR = dot(bcR, kQ);

    float has_bleed = step(0.001, COL_BLEED);
    fI = mix(fI, (iL + iR) * 0.5, 0.7 * has_bleed);
    fQ = mix(fQ, (qL + qR) * 0.5, 0.7 * has_bleed);
    
    fI = mix(fI, iL, 0.4 * red_persistence * step(0.001, red_persistence));

    // 3. RAINBOW & ARTIFACTS (Branchless)
    float edge = abs(yM - yL) + abs(yM - yR);
    float rb_mask = smoothstep(rb_detect, rb_detect + 0.1, edge) * step(0.001, rb_power);
    float ang = (vTexCoord.x * TextureSize.x / rb_size) + (vTexCoord.y * TextureSize.y * rb_tilt) + (time * rb_speed);
    fI += sin(ang) * rb_power * rb_mask;
    fQ += cos(ang) * rb_power * rb_mask;

    // 4. ANALOG NOISE & JAILBARS
    final_y += (rand(vTexCoord, time_seed) - 0.5) * analog_noise * step(0.001, analog_noise);
    final_y += sin(vTexCoord.x * TextureSize.x * jail_width) * jail_str * 0.02 * step(0.001, jail_str);

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