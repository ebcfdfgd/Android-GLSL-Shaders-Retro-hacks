#version 450

/*
    SABR v3.0 Shader - Optimized Edition
    Original Algorithm: Joshua Street / Hyllian
    Speed Optimization: Performance Refined
    Converted from GLSL to Slang (RetroArch)
*/

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 tc;
layout(location = 1) out vec4 xyp_1_2_3;
layout(location = 2) out vec4 xyp_6_7_8;
layout(location = 3) out vec4 xyp_11_12_13;
layout(location = 4) out vec4 xyp_16_17_18;
layout(location = 5) out vec4 xyp_21_22_23;
layout(location = 6) out vec4 xyp_5_10_15;
layout(location = 7) out vec4 xyp_9_14_9;

void main()
{
    gl_Position = global.MVP * Position;

    float x = params.SourceSize.z;
    float y = params.SourceSize.w;

    // Original alignment correction
    tc = TexCoord * vec2(1.0004, 1.0);

    // Pack the sample coordinates to reduce fragment work
    xyp_1_2_3    = tc.xxxy + vec4(-x, 0.0, x, -2.0 * y);
    xyp_6_7_8    = tc.xxxy + vec4(-x, 0.0, x, -y);
    xyp_11_12_13 = tc.xxxy + vec4(-x, 0.0, x, 0.0);
    xyp_16_17_18 = tc.xxxy + vec4(-x, 0.0, x, y);
    xyp_21_22_23 = tc.xxxy + vec4(-x, 0.0, x, 2.0 * y);
    xyp_5_10_15  = tc.xyyy + vec4(-2.0 * x, -y, 0.0, y);
    xyp_9_14_9   = tc.xyyy + vec4(2.0 * x, -y, 0.0, y);
}

#pragma stage fragment
layout(location = 0) in vec2 tc;
layout(location = 1) in vec4 xyp_1_2_3;
layout(location = 2) in vec4 xyp_6_7_8;
layout(location = 3) in vec4 xyp_11_12_13;
layout(location = 4) in vec4 xyp_16_17_18;
layout(location = 5) in vec4 xyp_21_22_23;
layout(location = 6) in vec4 xyp_5_10_15;
layout(location = 7) in vec4 xyp_9_14_9;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

// Constants
const vec4 Ai  = vec4( 1.0, -1.0, -1.0,  1.0);
const vec4 B45 = vec4( 1.0,  1.0, -1.0, -1.0);
const vec4 C45 = vec4( 1.5,  0.5, -0.5,  0.5);
const vec4 M45 = vec4(0.4);
const vec3 lum = vec3(0.21, 0.72, 0.07);

vec4 lum_to(vec3 v0, vec3 v1, vec3 v2, vec3 v3)
{
    return vec4(dot(lum, v0), dot(lum, v1), dot(lum, v2), dot(lum, v3));
}

vec4 lum_wd(vec4 a, vec4 b, vec4 c, vec4 d, vec4 e, vec4 f, vec4 g, vec4 h)
{
    return abs(a - b) + abs(a - c) + abs(d - e) + abs(d - f) + 4.0 * abs(g - h);
}

void main()
{
    // Source lookups
    vec3 P1  = texture(Source, xyp_1_2_3.xw).rgb;
    vec3 P2  = texture(Source, xyp_1_2_3.yw).rgb;
    vec3 P3  = texture(Source, xyp_1_2_3.zw).rgb;
    vec3 P6  = texture(Source, xyp_6_7_8.xw).rgb;
    vec3 P7  = texture(Source, xyp_6_7_8.yw).rgb;
    vec3 P8  = texture(Source, xyp_6_7_8.zw).rgb;
    vec3 P11 = texture(Source, xyp_11_12_13.xw).rgb;
    vec3 P12 = texture(Source, xyp_11_12_13.yw).rgb;
    vec3 P13 = texture(Source, xyp_11_12_13.zw).rgb;
    vec3 P16 = texture(Source, xyp_16_17_18.xw).rgb;
    vec3 P17 = texture(Source, xyp_16_17_18.yw).rgb;
    vec3 P18 = texture(Source, xyp_16_17_18.zw).rgb;
    vec3 P21 = texture(Source, xyp_21_22_23.xw).rgb;
    vec3 P22 = texture(Source, xyp_21_22_23.yw).rgb;
    vec3 P23 = texture(Source, xyp_21_22_23.zw).rgb;
    vec3 P5  = texture(Source, xyp_5_10_15.xy).rgb;
    vec3 P10 = texture(Source, xyp_5_10_15.xz).rgb;
    vec3 P15 = texture(Source, xyp_5_10_15.xw).rgb;
    vec3 P9  = texture(Source, xyp_9_14_9.xy).rgb;
    vec3 P14 = texture(Source, xyp_9_14_9.xz).rgb;
    vec3 P19 = texture(Source, xyp_9_14_9.xw).rgb;

    // Luminance vectors
    vec4 p7  = lum_to(P7, P11, P17, P13);
    vec4 p8  = lum_to(P8, P6, P16, P18);
    vec4 p11 = p7.yzwx;
    vec4 p12 = vec4(dot(lum, P12));
    vec4 p13 = p7.wxyz;
    vec4 p14 = lum_to(P14, P2, P10, P22);
    vec4 p16 = p8.zwxy;
    vec4 p17 = p7.zwxy;
    vec4 p18 = p8.wxyz;
    vec4 p19 = lum_to(P19, P3, P5, P21);
    vec4 p22 = p14.wxyz;
    vec4 p23 = lum_to(P23, P9, P1, P15);

    vec2 fp = fract(tc * params.SourceSize.xy);

    // Smoothing
    vec4 AyB45 = Ai * fp.y + B45 * fp.x;
    vec4 ma45  = smoothstep(C45 - M45, C45 + M45, AyB45);

    // Edge weights
    vec4 e45   = lum_wd(p12, p8, p16, p18, p22, p14, p17, p13);
    vec4 econt = lum_wd(p17, p11, p23, p13, p7, p19, p12, p18);

    // Final blend rules
    vec4 edr45 = vec4(lessThan(e45, econt));
    vec4 px    = step(abs(p12 - p17), abs(p12 - p13));
    vec4 mac   = ma45 * edr45;

    // Final result
    vec3 res1 = mix(P12, mix(P13, P17, px.x), mac.x);
    res1 = mix(res1, mix(P7,  P13, px.y), mac.y);
    res1 = mix(res1, mix(P11, P7,  px.z), mac.z);
    res1 = mix(res1, mix(P17, P11, px.w), mac.w);

    FragColor = vec4(res1, 1.0);
}
