#version 110

/*
    SABR-Lite (GLSL / libretro)
    A lightweight edge-directed pixel-art smoother (EPX / Scale2x style
    rule with an anti-aliased 45 degree cut, as in SABR).
    Only 5 texture fetches per pixel instead of 21.
*/

#pragma parameter EDGE_THRESHOLD "Edge Threshold" 0.15 0.02 0.50 0.01
#pragma parameter SMOOTHNESS "Diagonal Smoothness" 0.20 0.02 0.50 0.01

#if defined(VERTEX)

attribute vec4 VertexCoord;
attribute vec4 TexCoord;
uniform mat4 MVPMatrix;
uniform vec2 TextureSize;

varying vec2 tc;
varying vec4 we;   // W.xy , E.zw
varying vec4 ns;   // N.xy , S.zw

void main()
{
    gl_Position = MVPMatrix * VertexCoord;
    tc = TexCoord.xy;

    float x = 1.0 / TextureSize.x;
    float y = 1.0 / TextureSize.y;

    we = vec4(tc.x - x, tc.y, tc.x + x, tc.y);
    ns = vec4(tc.x, tc.y - y, tc.x, tc.y + y);
}

#elif defined(FRAGMENT)

#ifdef GL_ES
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
#endif

uniform sampler2D Texture;
uniform vec2 TextureSize;

varying vec2 tc;
varying vec4 we;
varying vec4 ns;

#ifdef PARAMETER_UNIFORM
uniform float EDGE_THRESHOLD;
uniform float SMOOTHNESS;
#else
#define EDGE_THRESHOLD 0.15
#define SMOOTHNESS 0.20
#endif

const vec3 lum = vec3(0.21, 0.72, 0.07);

void main()
{
    // 5 taps only
    vec3 C = texture2D(Texture, tc).rgb;
    vec3 W = texture2D(Texture, we.xy).rgb;
    vec3 E = texture2D(Texture, we.zw).rgb;
    vec3 N = texture2D(Texture, ns.xy).rgb;
    vec3 S = texture2D(Texture, ns.zw).rgb;

    // Position inside the source pixel
    vec2 fp = fract(tc * TextureSize);

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
    float thr  = EDGE_THRESHOLD;
    float cond = step(abs(lH - lV), thr)
               * step(thr, abs(lH - lHo))
               * step(thr, abs(lV - lVo));

    // Anti-aliased 45 degree cut across the corner of the pixel
    float t = dot(abs(fp - 0.5), vec2(1.0));
    float w = smoothstep(0.5 - SMOOTHNESS, 0.5 + SMOOTHNESS, t) * cond;

    gl_FragColor = vec4(mix(C, 0.5 * (H + V), w), 1.0);
}
#endif
