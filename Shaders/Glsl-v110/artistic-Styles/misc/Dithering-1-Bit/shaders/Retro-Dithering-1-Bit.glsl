#version 110

#pragma parameter sep_c0       "--- [ Color 0 (Darkest) ] ---" 0.0 0.0 0.0 1.0
#pragma parameter c0_r         "Red"                           0.06 0.0 1.0 0.01
#pragma parameter c0_g         "Green"                         0.22 0.0 1.0 0.01
#pragma parameter c0_b         "Blue"                          0.06 0.0 1.0 0.01

#pragma parameter sep_c1       "--- [ Color 1 ] ---"           0.0 0.0 0.0 1.0
#pragma parameter c1_r         "Red"                           0.18 0.0 1.0 0.01
#pragma parameter c1_g         "Green"                         0.38 0.0 1.0 0.01
#pragma parameter c1_b         "Blue"                          0.18 0.0 1.0 0.01

#pragma parameter sep_c2       "--- [ Color 2 ] ---"           0.0 0.0 0.0 1.0
#pragma parameter c2_r         "Red"                           0.54 0.0 1.0 0.01
#pragma parameter c2_g         "Green"                         0.75 0.0 1.0 0.01
#pragma parameter c2_b         "Blue"                          0.22 0.0 1.0 0.01

#pragma parameter sep_c3       "--- [ Color 3 (Brightest) ] ---" 0.0 0.0 0.0 1.0
#pragma parameter c3_r         "Red"                           0.85 0.0 1.0 0.01
#pragma parameter c3_g         "Green"                         0.93 0.0 1.0 0.01
#pragma parameter c3_b         "Blue"                          0.60 0.0 1.0 0.01

#pragma parameter gb_dither_strength "Bayer Intensity"         0.35 0.0 1.0 0.05
#pragma parameter gb_pixel_size      "Pixel Scale"             1.0  1.0 4.0 1.0

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
precision highp float;
varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform vec2 InputSize;

uniform float sep_c0, c0_r, c0_g, c0_b;
uniform float sep_c1, c1_r, c1_g, c1_b;
uniform float sep_c2, c2_r, c2_g, c2_b;
uniform float sep_c3, c3_r, c3_g, c3_b;
uniform float gb_dither_strength, gb_pixel_size;

const vec3 Y = vec3(0.299, 0.587, 0.114);

float luma(vec3 c) { return dot(c, Y); }

float bayer4(vec2 p) {
    vec2 pos = mod(p, 4.0);
    int ix = int(pos.x);
    int iy = int(pos.y);
    float m = 0.0;
    if (iy == 0) {
        if (ix == 0) m = 0.0; else if (ix == 1) m = 8.0; else if (ix == 2) m = 2.0; else m = 10.0;
    } else if (iy == 1) {
        if (ix == 0) m = 12.0; else if (ix == 1) m = 4.0; else if (ix == 2) m = 14.0; else m = 6.0;
    } else if (iy == 2) {
        if (ix == 0) m = 3.0; else if (ix == 1) m = 11.0; else if (ix == 2) m = 1.0; else m = 9.0;
    } else {
        if (ix == 0) m = 15.0; else if (ix == 1) m = 7.0; else if (ix == 2) m = 13.0; else m = 5.0;
    }
    return m / 16.0;
}

vec3 getPaletteColor(float val) {
    vec3 c0 = vec3(c0_r, c0_g, c0_b);
    vec3 c1 = vec3(c1_r, c1_g, c1_b);
    vec3 c2 = vec3(c2_r, c2_g, c2_b);
    vec3 c3 = vec3(c3_r, c3_g, c3_b);
    if (val < 0.25) return c0;
    if (val < 0.50) return c1;
    if (val < 0.75) return c2;
    return c3;
}

void main() {
    vec2 gamePixelCoord = floor(uv * TextureSize / gb_pixel_size);
    vec2 coord = (gamePixelCoord * gb_pixel_size + gb_pixel_size * 0.5) / TextureSize;
    vec3 color = texture2D(Texture, coord).rgb;
    float lum = luma(color);
    float dither = bayer4(gamePixelCoord);
    float adjustedLum = clamp(lum + (dither - 0.5) * gb_dither_strength, 0.0, 1.0);
    vec3 finalColor = getPaletteColor(adjustedLum);
    gl_FragColor = vec4(finalColor, 1.0);
}
#endif