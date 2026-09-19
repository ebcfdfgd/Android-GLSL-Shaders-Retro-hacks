#version 110

// ===== Retro Dithering & Blend Settings =====
#pragma parameter gb_palette         "Dithering - Palette Style"        0.0  0.0 1.0  1.0
#pragma parameter gb_hue_shift       "Dithering - Custom Hue Shift"     0.0  0.0 1.0  0.02
#pragma parameter gb_dither_strength "Dithering - Bayer Intensity"      0.35 0.0 1.0  0.05
#pragma parameter gb_pixel_size      "Dithering - Pixel Scale"          1.0  1.0 4.0  1.0
#pragma parameter SGPT_BLEND_LEVEL   "Blend Level"                      1.0  0.0 1.0  0.05

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
uniform vec2 InputSize;

uniform float gb_palette;
uniform float gb_hue_shift;
uniform float gb_dither_strength;
uniform float gb_pixel_size;
uniform float SGPT_BLEND_LEVEL;

const vec3 Y = vec3(0.299, 0.587, 0.114);

float luma(vec3 c)
{
    return dot(c, Y);
}

// ============================================================
// Matrix-based Hue Shifter
// ============================================================
vec3 shiftHue(vec3 color, float hue)
{
    float angle = hue * 6.28318531;

    float s = sin(angle);
    float c = cos(angle);

    mat3 rot = mat3(
        0.299 + 0.701*c + 0.168*s,
        0.587 - 0.587*c + 0.330*s,
        0.114 - 0.114*c - 0.497*s,

        0.299 - 0.299*c - 0.328*s,
        0.587 + 0.413*c + 0.035*s,
        0.114 - 0.114*c + 0.292*s,

        0.299 - 0.300*c + 1.250*s,
        0.587 - 0.588*c - 1.050*s,
        0.114 + 0.886*c + 0.203*s
    );

    return clamp(
        rot * color,
        0.0,
        1.0
    );
}

// ============================================================
// 4x4 Bayer Matrix
// ============================================================
float bayer4(vec2 p)
{
    vec2 pos = mod(p, 4.0);

    int ix = int(pos.x);
    int iy = int(pos.y);

    float m = 0.0;

    if (iy == 0) {
        if (ix == 0) m = 0.0;
        else if (ix == 1) m = 8.0;
        else if (ix == 2) m = 2.0;
        else m = 10.0;
    }
    else if (iy == 1) {
        if (ix == 0) m = 12.0;
        else if (ix == 1) m = 4.0;
        else if (ix == 2) m = 14.0;
        else m = 6.0;
    }
    else if (iy == 2) {
        if (ix == 0) m = 3.0;
        else if (ix == 1) m = 11.0;
        else if (ix == 2) m = 1.0;
        else m = 9.0;
    }
    else {
        if (ix == 0) m = 15.0;
        else if (ix == 1) m = 7.0;
        else if (ix == 2) m = 13.0;
        else m = 5.0;
    }

    return m / 16.0;
}

// ============================================================
// Palette Mapping (GameBoy Green & Custom Hue Tint only)
// ============================================================
vec3 getPaletteColor(
    float val,
    float paletteType,
    float hue
)
{
    vec3 c0, c1, c2, c3;

    if (paletteType < 0.5) {
        // Classic GameBoy Green
        c0 = vec3(0.06, 0.22, 0.06);
        c1 = vec3(0.18, 0.38, 0.18);
        c2 = vec3(0.54, 0.75, 0.22);
        c3 = vec3(0.85, 0.93, 0.60);
    }
    else {
        // Custom Hue Tint
        c0 = vec3(0.05, 0.05, 0.05);
        c1 = vec3(0.35, 0.35, 0.35);
        c2 = vec3(0.68, 0.68, 0.68);
        c3 = vec3(0.92, 0.92, 0.92);
    }

    vec3 resColor;

    if (val < 0.25)
        resColor = c0;
    else if (val < 0.50)
        resColor = c1;
    else if (val < 0.75)
        resColor = c2;
    else
        resColor = c3;

    if (paletteType >= 0.5) {
        resColor = shiftHue(
            resColor,
            hue
        );
    }

    return resColor;
}

void main()
{
    // ========================================================
    // 1. Game Pixel Grid
    // ========================================================

    vec2 gamePixelCoord =
        floor(
            uv *
            TextureSize /
            gb_pixel_size
        );

    vec2 coord =
        (
            gamePixelCoord *
            gb_pixel_size +
            gb_pixel_size * 0.5
        ) /
        TextureSize;

    // ========================================================
    // 2. SGPT Texture Fetches
    // ========================================================

    vec2 dx =
        vec2(
            1.0 / TextureSize.x,
            0.0
        );

    vec3 C =
        texture2D(
            Texture,
            coord
        ).rgb;

    vec3 L =
        texture2D(
            Texture,
            coord - dx
        ).rgb;

    vec3 R =
        texture2D(
            Texture,
            coord + dx
        ).rgb;

    // ========================================================
    // 3. SGPT Blend
    // ========================================================

    vec3 diffL = C - L;
    vec3 diffR = C - R;

    float wL =
        dot(
            abs(diffL),
            Y
        );

    float wR =
        dot(
            abs(diffR),
            Y
        );

    vec3 blendedColor =
        (wR < wL)
        ?
        (C - 0.5 * SGPT_BLEND_LEVEL * diffR)
        :
        (C - 0.5 * SGPT_BLEND_LEVEL * diffL);

    blendedColor =
        clamp(
            blendedColor,
            min(C, min(L, R)),
            max(C, max(L, R))
        );

    // ========================================================
    // 4. Dither on GAME PIXEL coordinates
    // ========================================================

    float lum =
        luma(blendedColor);

    float dither =
        bayer4(
            gamePixelCoord
        );

    float adjustedLum =
        clamp(
            lum +
            (dither - 0.5) *
            gb_dither_strength,
            0.0,
            1.0
        );

    // ========================================================
    // 5. Palette Mapping
    // ========================================================

    vec3 finalColor =
        getPaletteColor(
            adjustedLum,
            gb_palette,
            gb_hue_shift
        );

    // ========================================================
    // 6. Output
    // ========================================================

    gl_FragColor =
        vec4(
            finalColor,
            1.0
        );
}

#endif