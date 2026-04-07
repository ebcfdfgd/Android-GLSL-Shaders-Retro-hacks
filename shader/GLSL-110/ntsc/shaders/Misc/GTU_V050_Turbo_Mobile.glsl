// --- GTU v0.50 SHARP EDITION (MOBILE OPTIMIZED) ---
// Sharpness Fix: Original Pixel Restoration + High Res Default

#version 110

#pragma parameter signalResolution "Signal Sharpness (Luma)" 512.0 16.0 1024.0 16.0
#pragma parameter signalResolutionI "Chroma Sharpness I" 128.0 16.0 1024.0 16.0
#pragma parameter signalResolutionQ "Chroma Sharpness Q" 64.0 16.0 1024.0 16.0
#pragma parameter tvVerticalResolution "TV Vertical lines" 480.0 16.0 1024.0 16.0
#pragma parameter blackLevel "Black Level" 0.0 -0.20 0.20 0.01
#pragma parameter contrast "Contrast" 1.0 0.5 1.5 0.01

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
precision highp float;
#endif

uniform sampler2D Texture;
uniform vec2 TextureSize;
varying vec2 vTexCoord;

#ifdef PARAMETER_UNIFORM
uniform float signalResolution, signalResolutionI, signalResolutionQ, tvVerticalResolution, blackLevel, contrast;
#endif

const mat3 RGB_to_YIQ = mat3(0.299, 0.587, 0.114, 0.596, -0.274, -0.322, 0.211, -0.523, 0.311);
const mat3 YIQ_to_RGB = mat3(1.0, 0.956, 0.621, 1.0, -0.272, -0.647, 1.0, -1.106, 1.703);

// Improved Sampling: Center + Neighbors for Sharpness
vec3 get_signal_sample(vec2 uv, float res) {
    float offset = 1.0 / (res * 2.0); // تقليل مسافة الـ Blur
    vec3 center = texture2D(Texture, uv).rgb;
    vec3 side1  = texture2D(Texture, uv + vec2(offset, 0.0)).rgb;
    vec3 side2  = texture2D(Texture, uv - vec2(offset, 0.0)).rgb;
    // دمج البكسل الأصلي بنسبة 60% عشان يفضل حاد
    return mix(center, (side1 + side2) * 0.5, 0.4);
}

void main() {
    // 1. Process Signal
    vec3 sampleY = get_signal_sample(vTexCoord, signalResolution) * RGB_to_YIQ;
    vec3 sampleI = get_signal_sample(vTexCoord, signalResolutionI) * RGB_to_YIQ;
    vec3 sampleQ = get_signal_sample(vTexCoord, signalResolutionQ) * RGB_to_YIQ;

    // 2. Reconstruct
    vec3 yiq;
    yiq.x = sampleY.x; 
    yiq.y = sampleI.y; 
    yiq.z = sampleQ.z; 

    // 3. Convert back & Adjust
    vec3 rgb = clamp(yiq * YIQ_to_RGB, 0.0, 1.0);
    rgb = (rgb - vec3(blackLevel)) * contrast;

    // 4. Clean Scanlines (No more Blur on lines)
    float vertical_pos = vTexCoord.y * tvVerticalResolution;
    float scanline = abs(sin(vertical_pos * 3.14159));
    rgb *= mix(1.0, 0.90, scanline);

    gl_FragColor = vec4(rgb, 1.0);
}
#endif