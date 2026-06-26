#version 110

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
precision highp float;
#endif

varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize;

/* =====================================================
   RETROARCH PARAMETERS
===================================================== */

//#pragma parameter DITHER_STR "Dither Removal" 1.0 0.0 1.0 0.05
//#pragma parameter BLOOM_STR "Bloom" 0.3 0.0 1.0 0.05
#pragma parameter OUTLINE_STR "Outline" 0.25 0.0 1.0 0.05
#pragma parameter RIM_LIGHT "Rim Light" 1.2 0.0 2.0 0.05
#pragma parameter MICRO_AO "Micro AO" 0.3 0.0 1.0 0.05
#pragma parameter SPECULAR "Specular" 0.4 0.0 1.5 0.05
#pragma parameter VIBRANCE "Vibrance" 0.3 -1.0 1.0 0.05
//#pragma parameter WARMTH "Warmth" 0.0 -0.5 0.5 0.05
#pragma parameter FILM_LOG "Film Log" 0.2 0.0 1.0 0.05
#pragma parameter CROSS_PROCESS "Cross Process" 0.2 0.0 1.0 0.05
#pragma parameter CURVATURE_STR "Curvature" 0.2 0.0 2.0 0.05
#pragma parameter LUMA_ADAPT "Luma Adaptation" 0.2 0.0 1.0 0.05

uniform float DITHER_STR;
uniform float BLOOM_STR;
uniform float OUTLINE_STR;
uniform float RIM_LIGHT;
uniform float MICRO_AO;
uniform float SPECULAR;
uniform float VIBRANCE;
uniform float WARMTH;
uniform float FILM_LOG;
uniform float CROSS_PROCESS;
uniform float CURVATURE_STR;
uniform float LUMA_ADAPT;

const vec3 lumaW = vec3(0.299, 0.587, 0.114);

/* ===================================================== */

void main()
{
    vec2 px = 1.0 / TextureSize;

    /* ---------------- CORE FETCH ---------------- */
    vec3 c = texture2D(Texture, uv).rgb;
    vec3 r = texture2D(Texture, uv + vec2(px.x, 0.0)).rgb;
    vec3 t = texture2D(Texture, uv + vec2(0.0, px.y)).rgb;
    

      // vec3 res = mix(c, (c + r) * 0.5, DITHER_STR);

     vec3 res = c;

    /* ---------------- BLOOM (2-TAP) ---------------- */
   // float bc = max(0.0, dot(c, lumaW) - 0.70);
   // float bt = max(0.0, dot(t, lumaW) - 0.70);
   // res += (c * bc + t * bt) * BLOOM_STR;

    /* ---------------- OUTLINE (AO AWARE) ---------------- */
    float y_m = dot(res, lumaW);
    float edge = dot(abs(c - r) + abs(c - t), vec3(0.333));

    res *= 1.0 - (edge * OUTLINE_STR * (1.0 - y_m));


    /* ---------------- MICRO AO ---------------- */
    float dist = abs(dot(r, lumaW) - dot(t, lumaW));
    res -= dist * MICRO_AO * (1.0 - y_m) * (1.0 + dist * 0.5);

    /* ---------------- RIM LIGHT ---------------- */
    res += edge * (1.0 - y_m) * (1.0 + dist * 0.5) * RIM_LIGHT;

    /* ---------------- SPECULAR ---------------- */
    float spec = y_m * y_m * SPECULAR;
    res += vec3(spec * (1.0 - dist * 0.5));

    /* ---------------- LUMA ADAPT ---------------- */
    res += vec3(LUMA_ADAPT * 0.25);

    /* ---------------- CURVATURE ---------------- */
    float curvature = (edge + dist) * 1.0;
    res += curvature * CURVATURE_STR * 0.1;

   //  res += ((edge + dist) * 0.7) * (1.0 + y_m) * CURVATURE_STR * 0.1;

    /* ---------------- FILM LOG ---------------- */
    res = mix(res, res * res * (3.0 - 2.0 * res), FILM_LOG);

    /* ---------------- CROSS PROCESS ---------------- */
    res = mix(res,
        vec3(res.r * 1.05 + 0.02,
             res.g * 0.95 + res.r * 0.03,
             res.b * 0.90 + res.g * 0.08),
        CROSS_PROCESS);

    /* ---------------- VIBRANCE ---------------- */
    float gray = dot(res, lumaW);
    res = mix(vec3(gray), res, 1.0 + VIBRANCE);

    /* ---------------- WARMTH ---------------- */
   // res.r += WARMTH * (0.5 + y_m * 0.5) * 0.05;
   // res.b -= WARMTH * (0.5 + y_m * 0.5) * 0.05;

    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif