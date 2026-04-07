#version 130

/*
    LIGHT-ULTIMATE (Toshiba V3XEL Turbo Edition)
    - Feature: Added Soft-Vignette (V3XEL Style).
    - Updated: Toshiba Cylindrical Curve (Faster, straight edges).
    - Kept: Overlay (L1) & Multiply (L2) Logic for Adreno 300.
*/

#pragma parameter BARREL_DISTORTION "Toshiba Curve Strength" 0.12 0.0 0.5 0.01
#pragma parameter ZOOM "Zoom Amount" 1.0 0.5 2.0 0.01
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 5.0 0.05
#pragma parameter v_amount "Soft Vignette Intensity" 0.25 0.0 2.5 0.01

// L1: Fixed to Overlay
#pragma parameter OverlayMix "L1 Intensity (Overlay)" 1.0 0.0 1.0 0.05
#pragma parameter LUTWidth "L1 Width" 6.0 1.0 1024.0 1.0
#pragma parameter LUTHeight "L1 Height" 4.0 1.0 1024.0 1.0

// L2: Fixed to Multiply
#pragma parameter OverlayMix2 "L2 Intensity (Multiply)" 0.0 0.0 1.0 0.05
#pragma parameter LUTWidth2 "L2 Width" 6.0 1.0 1024.0 1.0
#pragma parameter LUTHeight2 "L2 Height" 4.0 1.0 1024.0 1.0

#if defined(VERTEX)
#if __VERSION__ >= 130
#define COMPAT_VARYING out
#define COMPAT_ATTRIBUTE in
#else
#define COMPAT_VARYING varying
#define COMPAT_ATTRIBUTE attribute
#endif
COMPAT_ATTRIBUTE vec4 VertexCoord;
COMPAT_ATTRIBUTE vec4 TexCoord;
COMPAT_VARYING vec4 TEX0;
uniform mat4 MVPMatrix;
void main() {
    gl_Position = MVPMatrix * VertexCoord;
    TEX0.xy = TexCoord.xy;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif
#if __VERSION__ >= 130
#define COMPAT_VARYING in
#define COMPAT_TEXTURE texture
out vec4 FragColor;
#else
#define COMPAT_VARYING varying
#define FragColor gl_FragColor
#define COMPAT_TEXTURE texture2D
#endif
uniform vec2 OutputSize;
uniform vec2 TextureSize;
uniform vec2 InputSize;
uniform sampler2D Texture;
uniform sampler2D overlay;
uniform sampler2D overlay2;
COMPAT_VARYING vec4 TEX0;
#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, ZOOM, BRIGHT_BOOST, v_amount, OverlayMix, LUTWidth, LUTHeight, OverlayMix2, LUTWidth2, LUTHeight2;
#endif

float overlay_f(float a, float b) { return a < 0.5 ? (2.0 * a * b) : (1.0 - 2.0 * (1.0 - a) * (1.0 - b)); }

void main() {
    vec2 sc = TextureSize / InputSize;
    vec2 uv = (TEX0.xy * sc) - 0.5;
    uv /= ZOOM;
    
    // 1. كيرف توشيبا (Cylindrical Turbo)
    float kx = BARREL_DISTORTION * 0.2; 
    float ky = BARREL_DISTORTION * 0.9; 

    vec2 d_uv;
    d_uv.x = uv.x * (1.0 + (uv.y * uv.y) * kx);
    d_uv.y = uv.y * (1.0 + (uv.x * uv.x) * ky);
    
    d_uv *= (1.0 - 0.15 * BARREL_DISTORTION);
    
    // 2. فحص الحدود والقطع المباشر
    if (abs(d_uv.x) > 0.5 || abs(d_uv.y) > 0.5) {
        FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    vec2 gC = (d_uv + 0.5) / sc;
    vec3 gm = COMPAT_TEXTURE(Texture, gC).xyz * BRIGHT_BOOST;

    // 3. الفنتيج الناعم (Soft Vignette) 
    // نستخدم معادلة تعتمد على الأبعاد لضمان نعومة التدرج عند الأركان
    float vignette = d_uv.x * d_uv.x + d_uv.y * d_uv.y;
    vignette *= v_amount;
    gm *= clamp(1.0 - vignette * vignette, 0.0, 1.0);

    vec2 mP = TEX0.xy * TextureSize / InputSize;
    
    // الطبقة الأولى (L1): Overlay
    vec3 r1 = gm;
    if (OverlayMix > 0.0) {
        vec3 m1 = COMPAT_TEXTURE(overlay, vec2(fract(mP.x * OutputSize.x / LUTWidth), fract(mP.y * OutputSize.y / LUTHeight))).xyz;
        vec3 ovl1 = vec3(overlay_f(gm.r, m1.r), overlay_f(gm.g, m1.g), overlay_f(gm.b, m1.b));
        r1 = mix(gm, clamp(ovl1, 0.0, 1.0), OverlayMix);
    }

    // الطبقة الثانية (L2): Multiply
    vec3 r2 = r1;
    if (OverlayMix2 > 0.0) {
        vec3 m2 = COMPAT_TEXTURE(overlay2, vec2(fract(mP.x * OutputSize.x / LUTWidth2), fract(mP.y * OutputSize.y / LUTHeight2))).xyz;
        r2 = mix(r1, r1 * m2, OverlayMix2);
    }

    FragColor = vec4(r2, 1.0);
}
#endif