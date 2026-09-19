#version 110

#pragma parameter PALETTE_DOMINANCE "Palette Dominance (4-Colors)" 0.80 0.0 1.0 0.05

// 4-Color Palette Controls (Obama Pop Art Poster Colors)
#pragma parameter C1_R "Color 1 (Dark Blue) Red" 0.00 0.0 1.0 0.01
#pragma parameter C1_G "Color 1 (Dark Blue) Green" 0.20 0.0 1.0 0.01
#pragma parameter C1_B "Color 1 (Dark Blue) Blue" 0.30 0.0 1.0 0.01

#pragma parameter C2_R "Color 2 (Red) Red" 0.84 0.0 1.0 0.01
#pragma parameter C2_G "Color 2 (Red) Green" 0.10 0.0 1.0 0.01
#pragma parameter C2_B "Color 2 (Red) Blue" 0.13 0.0 1.0 0.01

#pragma parameter C3_R "Color 3 (Light Blue) Red" 0.47 0.0 1.0 0.01
#pragma parameter C3_G "Color 3 (Light Blue) Green" 0.60 0.0 1.0 0.01
#pragma parameter C3_B "Color 3 (Light Blue) Blue" 0.65 0.0 1.0 0.01

#pragma parameter C4_R "Color 4 (Beige) Red" 0.99 0.0 1.0 0.01
#pragma parameter C4_G "Color 4 (Beige) Green" 0.90 0.0 1.0 0.01
#pragma parameter C4_B "Color 4 (Beige) Blue" 0.66 0.0 1.0 0.01

// Ben-Day Dots
#pragma parameter DOT_DENSITY  "Dot Grid Size (px)"    6.0  3.0 16.0 0.5
#pragma parameter DOT_ANGLE    "Dot Grid Angle (deg)"  15.0 0.0 90.0 5.0
#pragma parameter DOT_STRENGTH "Dot Shading Strength"  0.85 0.0 1.0 0.05

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

uniform float PALETTE_DOMINANCE;

uniform float C1_R, C1_G, C1_B;
uniform float C2_R, C2_G, C2_B;
uniform float C3_R, C3_G, C3_B;
uniform float C4_R, C4_G, C4_B;

uniform float DOT_DENSITY;
uniform float DOT_ANGLE;
uniform float DOT_STRENGTH;

const vec3 Y = vec3(0.299, 0.587, 0.114);

// ============================================================
// BEN-DAY DOT PATTERN
// ============================================================
float benDayDot(vec2 fragCoord, float density, float angleDeg, float darkness)
{
    float angle = radians(angleDeg);

    vec2 rotated = vec2(
        fragCoord.x * cos(angle) - fragCoord.y * sin(angle),
        fragCoord.x * sin(angle) + fragCoord.y * cos(angle)
    );

    vec2 cell = mod(rotated, density) - density * 0.5;

    float dist = length(cell);

    float radius = darkness * (density * 0.5);

    return 1.0 - smoothstep(
        radius - 1.0,
        radius + 1.0,
        dist
    );
}

void main() {

    vec3 gameColor = texture2D(Texture, uv).rgb;

    // ========================================================
    // Calculate Posterized Palette Target
    // ========================================================
    float lum = dot(gameColor, Y);
    vec3 posterized;

    if (lum < 0.25) {
        posterized = vec3(C1_R, C1_G, C1_B);
    }
    else if (lum < 0.50) {
        posterized = vec3(C2_R, C2_G, C2_B);
    }
    else if (lum < 0.75) {
        posterized = vec3(C3_R, C3_G, C3_B);
    }
    else {
        posterized = vec3(C4_R, C4_G, C4_B);
    }

    // ========================================================
    // Blend Original + 4-Color Palette
    // ========================================================
    vec3 color = mix(
        gameColor,
        posterized,
        PALETTE_DOMINANCE
    );

    // ========================================================
    // Ben-Day Dots
    // ========================================================
    float finalLum = dot(color, Y);

    // Darker areas receive stronger dots
    float darkness = 1.0 - finalLum;

    float dot = benDayDot(
        uv * TextureSize,
        DOT_DENSITY,
        DOT_ANGLE,
        darkness
    );

    // Apply dots only as dark shading
    color = mix(
        color,
        vec3(0.0),
        dot * DOT_STRENGTH * 0.4
    );

    gl_FragColor = vec4(
        clamp(color, 0.0, 1.0),
        1.0
    );
}

#endif