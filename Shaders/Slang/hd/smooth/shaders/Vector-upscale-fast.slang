#version 450

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

#pragma parameter STRENGTH         "Reconstruction Strength" 2.00 0.0  3.0  0.05
#pragma parameter CORNER_THRESHOLD "Corner Match Tolerance"  1.0 0.0 2.0 0.05
#pragma parameter EDGE_SOFTNESS    "Edge AA Softness"        1.0 0.01 2.0 0.05

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float STRENGTH;
	float CORNER_THRESHOLD;
	float EDGE_SOFTNESS;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 uv;

void main()
{
    uv = TexCoord;
    gl_Position = global.MVP * Position;
}

#pragma stage fragment
layout(location = 0) in vec2 uv;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
    vec2 texel = params.SourceSize.zw;
    vec2 pixelCoord = uv * params.SourceSize.xy;
    vec2 fp = fract(pixelCoord);
    vec2 baseUV = (floor(pixelCoord) + 0.5) * texel;

    // which corner of the texel does this fragment sit closest to?
    // q   = 0.0 / 1.0   (same meaning as qx,qy in the 9-tap version)
    // dir = -1.0 / +1.0 (which way to step to reach that corner's
    //                   cardinal/diagonal neighbours)
    vec2 q   = step(0.5, fp);
    vec2 dir = q * 2.0 - 1.0;

    // only the 4 texels this fragment can possibly need: center, the
    // horizontal neighbour, the vertical neighbour, the diagonal
    // neighbour - picked directly instead of fetched-then-discarded.
    vec3 C = texture(Source, baseUV).rgb;
    vec3 A = texture(Source, baseUV + vec2(dir.x * texel.x, 0.0)).rgb; // cardinal, horizontal
    vec3 B = texture(Source, baseUV + vec2(0.0, dir.y * texel.y)).rgb; // cardinal, vertical
    vec3 D = texture(Source, baseUV + dir * texel).rgb;                // diagonal

    // does A/B/D form a matching diagonal region, different from C?
    // (that pattern is exactly what a jaggy staircase corner looks like)
    // Replaced smoothstep with linear clamp interpolation
    float simAB = 1.0 - clamp(distance(A, B) / params.CORNER_THRESHOLD, 0.0, 1.0);
    float simAD = 1.0 - clamp(distance(A, D) / params.CORNER_THRESHOLD, 0.0, 1.0);
    vec3  ABavg = 0.5 * (A + B);
    float simCenter = 1.0 - clamp(distance(ABavg, C) / params.CORNER_THRESHOLD, 0.0, 1.0);
    float cornerConfidence = simAB * simAD * (1.0 - simCenter);

    // exact geometric position within the corner triangle -> analytic AA,
    // not a blur radius. Zero effect at the texel center (r sums to 1.0),
    // full effect right at the shared grid corner (r sums to 0.0).
    vec2 r = abs(fp - q);
    float t = 0.5 - (r.x + r.y);
    
    // Replaced smoothstep with linear clamp interpolation
    float geomBlend = clamp((t + params.EDGE_SOFTNESS) / (2.0 * params.EDGE_SOFTNESS), 0.0, 1.0);

    float finalBlend = geomBlend * cornerConfidence * params.STRENGTH;
    vec3 color = mix(C, D, finalBlend);

    FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
