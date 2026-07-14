#version 110

/*
    Vector Edge Reconstruct - v110 (single pass, RetroArch)
    -------------------------------------------------------------------
    NOT a blur filter. This does not soften the whole image.

    It looks at the raw low-res pixel grid, finds the exact spots where
    a jagged "staircase" corner exists (two matching neighbor pixels
    of a different color meeting diagonally around the current pixel),
    and replaces ONLY that small triangular corner area with a precise,
    analytically anti-aliased 45-degree cut - like the corner was
    always vector art.

    Flat areas, straight horizontal/vertical edges, text, HUDs: 100%
    pixel-identical to the source, completely untouched. Only actual
    diagonal staircase corners are touched, and only right at the corner.

    Cost: 9 texture fetches, no branching, single pass, no LUT. Cheap
    enough to run at full speed on a phone.

    IMPORTANT: for this to work correctly, this pass must receive a
    crisp, non-blurred image. In RetroArch's shader pass settings for
    THIS shader, set "Filter" to "Nearest" (not Linear), otherwise the
    corner-detection math analyzes an already-softened image.
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

#pragma parameter STRENGTH         "Reconstruction Strength" 2.00 0.0  3.0  0.05
#pragma parameter CORNER_THRESHOLD "Corner Match Tolerance"  1.0 0.0 1.0 0.01
#pragma parameter EDGE_SOFTNESS    "Edge AA Softness"        0.3 0.01 1.0 0.01

void main()
{
    vec2 texel = 1.0 / TextureSize;
    vec2 pixelCoord = uv * TextureSize;
    vec2 fp = fract(pixelCoord);
    vec2 baseUV = (floor(pixelCoord) + 0.5) * texel;

    vec3 C  = texture2D(Texture, baseUV).rgb;
    vec3 N  = texture2D(Texture, baseUV + vec2(0.0,      texel.y)).rgb;
    vec3 S  = texture2D(Texture, baseUV - vec2(0.0,      texel.y)).rgb;
    vec3 E  = texture2D(Texture, baseUV + vec2(texel.x,  0.0)).rgb;
    vec3 W  = texture2D(Texture, baseUV - vec2(texel.x,  0.0)).rgb;
    vec3 NE = texture2D(Texture, baseUV + vec2(texel.x,  texel.y)).rgb;
    vec3 NW = texture2D(Texture, baseUV + vec2(-texel.x, texel.y)).rgb;
    vec3 SE = texture2D(Texture, baseUV + vec2(texel.x, -texel.y)).rgb;
    vec3 SW = texture2D(Texture, baseUV + vec2(-texel.x,-texel.y)).rgb;

    // which corner of the texel does this fragment sit closest to?
    float qx = step(0.5, fp.x);
    float qy = step(0.5, fp.y);

    vec3 A = mix(W, E, qx);                       // cardinal neighbor (horizontal)
    vec3 B = mix(S, N, qy);                       // cardinal neighbor (vertical)
    vec3 D = mix(mix(SW, SE, qx), mix(NW, NE, qx), qy); // diagonal neighbor

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
    vec2 r = abs(fp - vec2(qx, qy));
    float t = 0.5 - (r.x + r.y);
    float geomBlend = smoothstep(-EDGE_SOFTNESS, EDGE_SOFTNESS, t);

    float finalBlend = geomBlend * cornerConfidence * STRENGTH;
    vec3 color = mix(C, D, finalBlend);

    gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}

#endif
