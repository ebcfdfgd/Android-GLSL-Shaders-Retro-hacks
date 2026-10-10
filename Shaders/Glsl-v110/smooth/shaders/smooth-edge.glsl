#version 110

/*
    Smooth-Edge 5-Tap (GLSL / libretro)
    4 bilinear taps build a cubic B-spline smooth field,
    1 exact tap for the center pixel; the edge is the anti-aliased
    iso-contour of that field. Needs filter_linear = true.
*/

#pragma parameter EDGE_THRESHOLD "Edge Threshold (min contrast)" 0.015 0.005 0.20 0.005
#pragma parameter AA_WIDTH "Edge Anti-Alias Width" 0.75 0.25 2.00 0.05

#if defined(VERTEX)

attribute vec4 VertexCoord;
attribute vec4 TexCoord;
uniform mat4 MVPMatrix;

varying vec2 tc;

void main()
{
    gl_Position = MVPMatrix * VertexCoord;
    tc = TexCoord.xy;
}

#elif defined(FRAGMENT)

#ifdef GL_ES
#extension GL_OES_standard_derivatives : enable
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
#endif

uniform sampler2D Texture;
uniform vec2 TextureSize;

varying vec2 tc;

#ifdef PARAMETER_UNIFORM
uniform float EDGE_THRESHOLD;
uniform float AA_WIDTH;
#else
#define EDGE_THRESHOLD 0.015
#define AA_WIDTH 0.75
#endif

const vec3 lum = vec3(0.21, 0.72, 0.07);

void main()
{
    vec2 size = TextureSize;
    vec2 inv  = 1.0 / TextureSize;

    // Cubic B-spline weights (index space: texel centers at integers)
    vec2 pos = tc * size - 0.5;
    vec2 ip  = floor(pos);
    vec2 a   = pos - ip;
    vec2 a2  = a * a;
    vec2 a3  = a2 * a;

    vec2 w0 = (1.0 - a) * (1.0 - a) * (1.0 - a) / 6.0;
    vec2 w1 = (3.0 * a3 - 6.0 * a2 + 4.0) / 6.0;
    vec2 w2 = (-3.0 * a3 + 3.0 * a2 + 3.0 * a + 1.0) / 6.0;
    vec2 w3 = a3 / 6.0;

    vec2 g0 = w0 + w1;
    vec2 g1 = w2 + w3;
    vec2 h0 = (ip - 1.0 + w1 / g0 + 0.5) * inv;
    vec2 h1 = (ip + 1.0 + w3 / g1 + 0.5) * inv;

    // 5 fetches: 4 bilinear (smooth field) + 1 exact centre texel
    vec3 T00 = texture2D(Texture, vec2(h0.x, h0.y)).rgb;
    vec3 T10 = texture2D(Texture, vec2(h1.x, h0.y)).rgb;
    vec3 T01 = texture2D(Texture, vec2(h0.x, h1.y)).rgb;
    vec3 T11 = texture2D(Texture, vec2(h1.x, h1.y)).rgb;
    vec3 C   = texture2D(Texture, (floor(tc * size) + 0.5) * inv).rgb;

    // Smooth field
    vec3 F = g0.y * (g0.x * T00 + g1.x * T10)
           + g1.y * (g0.x * T01 + g1.x * T11);

    // Local darkest / brightest colour among the taps
    float lC = dot(lum, C);
    float l0 = dot(lum, T00);
    float l1 = dot(lum, T10);
    float l2 = dot(lum, T01);
    float l3 = dot(lum, T11);

    vec3  colLo = C;  float lLo = lC;
    vec3  colHi = C;  float lHi = lC;

    if (l0 < lLo) { lLo = l0; colLo = T00; }
    if (l1 < lLo) { lLo = l1; colLo = T10; }
    if (l2 < lLo) { lLo = l2; colLo = T01; }
    if (l3 < lLo) { lLo = l3; colLo = T11; }

    if (l0 > lHi) { lHi = l0; colHi = T00; }
    if (l1 > lHi) { lHi = l1; colHi = T10; }
    if (l2 > lHi) { lHi = l2; colHi = T01; }
    if (l3 > lHi) { lHi = l3; colHi = T11; }

    float contrast = lHi - lLo;

    // Position of the smooth field between the two colours
    float m = (dot(lum, F) - lLo) / max(contrast, 1e-4);

    // Anti-aliased iso-contour at 0.5, about 1 output pixel wide
    float w = fwidth(m) * AA_WIDTH + 1e-4;
    float s = smoothstep(0.5 - w, 0.5 + w, m);

    vec3 edge = mix(colLo, colHi, s);

    // Flat / low contrast areas keep the exact source pixel
    float e = smoothstep(EDGE_THRESHOLD, EDGE_THRESHOLD * 4.0, contrast);

    gl_FragColor = vec4(mix(C, edge, e), 1.0);
}
#endif
