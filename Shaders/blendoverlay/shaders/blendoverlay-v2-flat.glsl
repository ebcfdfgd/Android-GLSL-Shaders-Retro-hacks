/* ULTIMATE-TURBO-300 (Performance Build - Raw Mode - No Zoom)
   - REMOVED: Zoom logic for fixed standard scaling.
   - OPTIMIZATION: Direct texture sampling using original TEX0.
   - FIXED: Bright Boost applied at final stage.
*/

// --- PARAMETERS ---
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 5.0 0.05

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
varying vec2 TEX0, screen_scale;
uniform mat4 MVPMatrix;
uniform vec2 TextureSize, InputSize;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    TEX0 = TexCoord.xy;
    screen_scale = TextureSize / InputSize;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 TEX0, screen_scale;
uniform vec2 OutputSize, TextureSize, InputSize;
uniform sampler2D Texture, overlay, overlay2;

#ifdef PARAMETER_UNIFORM
uniform float BRIGHT_BOOST, blend_mode, OverlayMix, LUTWidth, LUTHeight, blend_mode2, OverlayMix2, LUTWidth2, LUTHeight2;
#endif

float b1(float a, float b) { 
    return (a < 0.5) ? (2.0 * a * b) : (1.0 - 2.0 * (1.0 - a) * (1.0 - b)); 
}

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
    // 1. DIRECT SAMPLING (أخذ الصورة الأصلية مباشرة بدون زوم)
    vec3 gm = texture2D(Texture, TEX0).xyz;

    vec2 mP = TEX0 * screen_scale;
    vec3 res = gm;

    // 2. الطبقة الأولى
    if (OverlayMix > 0.01) {
        vec2 maskUV1 = vec2(fract(mP.x * OutputSize.x / LUTWidth), fract(mP.y * OutputSize.y / LUTHeight));
        vec3 m1 = texture2D(overlay, maskUV1).xyz;
        res = mix(res, clamp(logic(res, m1, blend_mode), 0.0, 1.0), OverlayMix);
    }

    // 3. الطبقة الثانية
    if (OverlayMix2 > 0.01) {
        vec2 maskUV2 = vec2(fract(mP.x * OutputSize.x / LUTWidth2), fract(mP.y * OutputSize.y / LUTHeight2));
        vec3 m2 = texture2D(overlay2, maskUV2).xyz;
        res = mix(res, clamp(logic(res, m2, blend_mode2), 0.0, 1.0), OverlayMix2);
    }

    // 4. تطبيق الـ Boost النهائي والخرج
    gl_FragColor = vec4(clamp(res * BRIGHT_BOOST, 0.0, 1.0), 1.0);
}
#endif