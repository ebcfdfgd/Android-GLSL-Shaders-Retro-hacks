#version 450

/*
    Smooth-Edge 5-Tap
    Contour reconstruction for pixel art:
      - 4 bilinear taps build a cubic B-spline smooth field (4x4 support)
      - 1 exact tap for the center pixel
      - the edge is the iso-contour of that field between the local
        dark/bright colours, drawn with a ~1 output pixel anti-aliased width
    Result: edges at ANY angle become smooth lines instead of stair steps.
    Needs: filter_linear = true in the preset.
*/

#pragma parameter EDGE_THRESHOLD "Edge Threshold (min contrast)" 0.015 0.005 0.20 0.005
#pragma parameter AA_WIDTH "Edge Anti-Alias Width" 0.75 0.25 2.00 0.05

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float EDGE_THRESHOLD;
    float AA_WIDTH;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 tc;

void main()
{
    gl_Position = global.MVP * Position;
    tc = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 tc;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

const vec3 lum = vec3(0.21, 0.72, 0.07);

void main()
{
    vec2 size = params.SourceSize.xy;
    vec2 inv  = params.SourceSize.zw;

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
    vec3 T00 = texture(Source, vec2(h0.x, h0.y)).rgb;
    vec3 T10 = texture(Source, vec2(h1.x, h0.y)).rgb;
    vec3 T01 = texture(Source, vec2(h0.x, h1.y)).rgb;
    vec3 T11 = texture(Source, vec2(h1.x, h1.y)).rgb;
    vec3 C   = texture(Source, (floor(tc * size) + 0.5) * inv).rgb;

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
    float w = fwidth(m) * params.AA_WIDTH + 1e-4;
    float s = smoothstep(0.5 - w, 0.5 + w, m);

    vec3 edge = mix(colLo, colHi, s);

    // Flat / low contrast areas keep the exact source pixel
    float e = smoothstep(params.EDGE_THRESHOLD, params.EDGE_THRESHOLD * 4.0, contrast);

    FragColor = vec4(mix(C, edge, e), 1.0);
}
