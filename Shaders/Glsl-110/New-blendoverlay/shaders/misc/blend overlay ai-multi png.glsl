#version 110

/*
    ULTIMATE-HYBRID-AIO (Version 110 - Backported)
    - 1. NTSC/CRT Curvature (Barrel Distortion).
    - 2. Dynamic Vignette (Smoothstep Edge Fade).
    - 3. Dual Layer Multi-Texture System (RGB, Slot, GBA, Shadows, Scanlines).
    - 4. Advanced Blending Engine (7 Modes).
*/

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 TEX0;
varying vec2 vTexCoord;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    TEX0 = TexCoord; 
    vTexCoord = TexCoord; 
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 TEX0;
varying vec2 vTexCoord;

uniform sampler2D Texture;        

// --- طبقة الصور الأولى (L1) ---
uniform sampler2D L1_RGB;      // 0
uniform sampler2D L1_SLOT;     // 1
uniform sampler2D L1_GBA;      // 2
uniform sampler2D L1_SHADOWS;  // 3
uniform sampler2D L1_SCANLINES;// 4

// --- طبقة الصور الثانية (L2) ---
uniform sampler2D L2_RGB;      // 0
uniform sampler2D L2_SLOT;     // 1
uniform sampler2D L2_GBA;      // 2
uniform sampler2D L2_SHADOWS;  // 3
uniform sampler2D L2_SCANLINES;// 4

uniform vec2 TextureSize;
uniform vec2 InputSize;
uniform vec2 OutputSize;

// --- إعدادات الصورة العامة ---
#pragma parameter GAME_ZOOM "1. [ Screen Zoom ]" 1.0 0.5 2.0 0.001
#pragma parameter BRIGHT_BOOST "2. [ Brightness Boost ]" 1.2 1.0 2.0 0.05
#pragma parameter BARREL_DISTORTION "3. [ CRT Curvature ]" 0.12 0.0 0.5 0.01

// --- ميزة Vignette ---
#pragma parameter v_softness "Vignette Softness" 0.10 0.0 0.30 0.01
#pragma parameter v_amount "Vignette Strength" 0.5 0.0 1.0 0.05

// --- إعدادات الطبقة الأولى (L1) ---
#pragma parameter select_l1 "L1: Type (RGB, SLOT, GBA, SHAD, SCAN)" 0.0 0.0 4.0 1.0
#pragma parameter blend_mode "L1 Mode: Mult, Over, Soft, Vivid, SUB, DODGE, DARK" 0.0 0.0 6.0 1.0
#pragma parameter overlay_str "L1: Intensity" 0.35 0.0 1.0 0.05
#pragma parameter zoom_overlay "L1: PNG Scale" 1.0 0.1 10.0 0.1
#pragma parameter png_width "L1: PNG Width" 5.0 1.0 2048.0 1.0
#pragma parameter png_height "L1: PNG Height" 5.0 1.0 2048.0 1.0

// --- إعدادات الطبقة الثانية (L2) ---
#pragma parameter select_l2 "L2: Type (RGB, SLOT, GBA, SHAD, SCAN)" 0.0 0.0 4.0 1.0
#pragma parameter blend_mode2 "L2 Mode: Mult, Over, Soft, Vivid, SUB, DODGE, DARK" 0.0 0.0 6.0 1.0
#pragma parameter overlay_str2 "L2: Intensity" 0.20 0.0 1.0 0.05
#pragma parameter zoom_overlay2 "L2: PNG Scale" 1.0 0.1 10.0 0.1
#pragma parameter png_width2 "L2: PNG Width" 5.0 1.0 2048.0 1.0
#pragma parameter png_height2 "L2: PNG Height" 5.0 1.0 2048.0 1.0

#ifdef PARAMETER_UNIFORM
uniform float GAME_ZOOM, BRIGHT_BOOST, BARREL_DISTORTION, v_softness, v_amount, select_l1, blend_mode, overlay_str, zoom_overlay, png_width, png_height;
uniform float select_l2, blend_mode2, overlay_str2, zoom_overlay2, png_width2, png_height2;
#endif

