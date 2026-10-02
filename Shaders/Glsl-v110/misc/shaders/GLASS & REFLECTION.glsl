#version 110

/* 777-GLASS-MODULAR-EDITION
   - تم تحويل كل ميزة لكبسولة مستقلة ببادئة G_
   - نظام إحداثيات منفصل للانحناء.
   - نظام دمج طبقات (Screen + Specular + Fresnel).
*/

#pragma parameter GLASS_STR "Glass Reflection Strength" 0.15 0.0 1.0 0.05
#pragma parameter BORDER_GLOSS "Edge Gloss Intensity" 0.20 0.0 1.0 0.05
#pragma parameter CURVE_VAL "Glass Curvature" 0.15 0.0 0.5 0.01
#pragma parameter TINT_STR "Glass Tint Intensity" 0.10 0.0 0.5 0.02

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 vTexCoord;
uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;

#ifdef PARAMETER_UNIFORM
uniform float GLASS_STR, BORDER_GLOSS, CURVE_VAL, TINT_STR;
#endif

void main() {
    // --- [1] كبسولة هندسة الزجاج وانحناء الإحداثيات ---
    vec2 G_sc = TextureSize / InputSize;
    vec2 G_p  = (vTexCoord * G_sc) - 0.5;
    float G_r2 = dot(G_p, G_p);
    
    // الإحداثيات المنحنية (المخرج النهائي للهندسة)
    vec2 G_curved = G_p * (1.0 + G_r2 * CURVE_VAL);
    vec2 G_final_uv = (G_curved + 0.5) / G_sc;
    // ------------------------------------------------

    // --- [2] سحب عينة الصورة (بناءً على إحداثيات الزجاج) ---
    vec3 G_screen = texture2D(Texture, G_final_uv).rgb;

    // --- [3] كبسولة تظليل عمق الزجاج (Glass Tint) ---
    float G_vign = smoothstep(0.7, 0.2, length(G_curved));
    G_screen *= mix(1.0 - TINT_STR, 1.0, G_vign);
    // ------------------------------------------------

    // --- [4] كبسولة لمعة الأطراف (Fresnel Reflection) ---
    float G_fresnel = pow(G_r2 * 2.1, 2.0) * BORDER_GLOSS;
    // ------------------------------------------------

    // --- [5] كبسولة الإضاءة العلوية (Specular Gloss) ---
    // بقعة ضوء في الركن العلوي الأيسر
    float G_spec = smoothstep(0.42, 0.0, length(G_curved - vec2(-0.35, 0.35)));
    G_spec *= 0.18 * GLASS_STR;
    
    // وهج عام لسطح الزجاج
    float G_ambient = (1.0 - length(G_curved)) * 0.06 * GLASS_STR;
    // ------------------------------------------------

    // --- [6] الدمج النهائي للطبقات ---
    vec3 G_res = G_screen + G_fresnel + G_spec + G_ambient;

    // --- [7] كبسولة قناع حدود الزجاج (Edge Mask) ---
    if (abs(G_curved.x) > 0.5 || abs(G_curved.y) > 0.5) {
        G_res = vec3(0.0);
    }
    // ------------------------------------------------

    gl_FragColor = vec4(G_res, 1.0);
}
#endif