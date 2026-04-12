#version 130

// --- VERTEX SHADER ---
#if defined(VERTEX)
in vec4 VertexCoord;
in vec2 TexCoord;
out vec2 TEX0;
out vec2 vTexCoord;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    TEX0 = TexCoord; 
    vTexCoord = TexCoord; 
}

// --- FRAGMENT SHADER ---
#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

in vec2 TEX0;
in vec2 vTexCoord;
out vec4 FragColor;

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

// --- ميزة Vignette من كود 63 ---
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

uniform float GAME_ZOOM, BRIGHT_BOOST, BARREL_DISTORTION, v_softness, v_amount, select_l1, blend_mode, overlay_str, zoom_overlay, png_width, png_height;
uniform float select_l2, blend_mode2, overlay_str2, zoom_overlay2, png_width2, png_height2;

vec3 blend_logic(vec3 a, vec3 b, float mode) {
    vec3 b_safe = b * 0.5; 
    
    vec3 m = a * b; // Multiply (0.0)
    vec3 o = mix(2.0 * a * b, 1.0 - 2.0 * (1.0 - a) * (1.0 - b), step(0.5, a.r)); // Overlay (1.0)
    vec3 s = (1.0 - 2.0 * b_safe) * a * a + 2.0 * b_safe * a; // Soft Light (2.0)
    vec3 v = abs(a - b_safe); // Vivid (3.0)
    vec3 sub = clamp(a - b, 0.0, 1.0); // Subtract (4.0)
    vec3 dodge = a / (1.00001 - b_safe); // Safe Dodge (5.0)
    vec3 dark = min(a, b); // Darken (6.0)
    
    vec3 res = mix(m, o, step(0.5, mode));
    res = mix(res, s, step(1.5, mode));
    res = mix(res, v, step(2.5, mode));
    res = mix(res, sub, step(3.5, mode));
    res = mix(res, dodge, step(4.5, mode));
    res = mix(res, dark, step(5.5, mode)); 
    return res;
}

void main() {
    // --- إحداثيات فرش التكتشر من كود 63 بالملي ---
    vec2 scale = TextureSize / InputSize;
    vec2 mP = vTexCoord * scale; 
    
    vec2 texcoord = (TEX0 * scale) - vec2(0.5);
    texcoord /= GAME_ZOOM; 

    float rsq = dot(texcoord, texcoord);
    vec2 d_uv = texcoord + (texcoord * (BARREL_DISTORTION * rsq)); // d_uv للـ Vignette
    
    float rescale = 1.0 - (0.12 * BARREL_DISTORTION);
    vec2 final_uv = d_uv * rescale;

    if (abs(final_uv.x) > 0.5 || abs(final_uv.y) > 0.5) {
        FragColor = vec4(0.0, 0.0, 0.0, 1.0);
    } else {
        vec2 fetch_uv = (final_uv + vec2(0.5)) / scale;
        vec3 game = texture(Texture, fetch_uv).rgb;
        game *= BRIGHT_BOOST; 

        // --- ميزة Vignette من كود 63 ---
        float fade_x = smoothstep(0.5, 0.5 - v_softness, abs(d_uv.x));
        float fade_y = smoothstep(0.5, 0.5 - v_softness, abs(d_uv.y));
        game *= mix(1.0, fade_x * fade_y, v_amount);

        // --- معالجة الطبقة الأولى (L1) بمعادلة 63 الدقيقة ---
        vec2 uv1 = vec2(fract(mP.x * OutputSize.x / (png_width * zoom_overlay)), 
                        fract(mP.y * OutputSize.y / (png_height * zoom_overlay)));
        vec3 p1;
        if (select_l1 < 0.5) p1 = texture(L1_RGB, uv1).rgb;
        else if (select_l1 < 1.5) p1 = texture(L1_SLOT, uv1).rgb;
        else if (select_l1 < 2.5) p1 = texture(L1_GBA, uv1).rgb;
        else if (select_l1 < 3.5) p1 = texture(L1_SHADOWS, uv1).rgb;
        else p1 = texture(L1_SCANLINES, uv1).rgb;

        // --- معالجة الطبقة الثانية (L2) بمعادلة 63 الدقيقة ---
        vec2 uv2 = vec2(fract(mP.x * OutputSize.x / (png_width2 * zoom_overlay2)), 
                        fract(mP.y * OutputSize.y / (png_height2 * zoom_overlay2)));
        vec3 p2;
        if (select_l2 < 0.5) p2 = texture(L2_RGB, uv2).rgb;
        else if (select_l2 < 1.5) p2 = texture(L2_SLOT, uv2).rgb;
        else if (select_l2 < 2.5) p2 = texture(L2_GBA, uv2).rgb;
        else if (select_l2 < 3.5) p2 = texture(L2_SHADOWS, uv2).rgb;
        else p2 = texture(L2_SCANLINES, uv2).rgb;

        vec3 mix1 = mix(game, blend_logic(game, p1, blend_mode), overlay_str);
        vec3 mix2 = mix(mix1, blend_logic(mix1, p2, blend_mode2), overlay_str2);

        FragColor = vec4(clamp(mix2, 0.0, 1.0), 1.0);
    }
}
#endif