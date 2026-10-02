#version 110

/* LIGHT-ULTIMATE (Toshiba V3XEL Turbo - QUILEZ MODE) */

// --- PARAMETERS ---
#pragma parameter BARREL_DISTORTION "Curve 0 Strength" 0.15 0.0 1.0 0.02
#pragma parameter v_amount "Soft Vignette Intensity" 0.25 0.0 2.5 0.01
#pragma parameter OverlayMix "L1 Intensity (Multiply)" 1.0 0.0 1.5 0.05
#pragma parameter LUTWidth "L1 Width" 6.0 1.0 1024.0 1.0
#pragma parameter LUTHeight "L1 Height" 4.0 1.0 1024.0 1.0
#pragma parameter BRIGHT_BOOST "Final Brightness Boost" 1.0 1.0 2.0 0.05

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
uniform vec2 OutputSize, TextureSize, InputSize;
uniform sampler2D Texture, overlay;
uniform float BARREL_DISTORTION, v_amount, OverlayMix, LUTWidth, LUTHeight, BRIGHT_BOOST;

void main() {
    // 1. حساب إحداثيات الكيرف
    vec2 sc = TextureSize / InputSize;
    vec2 p = (TEX0 * sc) - 0.5;
    float r2 = dot(p, p);
    vec2 p_curved = p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8));
    
    // فحص الحدود (Branchless)
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float check = bounds.x * bounds.y;

    // 2. تطبيق Quilez Scaling
    // التحويل من إحداثيات الكيرف إلى فضاء النسيج ثم التكبير التكعيبي
    vec2 tex_uv = (p_curved + 0.5) / sc;
    vec2 q_p = tex_uv * TextureSize;
    vec2 q_i = floor(q_p) + 0.5;
    vec2 q_f = q_p - q_i;
    vec2 q_final = (q_i + 4.0 * q_f * q_f * q_f) / TextureSize;
    
    vec3 gm = texture2D(Texture, q_final).rgb;

    // 3. الطبقة الأولى (L1): Multiply Mode
    if (OverlayMix > 0.01) {
        vec2 mP = TEX0 * sc;
        vec2 maskUV1 = vec2(fract(mP.x * OutputSize.x / LUTWidth), 
                            fract(mP.y * OutputSize.y / LUTHeight));
        vec3 m1 = texture2D(overlay, maskUV1).rgb;
        gm = mix(gm, clamp(gm * m1, 0.0, 1.0), OverlayMix);
    }

    // 4. الفنتيج والسطوع
    gm *= clamp(1.0 - (r2 * v_amount), 0.0, 1.0);
    gl_FragColor = vec4(clamp(gm * check * BRIGHT_BOOST, 0.0, 1.0), 1.0);
}
#endif