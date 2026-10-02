#version 110

/*  
    SGPT + Pure-Color-Inverter + Rainbow Accent Combined Shader
    - PURPOSE: Combines SGPT edge-preserving smoothing, optional color inversion, and rainbow highlights.
*/

#pragma parameter INV_ENABLE           "Enable Color Inversion"       1.0    0.0 1.0    1.0
#pragma parameter SGPT_BLEND_LEVEL     "SGPT Blend Level"             1.0    0.0 1.0    0.05
#pragma parameter UNI_ACCENT_THRESHOLD "Rainbow Highlight Threshold"  0.8    0.0 0.98 0.01
#pragma parameter UNI_ACCENT_STRENGTH  "Rainbow Accent Strength"      0.7    0.0 1.0  0.05
#pragma parameter UNI_RAINBOW_SCALE    "Rainbow Spatial Scale"        1.0    0.1 4.0  0.1
#pragma parameter UNI_RAINBOW_SPEED    "Rainbow Shimmer Speed"        0.15   0.0 1.0  0.01

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

uniform float INV_ENABLE;
uniform float SGPT_BLEND_LEVEL;
uniform float UNI_ACCENT_THRESHOLD;
uniform float UNI_ACCENT_STRENGTH;
uniform float UNI_RAINBOW_SCALE;
uniform float UNI_RAINBOW_SPEED;

const vec3 Y = vec3(0.299, 0.587, 0.114);

vec3 hueColor(float h) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(h + K.xyz) * 6.0 - K.www);
    return clamp(p - K.xxx, 0.0, 1.0);
}

void main() {
    vec2 dx = vec2(1.0 / TextureSize.x, 0.0);

    // [1] Read pixels (3 samples) for SGPT
    vec3 C = texture2D(Texture, uv).rgb;
    vec3 L = texture2D(Texture, uv - dx).rgb;
    vec3 R = texture2D(Texture, uv + dx).rgb;

    // [2] Calculate differences
    vec3 diffL = C - L;
    vec3 diffR = C - R;
    
    float wL = dot(abs(diffL), Y);
    float wR = dot(abs(diffR), Y);

    // [3] Direct Blend - SGPT
    vec3 sgptColor = (wR < wL) ? (C - 0.5 * SGPT_BLEND_LEVEL * diffR) 
                                : (C - 0.5 * SGPT_BLEND_LEVEL * diffL);

    // Clamp SGPT color to avoid overshooting
    sgptColor = clamp(sgptColor, min(C, min(L, R)), max(C, max(L, R)));

    // [4] Calculate luminance for rainbow highlights based on the processed SGPT color
    float lum = clamp(dot(sgptColor, Y), 0.0, 1.0);

    // [5] Pure mathematical color inversion with toggle
    vec3 inverted_col = vec3(1.0) - sgptColor;
    vec3 base_col = mix(sgptColor, inverted_col, INV_ENABLE);

    // [6] Rainbow Accent on highlights
    vec2 gamePixel = floor(uv * TextureSize);
    
    float rainbowMask = smoothstep(
        UNI_ACCENT_THRESHOLD - 0.05,
        UNI_ACCENT_THRESHOLD + 0.05,
        lum
    );
    
    float hue = fract((gamePixel.x + gamePixel.y) * 0.01 * UNI_RAINBOW_SCALE 
                        + FrameCount * UNI_RAINBOW_SPEED * 0.005);
    vec3 accent = hueColor(hue);

    // Apply rainbow over the base image
    vec3 result = mix(base_col, accent, rainbowMask * UNI_ACCENT_STRENGTH);

    // [7] Final Output
    gl_FragColor = vec4(clamp(result, 0.0, 1.0), 1.0);
}
#endif