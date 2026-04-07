#version 110

/* ULTIMATE-TURBO-300 (Performance Build - Backported to 110)
   - Feature: Toshiba V3XEL Cylindrical Curve (Optimized Speed).
   - Smart Branching: GPU skips unused overlays and texture fetches.
   - Performance: Early Exit logic to save GPU cycles on out-of-bounds pixels.
   - Compatibility: Optimized for Adreno 300/400 and Mali-T series.
*/

// --- PARAMETERS ---
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
attribute vec4 VertexCoord;
attribute vec4 TexCoord;
varying vec2 TEX0;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    TEX0 = TexCoord.xy;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 TEX0;
uniform vec2 OutputSize;
uniform vec2 TextureSize;
uniform vec2 InputSize;
uniform sampler2D Texture;
uniform sampler2D overlay;
uniform sampler2D overlay2;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, ZOOM, BRIGHT_BOOST, v_amount, blend_mode, OverlayMix, LUTWidth, LUTHeight, blend_mode2, OverlayMix2, LUTWidth2, LUTHeight2;
#endif

// دالة الـ Overlay الأساسية
float b1(float a, float b) { 
    return (a < 0.5) ? (2.0 * a * b) : (1.0 - 2.0 * (1.0 - a) * (1.0 - b)); 
}

// محرك منطق الدمج (Blending Engine)
vec3 logic(vec3 a, vec3 b, float m) {
    if (m < 0.5) return vec3(b1(a.r, b.r), b1(a.g, b.g), b1(a.b, b.b)); // Overlay
    if (m < 1.5) return a * b; // Multiply
    if (m < 2.5) return a / (1.00001 - b); // Color Dodge
    if (m < 3.5) return min(a, b); // Darken
    if (m < 4.5) return (1.0 - 2.0 * b) * a * a + 2.0 * b * a; // Soft Light
    if (m < 5.5) return mix(2.0 * a * b, 1.0 - 2.0 * (1.0 - a) * (1.0 - b), step(0.5, a)); // Hard Light
    return a * (b + (a * (1.0 - b) * 0.5)); // Smart Mix
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

    // 2. القطع المبكر (Early Exit) - أهم ميزة لتوفير جهد كارت الشاشة
    // إذا كان البكسل خارج الإطار، يتوقف الشيدر فوراً ولا يسحب أي أنسجة (Textures)
    if (abs(d_uv.x) > 0.5 || abs(d_uv.y) > 0.5) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // سحب الصورة الأساسية
    vec2 gC = (d_uv + 0.5) / sc;
    vec3 gm = texture2D(Texture, gC).xyz * BRIGHT_BOOST;

    // 3. الفنيت ناعم (Soft Vignette) - حساب Dot Product سريع
    float vignette_dist = dot(d_uv, d_uv);
    gm *= clamp(1.0 - (vignette_dist * v_amount), 0.0, 1.0);

    vec2 mP = TEX0.xy * sc;
    vec3 res = gm;

    // 4. نظام التفرع الذكي (Smart Branching) للطبقة الأولى
    if (OverlayMix > 0.01) {
        vec2 maskUV1 = vec2(fract(mP.x * OutputSize.x / LUTWidth), 
                            fract(mP.y * OutputSize.y / LUTHeight));
        vec3 m1 = texture2D(overlay, maskUV1).xyz;
        res = mix(res, clamp(logic(res, m1, blend_mode), 0.0, 1.0), OverlayMix);
    }

    // 5. نظام التفرع الذكي للطبقة الثانية
    if (OverlayMix2 > 0.01) {
        vec2 maskUV2 = vec2(fract(mP.x * OutputSize.x / LUTWidth2), 
                            fract(mP.y * OutputSize.y / LUTHeight2));
        vec3 m2 = texture2D(overlay2, maskUV2).xyz;
        res = mix(res, clamp(logic(res, m2, blend_mode2), 0.0, 1.0), OverlayMix2);
    }

    gl_FragColor = vec4(res, 1.0);
}
#endif