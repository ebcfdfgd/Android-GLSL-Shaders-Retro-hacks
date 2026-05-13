/* 777-NTSC-V1-TURBO-FINAL-FIX 
    - REMOVED: TV Signal Mist.
    - FIXED: RF Grain precision (Switched to highp for pixel-perfect hash).
    - FIXED: Noise pattern (Now fine grain "Namash" instead of bars).
    - OPTIMIZED: High-performance branchless engine.
    - UPDATED: Jailbars are now resolution independent.
    - ADDED: Saturation & Black Level Control.
*/

#version 110

#pragma parameter ntsc_hue "NTSC Color Hue" 0.0 -3.14 3.14 0.05
#pragma parameter SATURATION "Saturation" 1.0 0.0 2.0 0.05
#pragma parameter BLACK_LEVEL "Black Level" 0.0 -0.5 0.5 0.01
#pragma parameter COL_BLEED "Chroma Bleed Strength" 1.5 0.0 5.0 0.05
#pragma parameter red_persistence "Red Persistence" 1.2 0.0 5.0 0.05
#pragma parameter rb_power "Rainbow Strength" 0.15 0.0 2.0 0.01
#pragma parameter rb_size "Rainbow Width" 3.0 0.5 10.0 0.1
#pragma parameter rb_detect "Rainbow Detection" 0.30 0.0 1.0 0.01
#pragma parameter rb_speed "Rainbow Crawl Speed" 0.5 0.0 2.0 0.05
#pragma parameter rb_tilt "Rainbow Diagonal Tilt" 0.5 -2.0 2.0 0.1
#pragma parameter de_dither "MD De-Dither Intensity" 1.0 0.0 2.0 0.1
#pragma parameter sig_noise "Signal RF Grain" 0.05 0.0 0.50 0.01
#pragma parameter jail_str "MD Vertical Jailbars" 0.10 0.0 1.0 0.01
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
precision highp float;
#endif

uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform int FrameCount;
varying vec2 vTexCoord;
varying vec2 hTrig;

#ifdef PARAMETER_UNIFORM
uniform float SATURATION, BLACK_LEVEL, COL_BLEED, red_persistence, rb_power, rb_size, rb_detect, rb_speed, rb_tilt, de_dither, sig_noise;
uniform float jail_str, jail_width;
#endif

const vec3 kY = vec3(0.2989, 0.5870, 0.1140);
const vec3 kI = vec3(0.5959, -0.2744, -0.3216);
const vec3 kQ = vec3(0.2115, -0.5229, 0.3114);

float hash(vec2 co) { 
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453); 
}

void main() {
    vec2 ps = vec2(1.0 / TextureSize.x, 0.0);
    float time = float(FrameCount); 
    
    // 1. FETCH & LUMA
    vec3 cM = texture2D(Texture, vTexCoord).rgb;
    float d_off = max(de_dither, 1.0);
    vec3 cL = texture2D(Texture, vTexCoord - ps * d_off).rgb;
    vec3 cR = texture2D(Texture, vTexCoord + ps * d_off).rgb;

    float yM = dot(cM, kY);
    float yL = dot(cL, kY);
    float yR = dot(cR, kY);
    
    // De-Dither logic only (Mist removed)
    float final_y = mix(yM, (yL + yR) * 0.5, 0.5 * de_dither * step(0.001, de_dither));

    // 2. RF GRAIN & JAILBARS (Resolution Independent)
    if (sig_noise > 0.0)
        final_y += (hash(vTexCoord + time * 0.01) - 0.5) * sig_noise;
    
    if (jail_str > 0.0)
        final_y += sin(vTexCoord.x * jail_width * 500.0) * jail_str * 0.02;

    final_y = clamp(final_y, 0.0, 1.0);

    // 3. CHROMA ENGINE
    float fI = dot(cM, kI);
    float fQ = dot(cM, kQ);

    vec2 b_off = ps * COL_BLEED * 1.5; 
    vec3 bcL = texture2D(Texture, vTexCoord - b_off).rgb;
    vec3 bcR = texture2D(Texture, vTexCoord + b_off).rgb;
    
    float has_bleed = step(0.001, COL_BLEED);
    fI = mix(fI, (dot(bcL, kI) + dot(bcR, kI)) * 0.5, 0.7 * has_bleed);
    fQ = mix(fQ, (dot(bcL, kQ) + dot(bcR, kQ)) * 0.5, 0.7 * has_bleed);
    fI = mix(fI, dot(bcL, kI), 0.4 * red_persistence * step(0.001, red_persistence));

    // 4. RAINBOW
    float edge = abs(yM - yL) + abs(yM - yR);
    float rb_mask = smoothstep(rb_detect, rb_detect + 0.1, edge) * step(0.001, rb_power);
    float ang = (vTexCoord.x * TextureSize.x / rb_size) + (vTexCoord.y * TextureSize.y * rb_tilt) + (time * rb_speed);
    fI += sin(ang) * rb_power * rb_mask;
    fQ += cos(ang) * rb_power * rb_mask;

    // 5. OUTPUT ASSEMBLY (Applying Hue & Saturation)
    float resI = (fI * hTrig.y - fQ * hTrig.x) * SATURATION;
    float resQ = (fI * hTrig.x + fQ * hTrig.y) * SATURATION;

    vec3 res = vec3(
        final_y + 0.956 * resI + 0.621 * resQ,
        final_y - 0.272 * resI - 0.647 * resQ,
        final_y - 1.106 * resI + 1.703 * resQ
    );

    // 6. APPLY BLACK LEVEL
    res = mix(vec3(BLACK_LEVEL), vec3(1.0), res);

    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif