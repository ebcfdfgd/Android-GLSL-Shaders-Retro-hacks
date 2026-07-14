#version 110

/*
    Vector Edge Reconstruct - Fast variant (single pass, RetroArch)
    -------------------------------------------------------------------
    Same algorithm, same output as the 9-tap version - just computed
    with 4 texture fetches instead of 9.

    The 9-tap version fetches the full 3x3 neighbourhood (N,S,E,W,NE,
    NW,SE,SW) every fragment, then throws away 5 of those 8 neighbours
    with mix() - only one cardinal-X, one cardinal-Y and one diagonal
    neighbour are ever actually used, chosen by which quadrant of the
    texel the fragment sits in. This version works out that quadrant
    FIRST (as a direction vector) and fetches only the 3 neighbours it
    needs, plus the center pixel.

    Texture fetch instructions are the most expensive part of a filter
    like this - well above the handful of distance()/smoothstep() calls -
    so this is where the speed gain comes from. The corner-detection
    math, the analytic AA falloff, and the parameter ranges are all
    untouched on purpose: same value per pixel, not a cheaper
    approximation of it.

    Cost: 4 texture fetches, no branching, single pass, no LUT.

    IMPORTANT: same requirement as the original - this pass must
    receive a crisp, non-blurred image. Set "Filter" to "Nearest" on
    THIS pass in RetroArch's shader settings.
*/

#if defined(VERTEX)

attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
uniform mat4 MVPMatrix;

void main()
{
    uv = TexCoord;
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)

#ifdef GL_ES
precision mediump float;
#else
precision highp float;
#endif

varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform vec2 InputSize;
uniform vec2 OutputSize;

#ifdef PARAMETER_UNIFORM
uniform float STRENGTH;
uniform float CORNER_THRESHOLD;
uniform float EDGE_SOFTNESS;
#else
    #define STRENGTH         1.00
    #define CORNER_THRESHOLD 0.15
    #define EDGE_SOFTNESS    0.08
#endif

#pragma parameter STRENGTH         "Reconstruction Strength" 2.00 0.0  1.0  0.05
#pragma parameter CORNER_THRESHOLD "Corner Match Tolerance"  1.0 0.02 1.0 0.05
#pragma parameter EDGE_SOFTNESS    "Edge AA Softness"        0.08 0.01 0.30 0.01

void main()
{
    vec2 texel = 1.0 / TextureSize;
    vec2 pixelCoord = uv * TextureSize;
    vec2 fp = fract(pixelCoord);
    vec2 baseUV = (floor(pixelCoord) + 0.5) * texel;

    // which corner of the texel does this fragment sit closest to?
    // q   = 0.0 / 1.0   (same meaning as qx,qy in the 9-tap version)
    // dir = -1.0 / +1.0 (which way to step to reach that corner's
    //                    cardinal/diagonal neighbours)
    vec2 q   = step(0.5, fp);
    vec2 dir = q * 2.0 - 1.0;

    // only the 4 texels this fragment can possibly need: center, the
    // horizontal neighbour, the vertical neighbour, the diagonal
    // neighbour - picked directly instead of fetched-then-discarded.
    vec3 C = texture2D(Texture, baseUV).rgb;
    vec3 A = texture2D(Texture, baseUV + vec2(dir.x * texel.x, 0.0)).rgb; // cardinal, horizontal
    vec3 B = texture2D(Texture, baseUV + vec2(0.0, dir.y * texel.y)).rgb; // cardinal, vertical
    vec3 D = texture2D(Texture, baseUV + dir * texel).rgb;                // diagonal

    // does A/B/D form a matching diagonal region, different from C?
    // (that pattern is exactly what a jaggy staircase corner looks like)
    float simAB = 1.0 - smoothstep(0.0, CORNER_THRESHOLD, distance(A, B));
    float simAD = 1.0 - smoothstep(0.0, CORNER_THRESHOLD, distance(A, D));
    vec3  ABavg = 0.5 * (A + B);
    float simCenter = 1.0 - smoothstep(0.0, CORNER_THRESHOLD, distance(ABavg, C));
    float cornerConfidence = simAB * simAD * (1.0 - simCenter);

    // exact geometric position within the corner triangle -> analytic AA,
    // not a blur radius. Zero effect at the texel center (r sums to 1.0),
    // full effect right at the shared grid corner (r sums to 0.0).
    vec2 r = abs(fp - q);
    float t = 0.5 - (r.x + r.y);
    float geomBlend = smoothstep(-EDGE_SOFTNESS, EDGE_SOFTNESS, t);

    float finalBlend = geomBlend * cornerConfidence * STRENGTH;
    vec3 color = mix(C, D, finalBlend);

    gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}

#endif
