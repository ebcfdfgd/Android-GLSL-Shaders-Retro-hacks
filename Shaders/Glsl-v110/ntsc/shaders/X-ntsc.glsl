#version 110

/* 777-CRT-ANALOG-MASTER (TRIANGLE-WAVE OPTIMIZED)
    - FIXED: Removed sin/cos entirely for Adreno.
    - OPTIMIZED: Triangle Wave for Rainbow Crawl.
*/

#pragma parameter CHROMA_BLEED_X "Bleed" 4.0 0.0 7.0 0.1
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

uniform float CHROMA_BLEED_X, BLUR_TAPS, NTSC_SAT, BRIGHTNESS;
uniform float RAINBOW_STR, RAINBOW_SIZE, RAINBOW_TILT, RAINBOW_SENS, CRAWL_SPEED;

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

// دالة الموجة المثلثية السريعة (بديلة sin/cos)
vec2 triangle_wave(float x) {
    vec2 val = abs(fract(vec2(x * 0.159, x * 0.159 + 0.25)) * 2.0 - 1.0) * 2.0 - 1.0;
    return val;
}

void main() {
    vec2 dx = vec2(1.0 / TextureSize.x, 0.0); 
    vec2 blurX = dx * BLUR_TAPS;
    vec2 bleedX = dx * CHROMA_BLEED_X;

    vec3 baseRGB = texture2D(Texture, uv).rgb;
    vec3 blurRGB = texture2D(Texture, uv + blurX).rgb;
    vec3 chromaLeftRGB  = texture2D(Texture, uv - bleedX).rgb;
    vec3 chromaRightRGB = texture2D(Texture, uv + bleedX).rgb;

    vec3 mainYIQ = RGB_to_YIQ * mix(baseRGB, blurRGB, 0.5);
    float Y = mainYIQ.x; 

    vec3 yiqLeft  = RGB_to_YIQ * chromaLeftRGB;
    vec3 yiqRight = RGB_to_YIQ * chromaRightRGB;

    float I = mix(mainYIQ.y, mix(yiqLeft.y, yiqRight.y, 0.5), 0.5);
    float Q = mix(mainYIQ.z, mix(yiqLeft.z, yiqRight.z, 0.5), 0.5);

    float lumaCenter = dot(baseRGB, lumaWeight);
    float diffH = abs(dot(chromaLeftRGB, lumaWeight) - lumaCenter) + abs(dot(blurRGB, lumaWeight) - lumaCenter);

    float edgeMask = clamp((diffH * RAINBOW_SENS) - 0.05, 0.0, 1.0);
    edgeMask = clamp(edgeMask * edgeMask * 3.0, 0.0, 1.0);

    float crawl_phase = float(FrameCount) * 0.5 * CRAWL_SPEED;
    float phase = (uv.x * TextureSize.x / RAINBOW_SIZE) + (uv.y * TextureSize.y * RAINBOW_TILT) + crawl_phase;
    
    // استدعاء دالة الموجة المثلثية
    vec2 wave = triangle_wave(phase);
    
    I += wave.x * RAINBOW_STR * 0.4 * edgeMask;
    Q += wave.y * RAINBOW_STR * 0.4 * edgeMask;
    Y += wave.x * RAINBOW_STR * 0.30 * edgeMask;

    gl_FragColor = vec4(clamp(YIQ_to_RGB * vec3(Y * BRIGHTNESS, I * NTSC_SAT, Q * NTSC_SAT), 0.0, 1.0), 1.0);
}
#endif