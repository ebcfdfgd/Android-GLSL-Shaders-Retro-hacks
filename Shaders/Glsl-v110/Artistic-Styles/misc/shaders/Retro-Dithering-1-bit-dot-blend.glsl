#version 110

// ===== Retro Palette & Blend Settings =====
#pragma parameter gb_palette         "Palette Style"              0.0  0.0 1.0  1.0
#pragma parameter gb_hue_shift       "Custom Hue Shift"           0.0  0.0 1.0  0.02
#pragma parameter SGPT_BLEND_LEVEL   "Blend Level"                1.0  0.0 1.0  0.05

// ===== Ben-Day Dots =====
#pragma parameter DOT_DENSITY        "Dot Grid Size (px)"         3.0  3.0 16.0 0.5
#pragma parameter DOT_ANGLE          "Dot Grid Angle (deg)"       0.0  0.0 90.0 5.0
#pragma parameter DOT_STRENGTH       "Dot Shading Strength"       1.0  0.0 1.0  0.05

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

uniform float gb_palette;
uniform float gb_hue_shift;
uniform float SGPT_BLEND_LEVEL;

uniform float DOT_DENSITY;
uniform float DOT_ANGLE;
uniform float DOT_STRENGTH;

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
// Fixed-Size Ben-Day Dot Pattern
// ============================================================
float benDayDot(
    vec2 fragCoord,
    float density,
    float angleDeg
)
{
    float angle = radians(angleDeg);

    vec2 rotated = vec2(
        fragCoord.x * cos(angle) -
        fragCoord.y * sin(angle),

        fragCoord.x * sin(angle) +
        fragCoord.y * cos(angle)
    );

    vec2 cell =
        mod(rotated, density) -
        density * 0.5;

    float dist =
        length(cell);

    float radius =
        density * 0.30;

    return 1.0 -
        smoothstep(
            radius - 0.75,
            radius + 0.75,
            dist
        );
}

// ============================================================
// Palette Mapping (Green & Custom Hue Tint Only)
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
        // Custom Hue Tint Base
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
        resColor =
            shiftHue(
                resColor,
                hue
            );
    }

    return resColor;
}

void main()
{
    // ========================================================
    // 1. Original Game Pixel Coordinates
    // ========================================================

    vec2 gamePixelCoord =
        floor(
            uv * TextureSize
        );

    vec2 coord =
        (gamePixelCoord + 0.5) /
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

    vec3 diffL =
        C - L;

    vec3 diffR =
        C - R;

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
    // 4. Palette
    // ========================================================

    float lum =
        luma(blendedColor);

    vec3 finalColor =
        getPaletteColor(
            lum,
            gb_palette,
            gb_hue_shift
        );

    // ========================================================
    // 5. Ben-Day Dots
    // ========================================================

    float finalLum =
        luma(finalColor);

    float darkness =
        1.0 - finalLum;

    float dotPattern =
        benDayDot(
            gamePixelCoord,
            DOT_DENSITY,
            DOT_ANGLE
        );

    float dotMask =
        dotPattern *
        darkness *
        DOT_STRENGTH;

    finalColor =
        mix(
            finalColor,
            vec3(0.0),
            dotMask * 0.4
        );

    // ========================================================
    // 6. Output
    // ========================================================

    gl_FragColor =
        vec4(
            clamp(
                finalColor,
                0.0,
                1.0
            ),
            1.0
        );
}

#endif