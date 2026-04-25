/* --- 777-NTSC-V1-TURBO-ULTRA-GRAIN (SMART DITHER 16) ---
   - REMOVED: Linear De-Dither.
   - ADDED: Smart Dither 16 (Context-aware filtering).
   - FIXED: Banding (Blocky noise) by forcing High Precision.
   - OPTIMIZED: High-Precision Hash logic for mobile.
*/

#version 110

#pragma parameter ntsc_hue "NTSC Color Hue" 0.0 -3.14 3.14 0.05
#pragma parameter COL_BLEED "Chroma Bleed Strength" 1.5 0.0 5.0 0.05
#pragma parameter red_persistence "Red Persistence" 1.2 0.0 5.0 0.05
#pragma parameter rb_power "Rainbow Strength" 0.15 0.0 2.0 0.01
#pragma parameter rb_size "Rainbow Width" 3.0 0.5 10.0 0.1
#pragma parameter rb_detect "Rainbow Detection" 0.30 0.0 1.0 0.01
#pragma parameter rb_speed "Rainbow Crawl Speed" 0.5 0.0 2.0 0.05
#pragma parameter rb_tilt "Rainbow Diagonal Tilt" 0.5 -2.0 2.0 0.1
#pragma parameter ntsc_blur "Smart Dither 16 Intensity" 0.5 0.0 1.0 0.05
#pragma parameter sig_noise "Signal RF Grain" 0.04 0.0 0.50 0.01
#pragma parameter jail_str "MD Vertical Jailbars" 0.10 0.0 1.0 0.01
#pragma parameter jail_width "MD Jailbar Spacing" 4.0 0.5 20.0 0.1

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
uniform float COL_BLEED, red_persistence, rb_power, rb_size, rb_detect, rb_speed, rb_tilt, ntsc_blur, sig_noise;
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
    float time = mod(float(FrameCount), 600.0); 
    
    // 1. SMART DITHER 16
    vec3 cM = texture2D(Texture, vTexCoord).rgb;
    vec3 cL = texture2D(Texture, vTexCoord - ps).rgb;
    vec3 cR = texture2D(Texture, vTexCoord + ps).rgb;
    
    float yM = dot(cM, kY);
    float yL = dot(cL, kY);
    float yR = dot(cR, kY);
    
    // Edge detection logic
    float d_mask = clamp(abs(yM - yL) * abs(yM - yR) * 50.0, 0.0, 1.0);
    d_mask *= clamp(1.0 - abs(yL - yR) * 5.0, 0.0, 1.0);
    
    vec3 col = mix(cM, (cL + cM + cR) * 0.3333, ntsc_blur * d_mask);
    float final_y = dot(col, kY);

    // 2. RF GRAIN
    final_y += (hash(vTexCoord + time * 0.01) - 0.5) * sig_noise * step(0.001, sig_noise);
    
    // 3. MD JAILBARS
    float jail = sin(vTexCoord.x * 500.0 * jail_width) * jail_str * 0.03 * step(0.001, jail_str);
    final_y += jail;

    final_y = clamp(final_y, 0.0, 1.0);

    // 4. CHROMA ENGINE (Based on smoothed col)
    float fI = dot(col, kI);
    float fQ = dot(col, kQ);

    vec2 b_off = ps * COL_BLEED * 1.5; 
    vec3 bcL = texture2D(Texture, vTexCoord - b_off).rgb;
    vec3 bcR = texture2D(Texture, vTexCoord + b_off).rgb;
    
    float has_bleed = step(0.001, COL_BLEED);
    fI = mix(fI, (dot(bcL, kI) + dot(bcR, kI)) * 0.5, 0.7 * has_bleed);
    fQ = mix(fQ, (dot(bcL, kQ) + dot(bcR, kQ)) * 0.5, 0.7 * has_bleed);
    fI = mix(fI, dot(bcL, kI), 0.4 * red_persistence * step(0.001, red_persistence));

    // 5. RAINBOW
    float edge = abs(yM - yL) + abs(yM - yR);
    float rb_mask = smoothstep(rb_detect, rb_detect + 0.1, edge) * step(0.001, rb_power);
    float ang = (vTexCoord.x * TextureSize.x / rb_size) + (vTexCoord.y * TextureSize.y * rb_tilt) + (time * rb_speed);
    fI += sin(ang) * rb_power * rb_mask;
    fQ += cos(ang) * rb_power * rb_mask;

    // 6. HUE & FINAL ASSEMBLY
    float resI = fI * hTrig.y - fQ * hTrig.x;
    float resQ = fI * hTrig.x + fQ * hTrig.y;

    vec3 res = vec3(
        final_y + 0.956 * resI + 0.621 * resQ,
        final_y - 0.272 * resI - 0.647 * resQ,
        final_y - 1.106 * resI + 1.703 * resQ
    );

    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif