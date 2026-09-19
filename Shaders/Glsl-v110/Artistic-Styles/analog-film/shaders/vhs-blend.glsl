#version 110

/*
    VHS Signal & Degradation Shader (RetroArch GLSL) — With Blend Level, Temperature & Tint
    --------------------------------------------------------------------------------------
*/

// ===== Blend Settings =====
#pragma parameter SGPT_BLEND_LEVEL     "Blend Level"                     1.0    0.0 1.0  0.05

// ===== VHS Signal & Distortion =====
#pragma parameter vhs_chroma_ab      "VHS - Chromatic Aberration"        2.5    0.0 8.0  0.25
#pragma parameter vhs_color_bleed    "VHS - Color Bleed (Chroma Blur)"   1.5    0.0 5.0  0.25
#pragma parameter vhs_scanline_str   "VHS - Scanline Strength"         0.25   0.0 1.0  0.05
#pragma parameter vhs_tape_noise     "VHS - Tape Tracking Noise"       0.40   0.0 2.0  0.05
#pragma parameter vhs_jitter_str     "VHS - Horizontal Jitter"         0.80   0.0 3.0  0.10

// ===== Color Adjustments =====
#pragma parameter vhs_black_level    "VHS - Signal Fade (Black Lift)"  0.08   0.0 0.3  0.01
#pragma parameter vhs_contrast       "VHS - Contrast"                  0.95   0.5 1.5  0.02
#pragma parameter vhs_saturation     "VHS - Saturation"                0.80   0.0 2.0  0.05
#pragma parameter vhs_temp           "VHS - Color Temperature"         0.0   -1.0 1.0  0.05
#pragma parameter vhs_tint           "VHS - Color Tint"                0.0   -1.0 1.0  0.05

#if defined(VERTEX)

attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
uniform mat4 MVPMatrix;

void main() {
    uv = TexCoord;
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)

#ifdef GL_ES
precision highp float;
#endif

varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform vec2 InputSize;
uniform int FrameCount;

uniform float SGPT_BLEND_LEVEL;
uniform float vhs_chroma_ab;
uniform float vhs_color_bleed;
uniform float vhs_scanline_str;
uniform float vhs_tape_noise;
uniform float vhs_jitter_str;
uniform float vhs_black_level;
uniform float vhs_contrast;
uniform float vhs_saturation;
uniform float vhs_temp;
uniform float vhs_tint;

const vec3 Y = vec3(0.299, 0.587, 0.114);

float luma(vec3 c) { 
    return dot(c, Y); 
}

// Pseudo-random number generator
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// VHS Tape Noise generator (horizontal bands and static)
float tapeNoise(vec2 uvCoord, float time) {
    float line = floor(uvCoord.y * TextureSize.y);
    float n1 = hash(vec2(line, floor(time)));
    
    // Random thick horizontal static bands
    float band = smoothstep(0.98, 1.0, sin(uvCoord.y * 10.0 + time * 0.05));
    
    // Fine static noise
    float staticNoise = hash(uvCoord * TextureSize + vec2(time, time * 1.5));
    
    return mix(staticNoise * 0.15, staticNoise * 0.85, band);
}

void main() {
    float time = float(FrameCount);
    vec2 texelSize = 1.0 / TextureSize;
    
    // ========================================================
    // 1. Horizontal Scanline Jitter & Distortion
    // ========================================================
    float lineY = floor(uv.y * TextureSize.y);
    float jitterRand = hash(vec2(lineY, floor(time * 0.5)));
    
    // Occasional line offsets (sync loss effect)
    float jitterOffset = 0.0;
    if (jitterRand > 0.92) {
        jitterOffset = (hash(vec2(lineY * 2.0, time)) - 0.5) * 0.015 * vhs_jitter_str;
    }
    
    vec2 distortedUV = uv + vec2(jitterOffset, 0.0);

    // ========================================================
    // 2. Chromatic Aberration & Color Bleed (YIQ / Composite style)
    // ========================================================
    vec2 abOffset = vec2(vhs_chroma_ab * texelSize.x, 0.0);
    vec2 bleedOffset = vec2(vhs_color_bleed * texelSize.x, 0.0);

    // Channel sample with horizontal displacement
    float r = texture2D(Texture, distortedUV + abOffset).r;
    float g = texture2D(Texture, distortedUV).g;
    float b = texture2D(Texture, distortedUV - abOffset - bleedOffset).b;

    vec3 rawColor = vec3(r, g, b);

    // ========================================================
    // 3. SGPT Edge Smoothing Blend
    // ========================================================
    vec3 L = texture2D(Texture, distortedUV - vec2(texelSize.x, 0.0)).rgb;
    vec3 R = texture2D(Texture, distortedUV + vec2(texelSize.x, 0.0)).rgb;

    vec3 diffL = rawColor - L;
    vec3 diffR = rawColor - R;
    float wL = dot(abs(diffL), Y);
    float wR = dot(abs(diffR), Y);

    vec3 blendedColor = (wR < wL) ? (rawColor - 0.5 * SGPT_BLEND_LEVEL * diffR)
                                : (rawColor - 0.5 * SGPT_BLEND_LEVEL * diffL);
    
    vec3 res = clamp(blendedColor, min(rawColor, min(L, R)), max(rawColor, max(L, R)));

    // ========================================================
    // 4. VHS Signal Degradation (Black Level, Contrast, Saturation, Temp, Tint)
    // ========================================================
    res = clamp((res - vhs_black_level) / max(1.0 - vhs_black_level, 0.001), 0.0, 1.0);
    res = (res - 0.5) * vhs_contrast + 0.5;
    
    float lum = luma(res);
    res = mix(vec3(lum), res, vhs_saturation);
    
    // Apply Color Temperature & Tint adjustments
    res.r += vhs_temp * 0.15 - vhs_tint * 0.05;
    res.g += vhs_tint * 0.15;
    res.b -= vhs_temp * 0.15 - vhs_tint * 0.05;
    
    res = clamp(res, 0.0, 1.0);

    // ========================================================
    // 5. Tape Tracking Noise & Static Lines
    // ========================================================
    if (vhs_tape_noise > 0.0) {
        float noiseVal = tapeNoise(distortedUV, time);
        res = mix(res, vec3(noiseVal), noiseVal * vhs_tape_noise * 0.5);
    }

    // ========================================================
    // 6. CRT Scanline Effect
    // ========================================================
    if (vhs_scanline_str > 0.0) {
        float scanline = sin(distortedUV.y * TextureSize.y * 3.14159);
        scanline = 1.0 - (0.5 * (1.0 + scanline) * vhs_scanline_str);
        res *= scanline;
    }

    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}

#endif