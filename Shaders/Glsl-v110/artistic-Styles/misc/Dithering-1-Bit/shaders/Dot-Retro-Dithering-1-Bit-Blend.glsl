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

#pragma parameter SGPT_BLEND_LEVEL "Blend Level" 1.0 0.0 1.0 0.05
#pragma parameter DOT_DENSITY "Dot Grid Size (px)" 3.0 3.0 16.0 0.5
#pragma parameter DOT_ANGLE "Dot Grid Angle (deg)" 0.0 0.0 90.0 5.0
#pragma parameter DOT_STRENGTH "Dot Shading Strength" 1.0 0.0 1.0 0.05

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
uniform float sep_c0, sep_c1, sep_c2, sep_c3;
uniform float c0_r, c0_g, c0_b, c1_r, c1_g, c1_b, c2_r, c2_g, c2_b, c3_r, c3_g, c3_b;
uniform float SGPT_BLEND_LEVEL;
uniform float DOT_DENSITY, DOT_ANGLE, DOT_STRENGTH;

const vec3 Y = vec3(0.299, 0.587, 0.114);

float luma(vec3 c) { return dot(c, Y); }

float benDayDot(vec2 fragCoord, float density, float angleDeg) {
    float angle = radians(angleDeg);
    vec2 rotated = vec2(fragCoord.x * cos(angle) - fragCoord.y * sin(angle),
                        fragCoord.x * sin(angle) + fragCoord.y * cos(angle));
    vec2 cell = mod(rotated, density) - density * 0.5;
    float radius = density * 0.30;
    return 1.0 - smoothstep(radius - 0.75, radius + 0.75, length(cell));
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
    vec2 gamePixelCoord = floor(uv * TextureSize);
    vec2 coord = (gamePixelCoord + 0.5) / TextureSize;
    vec2 dx = vec2(1.0 / TextureSize.x, 0.0);

    vec3 C = texture2D(Texture, coord).rgb;
    vec3 L = texture2D(Texture, coord - dx).rgb;
    vec3 R = texture2D(Texture, coord + dx).rgb;

    float wL = dot(abs(C - L), Y);
    float wR = dot(abs(C - R), Y);

    vec3 blendedColor = (wR < wL) ? (C - 0.5 * SGPT_BLEND_LEVEL * (C - R)) : (C - 0.5 * SGPT_BLEND_LEVEL * (C - L));
    blendedColor = clamp(blendedColor, min(C, min(L, R)), max(C, max(L, R)));

    vec3 finalColor = getPaletteColor(luma(blendedColor));
    float darkness = 1.0 - luma(finalColor);
    float dotMask = benDayDot(gamePixelCoord, DOT_DENSITY, DOT_ANGLE) * darkness * DOT_STRENGTH;
    finalColor = mix(finalColor, vec3(0.0), dotMask * 0.4);

    gl_FragColor = vec4(clamp(finalColor, 0.0, 1.0), 1.0);
}
#endif