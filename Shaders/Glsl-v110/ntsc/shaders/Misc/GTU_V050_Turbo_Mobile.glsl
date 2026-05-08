/* --- GTU v0.50 SHARP + ADVANCED RAINBOW (SAT & HUE EDITION) ---
    - REMOVED: Contrast control.
    - ADDED: Global Saturation & NTSC Hue (Tint).
    - RETAINED: GTU Sharpness, Black Level, & Vertical Scanlines.
*/

#version 110

#pragma parameter signalResolution "Signal Sharpness (Luma)" 320.0 16.0 1024.0 16.0
#pragma parameter signalResolutionI "Chroma Sharpness I" 128.0 16.0 1024.0 16.0
#pragma parameter signalResolutionQ "Chroma Sharpness Q" 64.0 16.0 1024.0 16.0
#pragma parameter tvVerticalResolution "TV Vertical lines" 480.0 16.0 1024.0 16.0
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
uniform float signalResolution, signalResolutionI, signalResolutionQ, tvVerticalResolution, blackLevel;
uniform float SATURATION, rb_power, rb_size, rb_detect, rb_speed, rb_tilt;
#endif

const mat3 RGB_to_YIQ = mat3(0.299, 0.587, 0.114, 0.596, -0.274, -0.322, 0.211, -0.523, 0.311);
const mat3 YIQ_to_RGB = mat3(1.0, 0.956, 0.621, 1.0, -0.272, -0.647, 1.0, -1.106, 1.703);

vec3 get_signal_sample(vec2 uv, float res) {
    float offset = 1.0 / (res * 2.0);
    vec3 center = texture2D(Texture, uv).rgb;
    vec3 side1  = texture2D(Texture, uv + vec2(offset, 0.0)).rgb;
    vec3 side2  = texture2D(Texture, uv - vec2(offset, 0.0)).rgb;
    return mix(center, (side1 + side2) * 0.5, 0.4);
}

void main() {
    vec2 ps = vec2(1.0 / TextureSize.x, 0.0);
    float time = float(FrameCount);

    // 1. Process Signal Samples
    vec3 sampleY_raw = get_signal_sample(vTexCoord, signalResolution);
    vec3 sampleY = sampleY_raw * RGB_to_YIQ;
    vec3 sampleI = get_signal_sample(vTexCoord, signalResolutionI) * RGB_to_YIQ;
    vec3 sampleQ = get_signal_sample(vTexCoord, signalResolutionQ) * RGB_to_YIQ;

    // 2. Reconstruct YIQ
    vec3 yiq;
    yiq.x = sampleY.x; 
    yiq.y = sampleI.y; 
    yiq.z = sampleQ.z; 

    // 3. Rainbow Artifacts Logic
    vec3 cL = texture2D(Texture, vTexCoord - ps).rgb;
    vec3 cR = texture2D(Texture, vTexCoord + ps).rgb;
    float yL = dot(cL, vec3(0.299, 0.587, 0.114));
    float yR = dot(cR, vec3(0.299, 0.587, 0.114));
    
    float edge = abs(yiq.x - yL) + abs(yiq.x - yR);
    float rb_mask = smoothstep(rb_detect, rb_detect + 0.1, edge) * step(0.001, rb_power);
    float ang = (vTexCoord.x * TextureSize.x / rb_size) + (vTexCoord.y * TextureSize.y * rb_tilt) + (time * rb_speed);
    
    yiq.y += sin(ang) * rb_power * rb_mask;
    yiq.z += cos(ang) * rb_power * rb_mask;

    // 4. Hue & Saturation Adjustment
    float rotatedI = yiq.y * hTrig.y - yiq.z * hTrig.x;
    float rotatedQ = yiq.y * hTrig.x + yiq.z * hTrig.y;
    yiq.y = rotatedI * SATURATION;
    yiq.z = rotatedQ * SATURATION;

    // 5. Convert back & Adjust Black Level
    vec3 rgb = clamp(yiq * YIQ_to_RGB, 0.0, 1.0);
    rgb -= vec3(blackLevel);

    // 6. Clean Scanlines
    float vertical_pos = vTexCoord.y * tvVerticalResolution;
    float scanline = abs(sin(vertical_pos * 3.14159));
    rgb *= mix(1.0, 0.90, scanline);

    gl_FragColor = vec4(clamp(rgb, 0.0, 1.0), 1.0);
}
#endif