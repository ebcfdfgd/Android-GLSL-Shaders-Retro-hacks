/* 777-CRT-ANALOG-MASTER (HIGH-PRECISION SENSITIVITY EDITION + SMART DITHER BLUR)
    - FIXED: Waterfall Dither Transparency completely resolved by optimizing neighbor blending.
    - REMARK: Rainbow Intensity (RAINBOW_STR) remains completely decoupled from sensitivity scaling.
    - ULTRA-OPTIMIZATION: Strictly locked to 5 HARD TEXTURE TAPS without adding a single extra fetch.
    - SUPER-LIGHTWEIGHT OPTIMIZATION: Removed pow() and smoothstep(), using lightning-fast subtraction thresholding.
    - OPTIMIZED: Replaced heavy sin-based noise with ultra-fast arithmetic pseudo-noise to fix stuttering.
*/

#pragma parameter CHROMA_BLEED_X "Composite YIQ Shift" 2.5 0.0 7.0 0.1
#pragma parameter BLUR_TAPS "Dither Blur Spread" 1.0 0.0 5.0 0.1
#pragma parameter NTSC_SAT "NTSC Saturation" 1.0 0.0 2.0 0.05
#pragma parameter BRIGHTNESS "NTSC Brightness" 1.0 0.5 1.5 0.02
#pragma parameter RAINBOW_STR "Rainbow Intensity" 0.35 0.0 1.5 0.01
#pragma parameter RAINBOW_SIZE "Rainbow Size/Frequency" 3.0 1.0 10.0 0.1
#pragma parameter RAINBOW_TILT "Rainbow Rotation/Tilt" 0.0 -5.0 5.0 0.1
#pragma parameter RAINBOW_SENS "Rainbow Edge Sensitivity" 2.0 0.0 5.0 0.1
#pragma parameter CRAWL_SPEED "Dot Crawl Traveling Speed" 0.0 0.0 5.0 0.01
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
    vec2 dy = vec2(0.0, 1.0 / TextureSize.y);

    vec2 blurX = dx * BLUR_TAPS;
    vec2 bleedX = dx * CHROMA_BLEED_X;

    // --- STRICT 5-TAP HARDWARE SAMPLING ---
    vec3 baseRGB        = texture2D(Texture, coord).rgb;          // Tap 1
    vec3 blurRGB        = texture2D(Texture, coord + blurX).rgb;    // Tap 2
    vec3 chromaLeftRGB  = texture2D(Texture, coord - bleedX).rgb;   // Tap 3
    vec3 chromaRightRGB = texture2D(Texture, coord + bleedX).rgb;   // Tap 4
    vec3 pixelUp        = texture2D(Texture, coord - dy).rgb;       // Tap 5

    // --- SMART ADAPTIVE DITHER MASK ENGINE ---
    float y_m = dot(baseRGB, lumaWeight);
    float y_l = dot(chromaLeftRGB, lumaWeight);
    float y_r = dot(blurRGB, lumaWeight);

    float is_dither = abs(y_m - y_l) * abs(y_m - y_r);
    float dither_mask = clamp(is_dither * 65.0, 0.0, 1.0); // حساسية أعلى لرصد الخطوط الرفيعة
    dither_mask *= clamp(1.0 - abs(y_l - y_r) * 5.0, 0.0, 1.0);

    // --- صهر خطوط الشلال العمودية عبر إعادة تدوير العينات الحالية ---
    vec3 side_avg = mix(chromaLeftRGB, blurRGB, 0.5);
    vec3 ditheredRGB = mix(baseRGB, side_avg, 0.5 * dither_mask);

    // --- Chroma / Luma Extraction ---
    vec3 mainYIQ = RGB_to_YIQ * ditheredRGB;
    float Y = mainYIQ.x; 

    vec3 yiqLeft  = RGB_to_YIQ * chromaLeftRGB;
    vec3 yiqRight = RGB_to_YIQ * chromaRightRGB;

    float bleedI = mix(yiqLeft.y, yiqRight.y, 0.5);
    float bleedQ = mix(yiqLeft.z, yiqRight.z, 0.5);

    float I = mix(mainYIQ.y, bleedI, 0.5);
    float Q = mix(mainYIQ.z, bleedQ, 0.5);

    // --- ULTRA-LIGHTWEIGHT HIGH-CONTRAST EDGE MASK (5 TAPS RECYCLED) ---
    float lumaCenter = dot(baseRGB, lumaWeight);
    
    float diffH = abs(dot(chromaLeftRGB, lumaWeight) - lumaCenter) + 
                  abs(dot(blurRGB,       lumaWeight) - lumaCenter);
    
    float diffV = abs(dot(pixelUp,       lumaWeight) - lumaCenter) * 2.0;

    // 1. Linear subtraction thresholding gate
    float edgeMask = clamp(((diffH + diffV) * RAINBOW_SENS) - 0.06, 0.0, 1.0);
    
    // 2. High jump boost simulation
    edgeMask = clamp(edgeMask * edgeMask * 3.5, 0.0, 1.0);

    // --- THE CHROME-CRAWL VELOCITY ENGINE ---
    float crawl_phase = float(FrameCount) * 1.57079632 * CRAWL_SPEED;
    float phase = (coord.x * TextureSize.x / RAINBOW_SIZE) + (coord.y * TextureSize.y * RAINBOW_TILT) + crawl_phase;
    
    float waveI = sin(phase) * RAINBOW_STR;
    float waveQ = cos(phase) * RAINBOW_STR;

    I += waveI * 0.4 * edgeMask;
    Q += waveQ * 0.4 * edgeMask;
    Y += waveI * 0.30 * edgeMask;

    // --- OPTIMIZED STATIC CABLE NOISE ENGINE (LIGHTWEIGHT) ---
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