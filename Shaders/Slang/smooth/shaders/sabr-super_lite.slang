#version 450

/*
    SABR-Lite
    A lightweight edge-directed pixel-art smoother (EPX / Scale2x style
    rule with an anti-aliased 45 degree cut, as in SABR).
    Only 5 texture fetches per pixel instead of 21, no heavy edge-weight math.
*/

#pragma parameter EDGE_THRESHOLD "Edge Threshold" 0.15 0.02 0.50 0.01
#pragma parameter SMOOTHNESS "Diagonal Smoothness" 0.20 0.02 0.50 0.01

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float EDGE_THRESHOLD;
    float SMOOTHNESS;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 tc;
layout(location = 1) out vec4 we;   // W.xy , E.zw
layout(location = 2) out vec4 ns;   // N.xy , S.zw

void main()
{
    gl_Position = global.MVP * Position;
    tc = TexCoord;

    float x = params.SourceSize.z;
    float y = params.SourceSize.w;

    we = vec4(tc.x - x, tc.y, tc.x + x, tc.y);
    ns = vec4(tc.x, tc.y - y, tc.x, tc.y + y);
}

#pragma stage fragment
layout(location = 0) in vec2 tc;
layout(location = 1) in vec4 we;
layout(location = 2) in vec4 ns;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

const vec3 lum = vec3(0.21, 0.72, 0.07);

void main()
{
    // 5 taps only
    vec3 C = texture(Source, tc).rgb;
    vec3 W = texture(Source, we.xy).rgb;
    vec3 E = texture(Source, we.zw).rgb;
    vec3 N = texture(Source, ns.xy).rgb;
    vec3 S = texture(Source, ns.zw).rgb;

    // Position inside the source pixel
    vec2 fp = fract(tc * params.SourceSize.xy);

    // Pick the two neighbours next to the current quadrant (H, V)
    // and the two opposite ones (Ho, Vo) - branch free
    vec2 q = step(vec2(0.5), fp);
    vec3 H  = mix(W, E, q.x);
    vec3 Ho = mix(E, W, q.x);
    vec3 V  = mix(N, S, q.y);
    vec3 Vo = mix(S, N, q.y);

    float lH  = dot(lum, H);
    float lHo = dot(lum, Ho);
    float lV  = dot(lum, V);
    float lVo = dot(lum, Vo);

    // Corner rule: H ~ V, and both differ from their opposite neighbours
    float thr  = params.EDGE_THRESHOLD;
    float cond = step(abs(lH - lV), thr)
               * step(thr, abs(lH - lHo))
               * step(thr, abs(lV - lVo));

    // Anti-aliased 45 degree cut across the corner of the pixel
    float t = dot(abs(fp - 0.5), vec2(1.0));
    float w = smoothstep(0.5 - params.SMOOTHNESS, 0.5 + params.SMOOTHNESS, t) * cond;

    FragColor = vec4(mix(C, 0.5 * (H + V), w), 1.0);
}
