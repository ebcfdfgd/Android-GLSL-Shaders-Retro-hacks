#version 110

/* NTSC-ULTRA-CLEAN (G90T Stable Edition + Analog Artifacts)
    - Integrated: Analog Noise & MD Vertical Jailbars
    - Logic: Applied to Luma channel for signal-accurate interference.
*/

// --- [ RetroArch Parameters ] ---
#pragma parameter ntsc_rainbow "NTSC Rainbow Strength" 0.6 0.0 2.0 0.01
#pragma parameter ntsc_freq "NTSC Rainbow Frequency" 0.08 0.0 2.0 0.01
#pragma parameter ntsc_tilt "NTSC Rainbow Tilt" 0.0 -2.0 2.0 0.05
#pragma parameter ntsc_crawl "NTSC Dot Crawl Speed" 0.0 0.0 5.0 0.05
#pragma parameter ntsc_blur "NTSC Dither Blur" 0.5 0.0 1.0 0.05
#pragma parameter ntsc_fringing "NTSC Color Fringing" 0.3 0.0 1.0 0.05
#pragma parameter ntsc_hue "NTSC Hue Adjustment" 0.0 -0.5 0.5 0.01
#pragma parameter ntsc_bleed "NTSC Chroma Bleed" 1.5 0.0 5.0 0.05
#pragma parameter red_persistence "Red Persistence (Right Smear)" 1.3 0.0 2.0 0.05
#pragma parameter noise_str "Analog Noise Intensity" 0.03 0.0 0.5 0.01
#pragma parameter jail_str "MD Vertical Jailbars" 0.1 0.0 1.0 0.01
#pragma parameter jail_width "Jailbar Spacing" 2.0 0.5 10.0 0.1

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
precision mediump float;
#endif

varying vec2 vTexCoord;
uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform int FrameCount;

#ifdef PARAMETER_UNIFORM
uniform float ntsc_rainbow, ntsc_freq, ntsc_tilt, ntsc_crawl, ntsc_blur, ntsc_fringing, ntsc_hue, ntsc_bleed, red_persistence;
uniform float noise_str, jail_str, jail_width;
#endif

const vec3 kY = vec3(0.2989, 0.5870, 0.1140);
const vec3 kI = vec3(0.5959, -0.2744, -0.3216);
const vec3 kQ = vec3(0.2115, -0.5229, 0.3114);

// Deterministic Noise Generator
float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 ps = 1.0 / TextureSize;
    float time = mod(float(FrameCount), 1024.0);
    vec2 pix = vTexCoord * TextureSize;

    // 1. Fetch Samples
    vec3 cC = texture2D(Texture, vTexCoord).rgb;
    vec3 cL = texture2D(Texture, vTexCoord - vec2(ps.x, 0.0)).rgb;
    vec3 cR = texture2D(Texture, vTexCoord + vec2(ps.x, 0.0)).rgb;

    float yC = dot(cC, kY);
    float yL = dot(cL, kY);
    float yR = dot(cR, kY);

    // 2. Dither Detection & Smart Blur
    float d_mask = clamp(abs(yC - yL) * abs(yC - yR) * 50.0, 0.0, 1.0);
    d_mask *= clamp(1.0 - abs(yL - yR) * 5.0, 0.0, 1.0);
    
    vec3 col = mix(cC, (cL + cC + cR) * 0.3333, ntsc_blur * d_mask);

    // 3. Chroma Engine
    float fI = dot(col, kI);
    float fQ = dot(col, kQ);

    if (ntsc_bleed > 0.1) {
        vec2 b_off = vec2(ps.x * ntsc_bleed, 0.0);
        vec3 bcL = texture2D(Texture, vTexCoord - b_off).rgb;
        vec3 bcR = texture2D(Texture, vTexCoord + b_off).rgb;
        fI = mix(fI, (dot(bcL, kI) + dot(bcR, kI)) * 0.5, 0.7);
        fQ = mix(fQ, (dot(bcL, kQ) + dot(bcR, kQ)) * 0.5, 0.7);
        
        if (red_persistence > 0.0) {
            fI = mix(fI, dot(bcL, kI), 0.45 * red_persistence);
        }
    }

    // 4. Artifacts (Manual Control)
    if (ntsc_rainbow > 0.0) {
        float phase = (pix.x * 3.14159 * ntsc_freq) + (pix.y * ntsc_tilt) + (time * ntsc_crawl);
        fI += sin(phase) * 0.2 * ntsc_rainbow * d_mask;
        fQ += cos(phase) * 0.2 * ntsc_rainbow * d_mask;
    }

    fI += (yL - yR) * ntsc_fringing * 0.15;

    // 5. Hue & Final Assembly
    float hSin = sin(ntsc_hue);
    float hCos = cos(ntsc_hue);
    float resI = fI * hCos - fQ * hSin;
    float resQ = fI * hSin + fQ * hCos;

    // Final Y with Analog Artifact Injection
    float final_y = dot(col, kY);
    if (noise_str > 0.0) final_y += (rand(vTexCoord + mod(time, 100.0) * 0.01) - 0.5) * noise_str;
    if (jail_str > 0.0) final_y += sin(pix.x * jail_width) * jail_str * 0.05;

    vec3 res = vec3(
        final_y + 0.956 * resI + 0.621 * resQ,
        final_y - 0.272 * resI - 0.647 * resQ,
        final_y - 1.106 * resI + 1.703 * resQ
    );

    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif