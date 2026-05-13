/* --- 777-GTU-TURBO-v2 (4-TAP) ---
    - TOTAL SAMPLES: 4 (2 Luma, 2 Chroma).
    - ADDED: Independent Chroma Sharpness (I & Q).
    - REMOVED: Scanlines & Vertical Resolution.
    - OPTIMIZED: High-speed Hue & Saturation.
*/

#version 110

#pragma parameter signalResolution "Signal Sharpness (Luma)" 320.0 16.0 1024.0 16.0
#pragma parameter signalResolutionI "Chroma Sharpness I" 128.0 16.0 1024.0 16.0
#pragma parameter signalResolutionQ "Chroma Sharpness Q" 64.0 16.0 1024.0 16.0
#pragma parameter chroma_bleed "Chroma Bleed Strength" 1.5 0.0 5.0 0.1
#pragma parameter blackLevel "Black Level" 0.0 -0.20 0.20 0.01
#pragma parameter SATURATION "Saturation" 1.0 0.0 2.0 0.05
#pragma parameter ntsc_hue "NTSC Hue (Tint)" 0.0 -3.14 3.14 0.05

// Rainbow Parameters
#pragma parameter rb_power "Rainbow Strength" 0.10 0.0 2.0 0.01
#pragma parameter rb_size "Rainbow Width" 5.0 0.5 10.0 0.1
#pragma parameter rb_detect "Rainbow Detection" 0.30 0.0 1.0 0.01
#pragma parameter rb_speed "Rainbow Crawl Speed" 0.1 0.0 2.0 0.05
#pragma parameter rb_tilt "Rainbow Diagonal Tilt" 0.0 -2.0 2.0 0.1

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
uniform float signalResolution, signalResolutionI, signalResolutionQ, chroma_bleed, blackLevel;
uniform float SATURATION, rb_power, rb_size, rb_detect, rb_speed, rb_tilt;
#endif

const vec3 kY = vec3(0.299, 0.587, 0.114);
const vec3 kI = vec3(0.596, -0.274, -0.322);
const vec3 kQ = vec3(0.211, -0.523, 0.311);
const mat3 YIQ_to_RGB = mat3(1.0, 0.956, 0.621, 1.0, -0.272, -0.647, 1.0, -1.106, 1.703);

void main() {
    vec2 ps = vec2(1.0 / TextureSize.x, 0.0);
    float time = float(FrameCount);

    // --- 1. LUMA ENGINE (2 SAMPLES) ---
    vec3 cM = texture2D(Texture, vTexCoord).rgb;
    vec3 cL = texture2D(Texture, vTexCoord - ps * (320.0 / signalResolution)).rgb;
    
    float yM = dot(cM, kY);
    float yL = dot(cL, kY);
    float final_y = mix(yM, yL, -0.3); // Sharpness offset

    // --- 2. CHROMA ENGINE (2 SAMPLES - I & Q SHARPNESS + BLEED) ---
    // سحب عينتين مستقلتين للكروما للتحكم في البليد والحدة
    vec2 bOffsetL = ps * (chroma_bleed * (320.0 / signalResolutionI));
    vec2 bOffsetR = ps * (chroma_bleed * (320.0 / signalResolutionQ));
    
    vec3 cbL = texture2D(Texture, vTexCoord - bOffsetL).rgb;
    vec3 cbR = texture2D(Texture, vTexCoord + bOffsetR).rgb;
    
    // حساب I و Q باستخدام الباراميترات الخاصة بهما
    float fI = (dot(cbL, kI) + dot(cM, kI)) * 0.5;
    float fQ = (dot(cbR, kQ) + dot(cM, kQ)) * 0.5;

    // --- 3. RAINBOW ARTIFACTS ---
    float edge = abs(yM - yL);
    float rb_mask = smoothstep(rb_detect, rb_detect + 0.1, edge) * step(0.001, rb_power);
    float ang = (vTexCoord.x * TextureSize.x / rb_size) + (vTexCoord.y * TextureSize.y * rb_tilt) + (time * rb_speed);
    
    fI += sin(ang) * rb_power * rb_mask;
    fQ += cos(ang) * rb_power * rb_mask;

    // --- 4. HUE & SATURATION ---
    float rotatedI = (fI * hTrig.y - fQ * hTrig.x) * SATURATION;
    float rotatedQ = (fI * hTrig.x + fQ * hTrig.y) * SATURATION;

    // --- 5. FINAL ASSEMBLY ---
    vec3 yiq = vec3(final_y, rotatedI, rotatedQ);
    vec3 rgb = clamp(yiq * YIQ_to_RGB, 0.0, 1.0);
    
    rgb -= vec3(blackLevel);

    gl_FragColor = vec4(clamp(rgb, 0.0, 1.0), 1.0);
}
#endif