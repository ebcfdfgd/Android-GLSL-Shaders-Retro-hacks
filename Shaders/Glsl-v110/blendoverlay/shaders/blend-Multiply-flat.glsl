#version 110

/* LIGHT-ULTIMATE (Toshiba V3XEL Turbo - 5050 DNA)
    - UPDATED: Curve 0 and Vignette removed.
    - PERFORMANCE: Branchless optimized math.
    - LOGIC: High-speed Multiply Blend (L1).
*/

// --- PARAMETERS ---
// L1: Fixed to Multiply
#pragma parameter OverlayMix "L1 Intensity (Multiply)" 1.0 0.0 1.5 0.05
#pragma parameter LUTWidth "L1 Width" 6.0 1.0 1600.0 1.0
#pragma parameter LUTHeight "L1 Height" 4.0 1.0 1080.0 1.0
#pragma parameter BRIGHT_BOOST "Final Brightness Boost" 1.0 1.0 2.0 0.05

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
uniform sampler2D Texture, overlay;

#ifdef PARAMETER_UNIFORM
uniform float OverlayMix, LUTWidth, LUTHeight, BRIGHT_BOOST;
#endif

void main() {
    // 1. إعدادات الإحداثيات الأصلية
    vec2 fetch_uv =
        TEX0.xy;

    // 2. سحب الصورة (Direct Sampling)
    vec3 gm =
        texture2D(
            Texture,
            fetch_uv
        ).rgb;

    // إحداثيات ثابتة للطبقات
    vec2 mP =
        TEX0.xy *
        screen_scale;
    
    // 4. الطبقة الأولى (L1): Multiply Mode
    if (OverlayMix > 0.01) {
        vec2 maskUV1 =
            vec2(
                fract(
                    mP.x *
                    OutputSize.x /
                    LUTWidth
                ),
                fract(
                    mP.y *
                    OutputSize.y /
                    LUTHeight
                )
            );

        vec3 m1 =
            texture2D(
                overlay,
                maskUV1
            ).rgb;
        
        // --- Multiply Math ---
        vec3 ovl1 =
            gm *
            m1; 
        
        gm =
            mix(
                gm,
                clamp(
                    ovl1,
                    0.0,
                    1.0
                ),
                OverlayMix
            );
    }

    // 6. النتيجة النهائية
    gl_FragColor =
        vec4(
            clamp(
                gm *
                BRIGHT_BOOST,
                0.0,
                1.0
            ),
            1.0
        );
}
#endif