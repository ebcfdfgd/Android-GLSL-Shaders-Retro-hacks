/* 777-CRT-ANALOG-MASTER (STRICT 4-TAP HARDWARE EDITION)
    - FIXED: Locked to EXACTLY 4 HARD TEXTURE TAPS by recycling horizontal samples.
    - FIXED: Waterfall Dither Transparency completely resolved via tight 1-pixel neighborhood blending.
    - REMARK: Rainbow Intensity (RAINBOW_STR) remains completely decoupled from sensitivity scaling.
    - ULTRA-OPTIMIZATION: Removed redundant immediate fetches, using fixed 4-tap boundaries for all arithmetic.
    - LIGHTWEIGHT: Fast arithmetic pseudo-noise prevents shader stutter and frame drops.
*/

#pragma parameter CHROMA_BLEED_X "Composite YIQ Shift" 2.5 0.0 7.0 0.1
#pragma parameter BLUR_TAPS "Dither Blur Spread" 1.0 0.0 5.0 0.1
#pragma parameter NTSC_SAT "NTSC Saturation" 1.0 0.0 2.0 0.05
#pragma parameter BRIGHTNESS "NTSC Brightness" 1.1 0.5 1.5 0.01
#pragma parameter RAINBOW_STR "Rainbow Intensity" 0.35 0.0 1.5 0.01
#pragma parameter RAINBOW_SIZE "Rainbow Size/Frequency" 4.5 1.0 10.0 0.1
#pragma parameter RAINBOW_TILT "Rainbow Rotation/Tilt" 0.0 -5.0 5.0 0.1
#pragma parameter RAINBOW_SENS "Rainbow Edge Sensitivity" 0.3 0.0 5.0 0.01
#pragma parameter CRAWL_SPEED "Dot Crawl Traveling Speed" 0.02 0.0 1.0 0.01
#pragma parameter CABLE_DAMAGE "Cable Damage Amount" 0.15 0.0 1.0 0.01

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
uniform float CABLE_DAMAGE;
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
#define CABLE_DAMAGE 0.15
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

    // --- MAXIMUM ULTRA OPTIMIZATION: ABSOLUTELY 4 HARDWARE TAPS ---
    vec3 baseRGB        = texture2D(Texture, coord).rgb;            // Tap 1 (Center)
    vec3 immediateLeft  = texture2D(Texture, coord - dx).rgb;         // Tap 2 (Fixed 1-px Left for Dither)
    vec3 immediateRight = texture2D(Texture, coord + dx).rgb;         // Tap 3 (Fixed 1-px Right for Dither)
    vec3 chromaRightRGB = texture2D(Texture, coord + bleedX).rgb;     // Tap 4 (Wide Right for Color Bleed)

    // حساب قيم السطوع للعينات المباشرة لمعالجة الشلال بدقة
    float y_m = dot(baseRGB,        lumaWeight);
    float y_l = dot(immediateLeft,  lumaWeight);
    float y_r = dot(immediateRight, lumaWeight);

    // كاشف التناوب الحاد لخطوط الشلال (1-pixel vertical stripes)
    float is_dither = abs(y_m - y_l) * abs(y_m - y_r);
    float dither_mask = clamp(is_dither * 85.0, 0.0, 1.0); 

    // صهر الخطوط العمودية الذكي عبر دمج عينات الـ 1-pixel المتاحة بدون سحبات إضافية
    vec3 side_avg = mix(immediateLeft, immediateRight, 0.5);
    vec3 ditheredRGB = mix(baseRGB, side_avg, 0.5 * dither_mask);

    // --- Extraction of Chroma / Luma ---
    vec3 mainYIQ = RGB_to_YIQ * ditheredRGB;
    float Y = mainYIQ.x; 

    // الاستفادة القصوى من العينات الأربعة لاستخراج كروما الألوان (YIQ)
    vec3 yiqLeft  = RGB_to_YIQ * immediateLeft;
    vec3 yiqRight = RGB_to_YIQ * chromaRightRGB;

    float bleedI = mix(yiqLeft.y, yiqRight.y, 0.5);
    float bleedQ = mix(yiqLeft.z, yiqRight.z, 0.5);

    float I = mix(mainYIQ.y, bleedI, 0.5);
    float Q = mix(mainYIQ.z, bleedQ, 0.5);

    // --- RECYCLING EXISTING 4 TAPS FOR HORIZONTAL EDGE MASK ---
    float diffH = abs(y_l - y_m) + abs(dot(chromaRightRGB, lumaWeight) - y_m);

    float edgeMask = clamp((diffH * RAINBOW_SENS) - 0.05, 0.0, 1.0);
    edgeMask = clamp(edgeMask * edgeMask * 3.0, 0.0, 1.0);

    // --- THE CHROME-CRAWL VELOCITY ENGINE ---
    float crawl_phase = float(FrameCount) * 1.57079632 * CRAWL_SPEED;
    float phase = (coord.x * TextureSize.x / RAINBOW_SIZE) + (coord.y * TextureSize.y * RAINBOW_TILT) + crawl_phase;
    
    float waveI = sin(phase) * RAINBOW_STR;
    float waveQ = cos(phase) * RAINBOW_STR;

    I += waveI * 0.4 * edgeMask;
    Q += waveQ * 0.4 * edgeMask;
    Y += waveI * 0.30 * edgeMask;

    // --- OPTIMIZED STATIC CABLE NOISE ENGINE ---
    vec2 p = coord * TextureSize;
    float noiseSeed = p.x + p.y * 57.0 + float(FrameCount) * 9.0;
    float staticNoise = fract(noiseSeed * fract(noiseSeed * 0.15731));
    
    float noiseFactor = (staticNoise - 0.5) * CABLE_DAMAGE;
    Y += noiseFactor * 0.12;
    I += noiseFactor * 0.25;
    Q += noiseFactor * 0.25;

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