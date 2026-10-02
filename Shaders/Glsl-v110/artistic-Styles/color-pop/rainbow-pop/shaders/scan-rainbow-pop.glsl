#version 110

/*
    Unichrome: Color Reduction + Grayscale + Selective Color + Rainbow Accent + Scanlines
    ------------------------------------------------------------------------------------
*/

#pragma parameter UNI_GAIN             "Contrast"                  1.0  0.5 2.0 0.05
#pragma parameter UNI_LEVEL            "Brightness"                0.0 -0.3 0.3 0.02
#pragma parameter UNI_ACCENT_THRESHOLD "Rainbow Highlight Threshold"  0.8  0.5 0.98 0.01
#pragma parameter UNI_ACCENT_STRENGTH  "Rainbow Accent Strength"     0.7  0.0 1.0 0.05
#pragma parameter UNI_RAINBOW_SCALE    "Rainbow Spatial Scale"       1.0  0.1 4.0 0.1
#pragma parameter UNI_RAINBOW_SPEED    "Rainbow Shimmer Speed"       0.15 0.0 1.0 0.01
#pragma parameter SEL_TARGET_HUE       "Selective Target Hue"        0.0  0.0 1.0 0.01
#pragma parameter SEL_HUE_WIDTH        "Selective Hue Range"         0.15 0.0 0.5 0.01
#pragma parameter SEL_MIN_SAT          "Selective Min Saturation"    0.3  0.0 1.0 0.05
#pragma parameter COLOR_LEVELS         "Color Reduction Levels"      16.0 2.0 32.0 1.0

// Scanlines Parameters
#pragma parameter scanline_amount      "Scanline Amount"           0.12 0.0 0.5 0.02
#pragma parameter scanline_scale       "Scanline Density"          1.0  1.0 4.0 0.5

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
precision mediump float;
#endif

varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform float FrameCount;
uniform float UNI_GAIN;
uniform float UNI_LEVEL;
uniform float UNI_ACCENT_THRESHOLD;
uniform float UNI_ACCENT_STRENGTH;
uniform float UNI_RAINBOW_SCALE;
uniform float UNI_RAINBOW_SPEED;
uniform float SEL_TARGET_HUE;
uniform float SEL_HUE_WIDTH;
uniform float SEL_MIN_SAT;
uniform float COLOR_LEVELS;

uniform float scanline_amount;
uniform float scanline_scale;

const vec3 Y = vec3(0.299, 0.587, 0.114);

vec3 hueColor(float h) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(h + K.xyz) * 6.0 - K.www);
    return clamp(p - K.xxx, 0.0, 1.0);
}

// RGB to HSV Conversion
vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// Scanline Pattern
float scanlinePattern(vec2 fragCoord, float scale) {
    float line = sin(fragCoord.y / scale * 3.14159);
    return line * 0.5 + 0.5;
}

void main() {
    vec2 gamePixel = floor(uv * TextureSize);

    vec3 C = texture2D(Texture, uv).rgb;
    float lum = clamp(dot(C, Y) * UNI_GAIN + UNI_LEVEL, 0.0, 1.0);

    // Base: Grayscale (Smooth gradient without 1-bit step)
    vec3 baseBW = vec3(lum);

    // Color Reduction applied to source colors
    vec3 reducedC = floor(C * COLOR_LEVELS) / COLOR_LEVELS;

    // Permanent Selective Color Logic with reduced colors
    vec3 hsv = rgb2hsv(reducedC);
    float hueDist = abs(hsv.x - SEL_TARGET_HUE);
    hueDist = min(hueDist, 1.0 - hueDist);
    float colorMask = (1.0 - smoothstep(SEL_HUE_WIDTH - 0.05, SEL_HUE_WIDTH + 0.05, hueDist))
                    * smoothstep(SEL_MIN_SAT - 0.1, SEL_MIN_SAT + 0.1, hsv.y);

    vec3 base = mix(baseBW, reducedC, colorMask);

    // Unichrome touch: Rainbow only on highest highlights
    float rainbowMask = smoothstep(
        UNI_ACCENT_THRESHOLD - 0.05,
        UNI_ACCENT_THRESHOLD + 0.05,
        lum
    );
    float hue = fract((gamePixel.x + gamePixel.y) * 0.01 * UNI_RAINBOW_SCALE
                        + FrameCount * UNI_RAINBOW_SPEED * 0.005);
    vec3 accent = hueColor(hue);

    vec3 result = mix(base, accent, rainbowMask * UNI_ACCENT_STRENGTH);

    // Scanlines Overlay
    float scan = scanlinePattern(
        uv * TextureSize,
        scanline_scale
    );

    result *= mix(
        1.0,
        scan,
        scanline_amount
    );

    gl_FragColor = vec4(clamp(result, 0.0, 1.0), 1.0);
}

#endif