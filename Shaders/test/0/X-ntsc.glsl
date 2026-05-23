/* 777-CRT-ANALOG-MASTER (HIGH-PRECISION SENSITIVITY EDITION)
    - FIXED: Edge detection rebuilt using close-neighborhood sampling.
    - FEATURE: Catches micro-dither, sub-pixel text, and sharp horizontal transitions perfectly.
    - REMARK: Rainbow Intensity (RAINBOW_STR) remains completely decoupled from sensitivity scaling.
    - ULTRA-OPTIMIZATION: Strictly locked to 4 HARD TEXTURE TAPS by making edge detection purely horizontal.
    - SUPER-LIGHTWEIGHT OPTIMIZATION: Removed pow() and smoothstep(), using lightning-fast subtraction thresholding.
*/

#pragma parameter CHROMA_BLEED_X "Composite YIQ Shift" 4.0 0.0 7.0 0.1
#pragma parameter BLUR_TAPS "Dither Blur Spread" 1.0 0.0 5.0 0.1
#pragma parameter NTSC_SAT "NTSC Saturation" 1.0 0.0 2.0 0.05
#pragma parameter BRIGHTNESS "NTSC Brightness" 1.1 0.5 1.5 0.01
#pragma parameter RAINBOW_STR "Rainbow Intensity" 0.35 0.0 1.5 0.01
#pragma parameter RAINBOW_SIZE "Rainbow Size/Frequency" 4.5 1.0 10.0 0.1
#pragma parameter RAINBOW_TILT "Rainbow Rotation/Tilt" 0.0 -5.0 5.0 0.1
#pragma parameter RAINBOW_SENS "Rainbow Edge Sensitivity" 0.3 0.0 5.0 0.01
#pragma parameter CRAWL_SPEED "Dot Crawl Traveling Speed" 0.02 0.0 1.0 0.01

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    uv = TexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform int FrameCount; 

varying vec2 uv;

#ifdef PARAMETER_UNIFORM
uniform float CHROMA_BLEED_X, BLUR_TAPS, NTSC_SAT, BRIGHTNESS;
uniform float RAINBOW_STR, RAINBOW_SIZE, RAINBOW_TILT, RAINBOW_SENS, CRAWL_SPEED;
#else
#define CHROMA_BLEED_X 2.5
#define BLUR_TAPS 1.0
#define NTSC_SAT 1.0
#define BRIGHTNESS 1.0
#define RAINBOW_STR 0.35
#define RAINBOW_SIZE 3.0
#define RAINBOW_TILT 1.5
#define RAINBOW_SENS 2.0
#define CRAWL_SPEED 1.0
#endif

const mat3 RGB_to_YIQ = mat3(
    0.299,  0.596,  0.211,
    0.587, -0.274, -0.523,
    0.114, -0.322,  0.312
);

const mat3 YIQ_to_RGB = mat3(
    1.0,    1.0,    1.0,
    0.956, -0.272, -1.106,
    0.621, -0.647,  1.703
);

const vec3 lumaWeight = vec3(0.299, 0.587, 0.114);

void main() {
    vec2 coord = uv;
    vec2 dx = vec2(1.0 / TextureSize.x, 0.0); 

    vec2 blurX = dx * BLUR_TAPS;
    vec2 bleedX = dx * CHROMA_BLEED_X;

    // --- STRICT 4-TAP HARDWARE SAMPLING ---
    vec3 baseRGB = texture2D(Texture, coord).rgb;
    vec3 blurRGB = texture2D(Texture, coord + blurX).rgb;
    vec3 chromaLeftRGB  = texture2D(Texture, coord - bleedX).rgb;
    vec3 chromaRightRGB = texture2D(Texture, coord + bleedX).rgb;

    // --- Chroma / Luma Extraction ---
    vec3 ditheredRGB = mix(baseRGB, blurRGB, 0.5);
    vec3 mainYIQ = RGB_to_YIQ * ditheredRGB;
    float Y = mainYIQ.x; 

    vec3 yiqLeft  = RGB_to_YIQ * chromaLeftRGB;
    vec3 yiqRight = RGB_to_YIQ * chromaRightRGB;

    float bleedI = mix(yiqLeft.y, yiqRight.y, 0.5);
    float bleedQ = mix(yiqLeft.z, yiqRight.z, 0.5);

    float I = mix(mainYIQ.y, bleedI, 0.5);
    float Q = mix(mainYIQ.z, bleedQ, 0.5);

    // --- ULTRA-LIGHTWEIGHT HIGH-CONTRAST EDGE MASK ---
    float lumaCenter = dot(baseRGB, lumaWeight);
    
    float diffH = abs(dot(chromaLeftRGB, lumaWeight) - lumaCenter) + 
                  abs(dot(blurRGB,       lumaWeight) - lumaCenter);

    // 1. عتبة تصفية أولية (بوابة طرح) لقتل الفروقات البسيطة في الأماكن الناعمة
    float edgeMask = clamp((diffH * RAINBOW_SENS) - 0.05, 0.0, 1.0);
    
    // 2. ضرب العينة في نفسها لتعزيز قفزة الحواف الحادة فوراً كبديل سريع لـ pow
    edgeMask = clamp(edgeMask * edgeMask * 3.0, 0.0, 1.0);

    // --- THE CHROME-CRAWL VELOCITY ENGINE ---
    float crawl_phase = float(FrameCount) * 1.57079632 * CRAWL_SPEED;
    float phase = (coord.x * TextureSize.x / RAINBOW_SIZE) + (coord.y * TextureSize.y * RAINBOW_TILT) + crawl_phase;
    
    float waveI = sin(phase) * RAINBOW_STR;
    float waveQ = cos(phase) * RAINBOW_STR;

    I += waveI * 0.4 * edgeMask;
    Q += waveQ * 0.4 * edgeMask;
    Y += waveI * 0.30 * edgeMask;

    // --- PURE ANALOG CONTROLS ---
    Y *= BRIGHTNESS;   
    I *= NTSC_SAT;     
    Q *= NTSC_SAT;

    // Reconstruct and output
    vec3 finalYIQ = vec3(Y, I, Q);
    vec3 finalRGB = YIQ_to_RGB * finalYIQ;

    gl_FragColor = vec4(clamp(finalRGB, 0.0, 1.0), 1.0);
}
#endif