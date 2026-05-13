/* PHYSICAL-SIGNAL-EMULATOR-V21-SMART-DITHER-16-CLEAN
   - Optimized for RetroArch Android - GLSL 110
   - REMOVED: Red Persistence logic for cleaner signal
*/

#version 110

// --- Parameters ---
#pragma parameter NTSC_FREQ "Signal Frequency" 0.08 0.0 1.0 0.01
#pragma parameter NTSC_SENSE "Rainbow Sensitivity" 0.5 0.0 1.0 0.01
#pragma parameter rb_tilt "Rainbow Tilt" 0.0 -2.0 2.0 0.1
#pragma parameter ntsc_hue "Color Hue (Shift)" 0.0 -3.14 3.14 0.05
#pragma parameter COL_BLEED "Chroma Bleed Strength" 1.5 0.0 5.0 0.05
#pragma parameter ntsc_blur "Smart Dither 16 Intensity" 0.5 0.0 1.0 0.05
#pragma parameter CRAWL_SPEED "Crawl Speed" 0.1 0.0 5.0 0.1
#pragma parameter NTSC_ARTIFACTS "Rainbow Intensity" 0.08 0.0 2.0 0.01
#pragma parameter NTSC_SATURATION "Saturation" 1.0 0.0 2.0 0.05
#pragma parameter RF_GRAIN "RF Noise Intensity" 0.0 0.0 0.5 0.01
#pragma parameter BLACK_LEVEL "Black Level" 0.0 -0.5 0.5 0.01

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
uniform mat4 MVPMatrix;
varying vec2 vTexCoord;

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

uniform float NTSC_FREQ, NTSC_SENSE, rb_tilt, ntsc_hue, COL_BLEED, ntsc_blur, CRAWL_SPEED, NTSC_ARTIFACTS, NTSC_SATURATION;
uniform float RF_GRAIN, BLACK_LEVEL;

const vec3 kY = vec3(0.2989, 0.5870, 0.1140);
const vec3 kI = vec3(0.5959, -0.2744, -0.3216);
const vec3 kQ = vec3(0.2115, -0.5229, 0.3114);

float hash(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 ps = vec2(1.0 / TextureSize.x, 0.0);
    vec3 cM = texture2D(Texture, vTexCoord).rgb;
    
    // --- SMART DITHER 16 LOGIC ---
    vec3 cL = texture2D(Texture, vTexCoord - ps).rgb;
    vec3 cR = texture2D(Texture, vTexCoord + ps).rgb;

    float yM = dot(cM, kY);
    float yL = dot(cL, kY);
    float yR = dot(cR, kY);
    
    float d_mask = clamp(abs(yM - yL) * abs(yM - yR) * 50.0, 0.0, 1.0);
    d_mask *= clamp(1.0 - abs(yL - yR) * 5.0, 0.0, 1.0);
    
    vec3 col = mix(cM, (cL + cM + cR) * 0.3333, ntsc_blur * d_mask);
    float final_y = dot(col, kY);

    // RF Grain
    float time_step = floor(float(FrameCount) / 4.0);
    float noise = (hash(vTexCoord + vec2(time_step * 0.05, 0.0)) - 0.5) * RF_GRAIN;
    final_y += noise;

    // Chroma
    float fI = dot(col, kI);
    float fQ = dot(col, kQ);
    
    vec2 b_off = ps * COL_BLEED * 1.5; 
    vec3 bcL = texture2D(Texture, vTexCoord - b_off).rgb;
    vec3 bcR = texture2D(Texture, vTexCoord + b_off).rgb;
    
    fI = mix(fI, (dot(bcL, kI) + dot(bcR, kI)) * 0.5, 0.7 * step(0.1, COL_BLEED));
    fQ = mix(fQ, (dot(bcL, kQ) + dot(bcR, kQ)) * 0.5, 0.7 * step(0.1, COL_BLEED));

    // Hue Rotation
    float cosH = cos(ntsc_hue);
    float sinH = sin(ntsc_hue);
    float rotI = fI * cosH - fQ * sinH;
    float rotQ = fI * sinH + fQ * cosH;
    fI = rotI; fQ = rotQ;

    // Rainbow
    float phase = (vTexCoord.x * TextureSize.x + vTexCoord.y * TextureSize.y * rb_tilt) * (3.14159 * NTSC_FREQ) + (float(FrameCount) * 0.05 * CRAWL_SPEED);
    float edge = abs(yM - yL) + abs(yM - yR);
    float rb_mask = smoothstep(0.1, 1.0, edge) * NTSC_ARTIFACTS;
    
    fI += sin(phase) * rb_mask;
    fQ += cos(phase) * rb_mask;

    // Output
    vec3 res = vec3(
        final_y + 0.956 * fI + 0.621 * fQ,
        final_y - 0.272 * fI - 0.647 * fQ,
        final_y - 1.106 * fI + 1.703 * fQ
    );

    res = mix(vec3(dot(res, kY)), res, NTSC_SATURATION);
    res += BLACK_LEVEL;
    
    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif