#version 110

/* ULTIMATE-HYBRID-AIO (Multi-Texture Build - Backported to 110)
    - 1. Dual-Layer Multi-Texture System (10 Selectable Slots).
    - 2. Barrel Distortion (CRT Curve) with Smooth-Edge Clipping.
    - 3. Smart-Branching Logic for Texture Fetching.
    - 4. Optimized for OpenGL 2.0 / Mobile GPUs.
*/

// --- PARAMETERS ---
#pragma parameter BARREL_DISTORTION "CRT Curve Amount" 0.12 0.0 0.5 0.01
#pragma parameter ZOOM "Zoom Amount" 1.0 0.5 2.0 0.01
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.3 1.0 5.0 0.05

// --- الطبقة الأولى (L1) ---
#pragma parameter L1_Selector "L1: 0:Sc1, 1:Sc2, 2:Fine, 3:Coar, 4:Grid" 0.0 0.0 4.0 1.0
#pragma parameter blend_mode "L1: 0:Over,1:Mult,2:Dodg,3:Dark,4:Soft,5:Hard,6:Smart" 6.0 0.0 6.0 1.0
#pragma parameter OverlayMix "L1 Intensity" 1.0 0.0 1.0 0.05
#pragma parameter LUTWidth "L1 Width" 6.0 1.0 1024.0 1.0
#pragma parameter LUTHeight "L1 Height" 4.0 1.0 1024.0 1.0

// --- الطبقة الثانية (L2) ---
#pragma parameter L2_Selector "L2: 0:Mk1, 1:Mk2, 2:Slot, 3:Aper, 4:Shad" 0.0 0.0 4.0 1.0
#pragma parameter blend_mode2 "L2: 0:Over,1:Mult,2:Dodg,3:Dark,4:Soft,5:Hard,6:Smart" 0.0 0.0 6.0 1.0
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
uniform sampler2D L1_0, L1_1, L1_2, L1_3, L1_4;
uniform sampler2D L2_0, L2_1, L2_2, L2_3, L2_4;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, ZOOM, BRIGHT_BOOST, L1_Selector, blend_mode, OverlayMix, LUTWidth, LUTHeight, L2_Selector, blend_mode2, OverlayMix2, LUTWidth2, LUTHeight2;
#endif

// دالة منطق الدمج (Blending Modes)
vec3 apply_logic(vec3 a, vec3 b, float m) {
    if (m < 0.5) return mix(2.0*a*b, 1.0-2.0*(1.0-a)*(1.0-b), step(0.5, a.r)); // Overlay
    if (m < 1.5) return a * b; // Multiply
    if (m < 2.5) return a / (1.00001 - b); // Color Dodge
    if (m < 3.5) return min(a, b); // Darken
    if (m < 4.5) return (1.0 - 2.0 * b) * a * a + 2.0 * b * a; // Soft Light
    if (m < 5.5) return mix(2.0*a*b, 1.0-2.0*(1.0-a)*(1.0-b), step(0.5, a.r)); // Hard Light
    return a * (b + (a * (1.0 - b) * 0.5)); // SmartMult
}

void main() {
    vec2 sc = TextureSize / InputSize;
    
    // إعداد إحداثيات التقوس (CRT Curve)
    vec2 uv = (TEX0.xy * sc) - 0.5;
    uv /= ZOOM;
    float rsq = dot(uv, uv);
    vec2 d_uv = uv + (uv * (BARREL_DISTORTION * rsq));
    
    // تصحيح الحواف لضمان تغطية كاملة
    d_uv *= (1.0 - (0.18 * BARREL_DISTORTION));
    
    // حدود الشاشة (Smooth Edges)
    float ed = smoothstep(0.5, 0.498, abs(d_uv.x)) * smoothstep(0.5, 0.498, abs(d_uv.y));
    
    if (ed <= 0.0) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    vec2 gC = (d_uv + 0.5) / sc;
    vec3 gm = texture2D(Texture, gC).xyz * BRIGHT_BOOST;

    vec2 mP = TEX0.xy * sc;
    
    // --- معالجة الطبقة الأولى (L1 Selector) ---
    vec3 m1;
    if (OverlayMix > 0.01) {
        vec2 c1 = vec2(fract(mP.x * OutputSize.x / LUTWidth), fract(mP.y * OutputSize.y / LUTHeight));
        if (L1_Selector < 0.5)      m1 = texture2D(L1_0, c1).xyz;
        else if (L1_Selector < 1.5) m1 = texture2D(L1_1, c1).xyz;
        else if (L1_Selector < 2.5) m1 = texture2D(L1_2, c1).xyz;
        else if (L1_Selector < 3.5) m1 = texture2D(L1_3, c1).xyz;
        else                        m1 = texture2D(L1_4, c1).xyz;
        gm = mix(gm, clamp(apply_logic(gm, m1, blend_mode), 0.0, 1.0), OverlayMix);
    }

    // --- معالجة الطبقة الثانية (L2 Selector) ---
    if (OverlayMix2 > 0.01) {
        vec3 m2;
        vec2 c2 = vec2(fract(mP.x * OutputSize.x / LUTWidth2), fract(mP.y * OutputSize.y / LUTHeight2));
        if (L2_Selector < 0.5)      m2 = texture2D(L2_0, c2).xyz;
        else if (L2_Selector < 1.5) m2 = texture2D(L2_1, c2).xyz;
        else if (L2_Selector < 2.5) m2 = texture2D(L2_2, c2).xyz;
        else if (L2_Selector < 3.5) m2 = texture2D(L2_3, c2).xyz;
        else                        m2 = texture2D(L2_4, c2).xyz;
        gm = mix(gm, clamp(apply_logic(gm, m2, blend_mode2), 0.0, 1.0), OverlayMix2);
    }

    gl_FragColor = vec4(gm, 1.0);
}
#endif