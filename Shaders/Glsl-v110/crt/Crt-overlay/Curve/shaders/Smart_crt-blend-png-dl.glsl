#version 110

/* LIGHT-ULTIMATE-SCANLINE-MOD (Screen-Locked Mask Revision)
    - INTEGRATED: Barrel Distortion (Curve 70 Logic).
    - SYNCED: Scanlines synced to TEX0 (Fixed grid).
    - FIXED: Mask synced to gl_FragCoord (Screen-Locked).
    - OPTIMIZED: Using dot products and vectorized operations.
*/

// --- PARAMETERS ---
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 5.0 0.05
#pragma parameter hardScan "Lottes Scan Hardness" -8.0 -20.0 0.0 1.0
#pragma parameter SCAN_STR "Scanline Intensity" 0.40 0.0 1.0 0.05
#pragma parameter SCAN_THRESH "Scanline Bloom Threshold" 0.8 0.5 1.0 0.05
#pragma parameter MASK_LIGHT "Mask Light Strength" 1.5 1.0 2.0 0.05
#pragma parameter MASK_DARK "Mask Dark Strength" 0.5 0.0 1.0 0.05
#pragma parameter LUTWidth2 "L2 Width" 6.0 1.0 1024.0 1.0
#pragma parameter LUTHeight2 "L2 Height" 4.0 1.0 1024.0 1.0
#pragma parameter BARREL_DISTORTION "Screen Curve" 0.08 0.0 0.5 0.01

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
precision highp float;
varying vec2 TEX0;
uniform vec2 OutputSize, TextureSize, InputSize;
uniform sampler2D Texture, overlay2;
uniform float BRIGHT_BOOST, hardScan, SCAN_STR, SCAN_THRESH, MASK_LIGHT, MASK_DARK, LUTWidth2, LUTHeight2, BARREL_DISTORTION;

float smart_overlay(float color, float scan, float thresh) {
    return (color < thresh) ? 
           ((1.0 / thresh) * color * scan) : 
           (1.0 - (1.0 / (1.0 - thresh)) * (1.0 - color) * (1.0 - scan));
}

void main() {
    // 1. BARREL DISTORTION (الهندسة فقط)
    vec2 scale = TextureSize / InputSize;
    vec2 texcoord = (TEX0 * scale) - vec2(0.5);
    
    float rsq = dot(texcoord, texcoord);
    texcoord += texcoord * (BARREL_DISTORTION * rsq);
    texcoord *= (1.0 - (0.12 * BARREL_DISTORTION));

    if (abs(texcoord.x) > 0.5 || abs(texcoord.y) > 0.5) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }
    
    vec2 warped_uv = (texcoord + vec2(0.5)) / scale;

    // 2. سحب اللون
    vec3 gm = texture2D(Texture, warped_uv).rgb;

    // 3. SCANLINES (مزامنة مع TEX0 لثبات الشبكة)
    float dst = fract(TEX0.y * TextureSize.y) - 0.5;
    float scanline = exp2(hardScan * dst * dst);
    
    vec3 smart_gm = vec3(
        smart_overlay(gm.r, scanline, SCAN_THRESH),
        smart_overlay(gm.g, scanline, SCAN_THRESH),
        smart_overlay(gm.b, scanline, SCAN_THRESH)
    );
    gm = mix(gm, clamp(smart_gm, 0.0, 1.0), SCAN_STR);

    // 4. MASK (SCREEN-LOCKED: الآن يتبع الشاشة)
    // نستخدم gl_FragCoord بدلاً من TEX0 لضمان أن الماسك ثابت أمام الشاشة
    vec2 maskUV2 = gl_FragCoord.xy / vec2(LUTWidth2, LUTHeight2);
    vec3 m2 = texture2D(overlay2, maskUV2).rgb;
    
    m2 = clamp(m2 * MASK_LIGHT, MASK_DARK, MASK_LIGHT);
    gm *= m2;

    // 5. الإخراج النهائي
    gl_FragColor = vec4(clamp(gm * BRIGHT_BOOST, 0.0, 1.0), 1.0);
}
#endif