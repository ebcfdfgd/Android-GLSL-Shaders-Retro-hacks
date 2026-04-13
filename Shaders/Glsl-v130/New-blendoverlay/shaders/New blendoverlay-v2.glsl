#version 130

/* ULTIMATE-TURBO-300 (Performance Build)
   - Toshiba V3XEL Cylindrical Curve (Straight Edges).
   - Smart Branching: GPU skips unused overlays and texture fetches.
   - Fixed Early Exit: Immediate return for out-of-bounds pixels.
*/

#pragma parameter BARREL_DISTORTION "Toshiba Curve Strength" 0.12 0.0 0.5 0.01
#pragma parameter ZOOM "Zoom Amount" 1.0 0.5 2.0 0.01
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 5.0 0.05
#pragma parameter v_amount "Soft Vignette Intensity" 0.25 0.0 2.5 0.01

// L1 Modes: 0:Over, 1:Mult, 2:Dodge, 3:Dark, 4:Soft, 5:Hard, 6:Smart
#pragma parameter blend_mode "L1 Mode: 0:Over,1:Mult,2:Dodg,3:Dark,4:Soft,5:Hard,6:Smart" 0.0 0.0 6.0 1.0
#pragma parameter OverlayMix "L1 Intensity" 1.0 0.0 1.0 0.05
#pragma parameter LUTWidth "L1 Width" 6.0 1.0 1024.0 1.0
#pragma parameter LUTHeight "L1 Height" 4.0 1.0 1024.0 1.0

// L2 Modes: 0:Over, 1:Mult, 2:Dodge, 3:Dark, 4:Soft, 5:Hard, 6:Smart
#pragma parameter blend_mode2 "L2 Mode: 0:Over,1:Mult,2:Dodg,3:Dark,4:Soft,5:Hard,6:Smart" 0.0 0.0 6.0 1.0
#pragma parameter OverlayMix2 "L2 Intensity" 0.0 0.0 1.0 0.05
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
uniform float BARREL_DISTORTION, ZOOM, BRIGHT_BOOST, v_amount, blend_mode, OverlayMix, LUTWidth, LUTHeight, blend_mode2, OverlayMix2, LUTWidth2, LUTHeight2;
#endif

float b1(float a, float b) { return a<0.5?(2.0*a*b):(1.0-2.0*(1.0-a)*(1.0-b)); }
vec3 logic(vec3 a, vec3 b, float m) {
    if (m < 0.5) return vec3(b1(a.r, b.r), b1(a.g, b.g), b1(a.b, b.b));
    if (m < 1.5) return a * b;
    if (m < 2.5) return a / (1.00001 - b);
    if (m < 3.5) return min(a, b);
    if (m < 4.5) return (1.0 - 2.0 * b) * a * a + 2.0 * b * a;
    if (m < 5.5) return mix(2.0 * a * b, 1.0 - 2.0 * (1.0 - a) * (1.0 - b), step(0.5, a));
    return a * (b + (a * (1.0 - b) * 0.5));
}

void main() {
    vec2 sc = TextureSize / InputSize;
    vec2 uv = (TEX0.xy * sc) - 0.5;
    uv /= ZOOM;

    // 1. كيرف توشيبا الأسطواني (Cylindrical Curve) - أداء فائق
    float kx = BARREL_DISTORTION * 0.2; 
    float ky = BARREL_DISTORTION * 0.9; 
    vec2 d_uv;
    d_uv.x = uv.x * (1.0 + (uv.y * uv.y) * kx);
    d_uv.y = uv.y * (1.0 + (uv.x * uv.x) * ky);
    d_uv *= (1.0 - 0.15 * BARREL_DISTORTION);

    // 2. القطع المبكر (Early Exit) لتوفير جهد كارت الشاشة
    if (abs(d_uv.x) > 0.5 || abs(d_uv.y) > 0.5) {
        FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    vec2 gC = (d_uv + 0.5) / sc;
    vec3 gm = COMPAT_TEXTURE(Texture, gC).xyz * BRIGHT_BOOST;

    // 3. الفنيت ناعم (Soft Vignette) رياضي سريع
    float vignette = d_uv.x * d_uv.x + d_uv.y * d_uv.y;
    gm *= clamp(1.0 - (vignette * v_amount), 0.0, 1.0);

    vec2 mP = TEX0.xy * TextureSize / InputSize;
    vec3 res = gm;

    // 4. تجاهل الطبقة الأولى إذا كانت مغلقة (Smart Branching L1)
    if (OverlayMix > 0.0) {
        vec2 maskUV1 = vec2(fract(mP.x * OutputSize.x / LUTWidth), fract(mP.y * OutputSize.y / LUTHeight));
        vec3 m1 = COMPAT_TEXTURE(overlay, maskUV1).xyz;
        res = mix(res, clamp(logic(res, m1, blend_mode), 0.0, 1.0), OverlayMix);
    }

    // 5. تجاهل الطبقة الثانية إذا كانت مغلقة (Smart Branching L2)
    if (OverlayMix2 > 0.0) {
        vec2 maskUV2 = vec2(fract(mP.x * OutputSize.x / LUTWidth2), fract(mP.y * OutputSize.y / LUTHeight2));
        vec3 m2 = COMPAT_TEXTURE(overlay2, maskUV2).xyz;
        res = mix(res, clamp(logic(res, m2, blend_mode2), 0.0, 1.0), OverlayMix2);
    }

    FragColor = vec4(res, 1.0);
}
#endif