// دالة منطق الدمج المتقدمة
vec3 blend_logic(vec3 a, vec3 b, float mode) {
    vec3 b_safe = b * 0.5; 
    
    if (mode < 0.5) return a * b; // Multiply
    if (mode < 1.5) return mix(2.0 * a * b, 1.0 - 2.0 * (1.0 - a) * (1.0 - b), step(0.5, a.r)); // Overlay
    if (mode < 2.5) return (1.0 - 2.0 * b_safe) * a * a + 2.0 * b_safe * a; // Soft Light
    if (mode < 3.5) return abs(a - b_safe); // Vivid
    if (mode < 4.5) return clamp(a - b, 0.0, 1.0); // Subtract
    if (mode < 5.5) return a / (1.00001 - b_safe); // Safe Dodge
    return min(a, b); // Darken
}

void main() {
    vec2 scale = TextureSize / InputSize;
    vec2 mP = vTexCoord * scale; 
    
    // إعداد إحداثيات التقوس
    vec2 texcoord = (TEX0 * scale) - vec2(0.5);
    texcoord /= GAME_ZOOM; 

    float rsq = dot(texcoord, texcoord);
    vec2 d_uv = texcoord + (texcoord * (BARREL_DISTORTION * rsq)); 
    
    float rescale = 1.0 - (0.12 * BARREL_DISTORTION);
    vec2 final_uv = d_uv * rescale;

    // الخروج المبكر إذا كان البكسل خارج النطاق
    if (abs(final_uv.x) > 0.5 || abs(final_uv.y) > 0.5) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
    } else {
        vec2 fetch_uv = (final_uv + vec2(0.5)) / scale;
        vec3 game = texture2D(Texture, fetch_uv).rgb;
        game *= BRIGHT_BOOST; 

        // تطبيق الـ Vignette (التعتيم الجانبي)
        float fade_x = smoothstep(0.5, 0.5 - v_softness, abs(d_uv.x));
        float fade_y = smoothstep(0.5, 0.5 - v_softness, abs(d_uv.y));
        game *= mix(1.0, fade_x * fade_y, v_amount);

        // --- الطبقة الأولى (L1) ---
        vec2 uv1 = vec2(fract(mP.x * OutputSize.x / (png_width * zoom_overlay)), 
                        fract(mP.y * OutputSize.y / (png_height * zoom_overlay)));
        vec3 p1;
        if (select_l1 < 0.5) p1 = texture2D(L1_RGB, uv1).rgb;
        else if (select_l1 < 1.5) p1 = texture2D(L1_SLOT, uv1).rgb;
        else if (select_l1 < 2.5) p1 = texture2D(L1_GBA, uv1).rgb;
        else if (select_l1 < 3.5) p1 = texture2D(L1_SHADOWS, uv1).rgb;
        else p1 = texture2D(L1_SCANLINES, uv1).rgb;

        // --- الطبقة الثانية (L2) ---
        vec2 uv2 = vec2(fract(mP.x * OutputSize.x / (png_width2 * zoom_overlay2)), 
                        fract(mP.y * OutputSize.y / (png_height2 * zoom_overlay2)));
        vec3 p2;
        if (select_l2 < 0.5) p2 = texture2D(L2_RGB, uv2).rgb;
        else if (select_l2 < 1.5) p2 = texture2D(L2_SLOT, uv2).rgb;
        else if (select_l2 < 2.5) p2 = texture2D(L2_GBA, uv2).rgb;
        else if (select_l2 < 3.5) p2 = texture2D(L2_SHADOWS, uv2).rgb;
        else p2 = texture2D(L2_SCANLINES, uv2).rgb;

        // دمج الطبقات بالترتيب
        vec3 mix1 = mix(game, blend_logic(game, p1, blend_mode), overlay_str);
        vec3 mix2 = mix(mix1, blend_logic(mix1, p2, blend_mode2), overlay_str2);

        gl_FragColor = vec4(clamp(mix2, 0.0, 1.0), 1.0);
    }
}
#endif