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

#pragma parameter SCANLINE_AMOUNT "Scanline Strength" 0.12 0.0 0.5 0.02
#pragma parameter SCANLINE_SCALE  "Scanline Density"  1.0  1.0 4.0 0.5

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
precision highp float;
#endif

varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize;

uniform float c0_r, c0_g, c0_b;
uniform float c1_r, c1_g, c1_b;
uniform float c2_r, c2_g, c2_b;
uniform float c3_r, c3_g, c3_b;

uniform float SCANLINE_AMOUNT;
uniform float SCANLINE_SCALE;

const vec3 Y = vec3(0.299, 0.587, 0.114);

float luma(vec3 c) {
    return dot(c, Y);
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

// Same scanline function as the Color Pop shader (works at density 1.0)
float scanlinePattern(vec2 fragCoord, float scale)
{
    float line = sin(
        fragCoord.y / scale * 3.14159
    );

    return line * 0.5 + 0.5;
}

void main() {
    // Pixel-perfect color sampling (palette stays blocky)
    vec2 gamePixelCoord = floor(uv * TextureSize);
    vec2 coord = (gamePixelCoord + 0.5) / TextureSize;

    vec3 color = texture2D(Texture, coord).rgb;

    // Four-color palette
    vec3 finalColor = getPaletteColor(luma(color));

    // CRT scanlines (continuous coordinate, same as Color Pop shader)
    float scan = scanlinePattern(
        uv * TextureSize,
        SCANLINE_SCALE
    );

    finalColor *= mix(
        1.0,
        scan,
        SCANLINE_AMOUNT
    );

    gl_FragColor = vec4(
        clamp(finalColor, 0.0, 1.0),
        1.0
    );
}

#endif