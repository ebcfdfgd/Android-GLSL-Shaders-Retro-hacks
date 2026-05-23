#version 110

/* LIGHT-ULTIMATE-SCANLINE-MOD (Flat Version)
    - INTEGRATED: Direct mapping (No Curve).
    - KEPT: Lottes Scanlines.
    - UPDATED: Independent Light/Dark Mask Controls for L2.
    - PERFORMANCE: Optimized flat display.
*/

// --- PARAMETERS ---
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 5.0 0.05

// --- SCANLINE PARAMETERS ---
#pragma parameter hardScan "Lottes Scan Hardness" -8.0 -20.0 0.0 1.0
#pragma parameter SCAN_STR "Scanline Intensity" 0.40 0.0 1.0 0.05

// L2: Independent Mask Controls
#pragma parameter MASK_LIGHT "Mask Light Strength" 1.5 1.0 2.0 0.05
#pragma parameter MASK_DARK "Mask Dark Strength" 0.5 0.0 1.0 0.05
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
uniform sampler2D Texture, overlay2;

#ifdef PARAMETER_UNIFORM
uniform float BRIGHT_BOOST, hardScan, SCAN_STR, MASK_LIGHT, MASK_DARK, LUTWidth2, LUTHeight2;
#endif

// Overlay blend function
float overlay_f(float a, float b) {
    return (a < 0.5) ? (2.0 * a * b) : (1.0 - 2.0 * (1.0 - a) * (1.0 - b));
}

void main() {
    // 1. Direct Mapping (No Curve, No Vignette)
    vec2 fetch_uv = TEX0.xy;
    vec3 gm = texture2D(Texture, fetch_uv).rgb;

    // 2. SCANLINES (Lottes)
    float dst = fract(fetch_uv.y * TextureSize.y) - 0.5;
    float scanline = exp2(hardScan * dst * dst);
    gm = mix(gm, vec3(overlay_f(gm.r, scanline), overlay_f(gm.g, scanline), overlay_f(gm.b, scanline)), SCAN_STR);

    // 3. الطبقة الثانية (L2): Dynamic Multiply Mask
    vec2 mP = TEX0.xy * screen_scale;
    vec2 maskUV2 = vec2(fract(mP.x * OutputSize.x / LUTWidth2), 
                        fract(mP.y * OutputSize.y / LUTHeight2));
    vec3 m2 = texture2D(overlay2, maskUV2).rgb;
    
    // تطبيق التحكم في الإضاءة والظلال للماسك
    m2 = clamp(m2 * MASK_LIGHT, MASK_DARK, MASK_LIGHT);
    gm *= m2;

    // 4. Final Polish (Brightness only)
    gm *= BRIGHT_BOOST;

    // 5. Final Output
    gl_FragColor = vec4(gm, 1.0);
}
#endif