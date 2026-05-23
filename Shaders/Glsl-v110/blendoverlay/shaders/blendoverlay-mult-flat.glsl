#version 110

/* LIGHT-ULTIMATE (Zoom Integrated - Stable Brush)
    - ADDED: 6070 Zoom logic.
    - CORE: Zoom affects game image only.
    - BRUSH: Overlay mapping stays pixel-locked to output.
*/

// --- PARAMETERS ---
#pragma parameter GAME_ZOOM "Global Zoom Scale" 1.0 0.5 2.0 0.001
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 5.0 0.05

// L1: Multiply
#pragma parameter OverlayMix "L1 Intensity (Multiply)" 1.0 0.0 1.0 0.05
#pragma parameter LUTWidth "L1 Width" 6.0 1.0 1024.0 1.0
#pragma parameter LUTHeight "L1 Height" 4.0 1.0 1024.0 1.0

// L2: Multiply
#pragma parameter OverlayMix2 "L2 Intensity (Multiply)" 0.0 0.0 1.0 0.05
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
uniform vec2 OutputSize, TextureSize;
uniform sampler2D Texture, overlay, overlay2;

#ifdef PARAMETER_UNIFORM
uniform float GAME_ZOOM, BRIGHT_BOOST, OverlayMix, LUTWidth, LUTHeight, OverlayMix2, LUTWidth2, LUTHeight2;
#endif

void main() {
    // [1] تطبيق الزوم على صورة اللعبة فقط
    vec2 uv = (TEX0 - 0.5) / GAME_ZOOM + 0.5;

    // حماية الحواف (خلفية سوداء عند التصغير)
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    vec3 gm = texture2D(Texture, uv).rgb;

    // [2] منطق الطبقات (استخدام TEX0 الأصلي للحفاظ على ثبات "الفرش")
    vec2 mP = TEX0 * screen_scale;
    
    // L1 Multiply + AVG
    vec2 maskUV1 = vec2(fract(mP.x * OutputSize.x / LUTWidth), fract(mP.y * OutputSize.y / LUTHeight));
    vec3 m1 = texture2D(overlay, maskUV1).rgb;
    float avg1 = (m1.r + m1.g + m1.b) / 3.0;
    gm = mix(gm, gm * (m1 / max(avg1, 0.01)), OverlayMix);

    // L2 Multiply + AVG
    vec2 maskUV2 = vec2(fract(mP.x * OutputSize.x / LUTWidth2), fract(mP.y * OutputSize.y / LUTHeight2));
    vec3 m2 = texture2D(overlay2, maskUV2).rgb;
    float avg2 = (m2.r + m2.g + m2.b) / 3.0;
    gm = mix(gm, gm * (m2 / max(avg2, 0.01)), OverlayMix2);

    // [3] المخرجات النهائية
    gl_FragColor = vec4(clamp(gm * BRIGHT_BOOST, 0.0, 1.0), 1.0);
}
#endif