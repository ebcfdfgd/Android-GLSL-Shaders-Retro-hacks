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
#pragma parameter DITHER_STR "Dither Removal" 0.6 0.0 1.0 0.05
#pragma parameter BLOOM_STR "Bloom" 0.3 0.0 1.0 0.05
#pragma parameter OUTLINE_STR "Outline" 0.25 0.0 1.0 0.05
#pragma parameter RIM_LIGHT "Rim Light" 1.2 0.0 2.0 0.05
#pragma parameter MICRO_AO "Micro AO" 0.3 0.0 1.0 0.05
#pragma parameter SPECULAR "Specular" 0.4 0.0 1.5 0.05
#pragma parameter VIBRANCE "Vibrance" 0.3 -1.0 1.0 0.05
#pragma parameter WARMTH "Warmth" 0.0 -0.5 0.5 0.05
#pragma parameter FILM_LOG "Film Log" 0.2 0.0 1.0 0.05
#pragma parameter CROSS_PROCESS "Cross Process" 0.2 0.0 1.0 0.05
#pragma parameter CURVATURE_STR "Curvature" 0.2 0.0 1.0 0.05
#pragma parameter LUMA_ADAPT "Luma Adaptation" 0.2 0.0 1.0 0.05

uniform float DITHER_STR, BLOOM_STR, OUTLINE_STR, RIM_LIGHT, MICRO_AO, SPECULAR, VIBRANCE, WARMTH, FILM_LOG, CROSS_PROCESS, CURVATURE_STR,LUMA_ADAPT;

const vec3 lumaW = vec3(0.299, 0.587, 0.114);

void main()
{
    vec2 px = 1.0 / TextureSize;

    /* ---------------- CORE FETCH (5-TAP SYMMETRIC) ---------------- */
    vec3 c = texture2D(Texture, uv).rgb;
    vec3 r = texture2D(Texture, uv + vec2(px.x, 0.0)).rgb;
    vec3 l = texture2D(Texture, uv - vec2(px.x, 0.0)).rgb;
    vec3 t = texture2D(Texture, uv + vec2(0.0, px.y)).rgb;
    vec3 b = texture2D(Texture, uv - vec2(0.0, px.y)).rgb;

    /* ---------------- DITHER (5-TAP AVERAGE) ---------------- */
    // نحسب متوسط الجيران الخمسة لتنعيم الصورة وإزالة الديذرينج بدقة
    vec3 avg = (c + r + l + t + b) * 0.2;
    vec3 res = mix(c, avg, DITHER_STR);

    /* ---------------- BLOOM (5-TAP BRIGHTNESS) ---------------- */
    // الـ Bloom الآن يكتشف الإضاءة من كل الجهات
    float b_avg = max(0.0, dot(avg, lumaW) - 0.55);
    res += (avg * b_avg) * BLOOM_STR;

    /* ---------------- OUTLINE (4-WAY SYMMETRIC) ---------------- */
    // مقارنة المركز بكل الجيران الأربعة لضمان حواف ثابتة
    float y_m = dot(res, lumaW);
    float edge = dot(abs(c - r) + abs(c - l) + abs(c - t) + abs(c - b), vec3(0.333)) * 0.25;
    res *= 1.0 - (edge * OUTLINE_STR * (1.0 - y_m));

    /* ---------------- MICRO AO (HORIZONTAL & VERTICAL) ---------------- */
    // حساب الفروقات أفقياً ورأسياً للعمق
    float diff_h = abs(dot(r, lumaW) - dot(l, lumaW));
    float diff_v = abs(dot(t, lumaW) - dot(b, lumaW));
    float dist = (diff_h + diff_v) * 0.5;
    res -= dist * MICRO_AO * (1.0 - y_m) * (1.0 + dist * 0.5);

    /* ---------------- RIM LIGHT ---------------- */
    // الـ Rim الآن يستخدم الـ edge المتطور المعتمد على 4 جهات
    res += edge * (1.0 - y_m) * (1.0 + dist * 0.5) * RIM_LIGHT;

    /* ---------------- SPECULAR ---------------- */
    float spec = y_m * y_m * SPECULAR;
    res += vec3(spec * (1.0 - dist * 0.5));

    /* ---------------- LUMA ADAPT ---------------- */
    res += vec3(LUMA_ADAPT * 0.25);

    /* ----------------  CURVATURE ---------------- */
    
    res += ((edge + dist) * 0.5) * CURVATURE_STR * 0.1;

    /* ---------------- POST-PROCESS ---------------- */
    res = mix(res, res * res * (3.0 - 2.0 * res), FILM_LOG);
    res = mix(res, vec3(res.r * 1.05 + 0.02, res.g * 0.95 + res.r * 0.03, res.b * 0.90 + res.g * 0.08), CROSS_PROCESS);
    
    float gray = dot(res, lumaW);
    res = mix(vec3(gray), res, 1.0 + VIBRANCE);
    
    res.r += WARMTH * (0.5 + y_m * 0.5) * 0.05;
    res.b -= WARMTH * (0.5 + y_m * 0.5) * 0.05;

    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif