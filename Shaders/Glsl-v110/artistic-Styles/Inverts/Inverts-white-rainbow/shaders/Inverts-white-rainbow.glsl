#version 110

/*  
    - PURPOSE: Pure mathematical color inversion (with optional toggle) mixed with Rainbow Highlight features.
*/

#pragma parameter INV_ENABLE           "Enable Color Inversion"       1.0  0.0 1.0  1.0
#pragma parameter UNI_ACCENT_THRESHOLD "Rainbow Highlight Threshold"  0.8  0.0 0.98 0.01
#pragma parameter UNI_ACCENT_STRENGTH  "Rainbow Accent Strength"      0.7  0.0 1.0  0.05
#pragma parameter UNI_RAINBOW_SCALE    "Rainbow Spatial Scale"        1.0  0.1 4.0  0.1
#pragma parameter UNI_RAINBOW_SPEED    "Rainbow Shimmer Speed"        0.15 0.0 1.0  0.01

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord.xy;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 vTexCoord;
uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform float FrameCount;

uniform float INV_ENABLE;
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
    // 1. Read core color directly from the source
    vec3 core_col = texture2D(Texture, vTexCoord).rgb;
    
    // Calculate original luminance to target highlights for the rainbow
    float lum = clamp(dot(core_col, Y), 0.0, 1.0);
    
    // 2. Pure pixel-by-pixel mathematical inversion with toggle
    vec3 inverted_col = vec3(1.0) - core_col;
    vec3 base_col = mix(core_col, inverted_col, INV_ENABLE);

    // 3. Unichrome Touch: Rainbow only on highest highlights
    vec2 gamePixel = floor(vTexCoord * TextureSize);
    
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

    // 4. Output the final image
    gl_FragColor = vec4(clamp(result, 0.0, 1.0), 1.0);
}
#endif