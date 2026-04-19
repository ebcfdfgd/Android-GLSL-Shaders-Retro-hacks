#version 110

/* LIGHT-ULTIMATE (Turbo Pure - 5050 DNA)
    - REMOVED: All distortion and vignette math (Maximum Performance).
    - FEATURE: Quilez Scaling (Anti-Moire) Integrated.
    - OPTIMIZATION: High-speed texture sampling.
    - FIXED: BRIGHT_BOOST applied at final stage.
*/

// --- PARAMETERS ---
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 5.0 0.05

// L1: Fixed to Overlay
#pragma parameter OverlayMix "L1 Intensity (Overlay)" 1.0 0.0 1.0 0.05
#pragma parameter LUTWidth "L1 Width" 6.0 1.0 1024.0 1.0
#pragma parameter LUTHeight "L1 Height" 4.0 1.0 1024.0 1.0

// L2: Fixed to Multiply
#pragma parameter OverlayMix2 "L2 Intensity (Multiply)" 0.0 0.0 1.0 0.05
#pragma parameter LUTWidth2 "L2 Width" 6.0 1.0 1024.0 1.0
#pragma parameter LUTHeight2 "L2 Height" 4.0 1.0 1024.0 1.0

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec4 TexCoord;
varying vec2 TEX0, inv_tex_size;
uniform mat4 MVPMatrix;
uniform vec2 TextureSize;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    TEX0 = TexCoord.xy;
    inv_tex_size = 1.0 / TextureSize;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 TEX0, inv_tex_size;
uniform vec2 OutputSize, TextureSize;
uniform sampler2D Texture, overlay, overlay2;

#ifdef PARAMETER_UNIFORM
uniform float BRIGHT_BOOST, OverlayMix, LUTWidth, LUTHeight, OverlayMix2, LUTWidth2, LUTHeight2;
#endif

float overlay_f(float a, float b) {
    return (a < 0.5) ? (2.0 * a * b) : (1.0 - 2.0 * (1.0 - a) * (1.0 - b));
}

void main() {
    // 1. محرك الشرب السريع (Quilez Scaling - DNA 5050)
    vec2 p = TEX0 * TextureSize;
    vec2 i = floor(p);
    vec2 f = p - i;
    f = f * f * (3.0 - 2.0 * f); 
    
    // سحب الصورة الأساسية الخام
    vec3 gm = texture2D(Texture, (i + f + 0.5) * inv_tex_size).rgb;

    // 2. إحداثيات الماسكات (Screen Space)
    vec2 maskPos = TEX0 * OutputSize;
    
    // الطبقة الأولى (L1): Overlay
    if (OverlayMix > 0.01) {
        vec2 maskUV1 = vec2(fract(maskPos.x / LUTWidth), 
                            fract(maskPos.y / LUTHeight));
        vec3 m1 = texture2D(overlay, maskUV1).rgb;
        vec3 ovl1 = vec3(overlay_f(gm.r, m1.r), overlay_f(gm.g, m1.g), overlay_f(gm.b, m1.b));
        gm = mix(gm, clamp(ovl1, 0.0, 1.0), OverlayMix);
    }

    // الطبقة الثانية (L2): Multiply
    if (OverlayMix2 > 0.01) {
        vec2 maskUV2 = vec2(fract(maskPos.x / LUTWidth2), 
                            fract(maskPos.y / LUTHeight2));
        vec3 m2 = texture2D(overlay2, maskUV2).rgb;
        gm = mix(gm, gm * m2, OverlayMix2);
    }

    // 3. تطبيق الـ Boost النهائي
    gl_FragColor = vec4(clamp(gm * BRIGHT_BOOST, 0.0, 1.0), 1.0);
}
#endif