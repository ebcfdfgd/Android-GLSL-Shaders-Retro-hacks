#version 110

/* LIGHT-ULTIMATE-SCANLINE-MOD (Flat Version)
    - SMART SCANLINES: Fades in bright areas to mimic CRT Beam Blooming.
    - UPDATED: Independent Mask Light/Dark Controls.
    - REMOVED: Curvature and Vignette.
*/

// --- PARAMETERS ---
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 5.0 0.05

// --- SCANLINE PARAMETERS ---
#pragma parameter hardScan "Lottes Scan Hardness" -8.0 -20.0 0.0 1.0
#pragma parameter SCAN_STR "Scanline Intensity" 0.40 0.0 1.0 0.05
#pragma parameter SCAN_THRESH "Scanline Bloom Threshold" 0.8 0.5 1.0 0.05

// L2: Independent Mask Controls
#pragma parameter MASK_LIGHT "Mask Light Strength" 1.5 1.0 2.0 0.05
#pragma parameter MASK_DARK "Mask Dark Strength" 0.5 0.0 1.0 0.05
#pragma parameter LUTWidth2 "L2 Width" 6.0 1.0 1024.0 1.0
#pragma parameter LUTHeight2 "L2 Height" 4.0 1.0 1024.0 1.0

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
uniform vec2 OutputSize, TextureSize;
uniform sampler2D Texture, overlay2;

#ifdef PARAMETER_UNIFORM
uniform float BRIGHT_BOOST, hardScan, SCAN_STR, SCAN_THRESH, MASK_LIGHT, MASK_DARK, LUTWidth2, LUTHeight2;
#endif

// Smart Overlay: تدمج السكان لاين وتختفي في البياض بناءً على العتبة
float smart_overlay(float color, float scan, float thresh) {
    return (color < thresh) ? 
           ( (1.0 / thresh) * color * scan ) : 
           ( 1.0 - (1.0 / (1.0 - thresh)) * (1.0 - color) * (1.0 - scan) );
}

void main() {
    // 1. Direct Sampling
    vec2 fetch_uv = TEX0.xy;
    vec3 gm = texture2D(Texture, fetch_uv).rgb;

    // 2. Smart Scanlines (Adaptive Blooming)
    float dst = fract(fetch_uv.y * TextureSize.y) - 0.5;
    float scanline = exp2(hardScan * dst * dst);
    
    vec3 smart_gm;
    smart_gm.r = smart_overlay(gm.r, scanline, SCAN_THRESH);
    smart_gm.g = smart_overlay(gm.g, scanline, SCAN_THRESH);
    smart_gm.b = smart_overlay(gm.b, scanline, SCAN_THRESH);
    
    gm = mix(gm, clamp(smart_gm, 0.0, 1.0), SCAN_STR);

    // 3. الطبقة الثانية (L2): Dynamic Multiply Mask
    vec2 mP = TEX0.xy * (TextureSize / vec2(1.0)); // استخدام أبعاد الصورة الأساسية للماسك
    vec2 maskUV2 = vec2(fract(mP.x * OutputSize.x / LUTWidth2), 
                        fract(mP.y * OutputSize.y / LUTHeight2));
    vec3 m2 = texture2D(overlay2, maskUV2).rgb;
    
    // التحكم المستقل في إضاءة وظلال الماسك
    m2 = clamp(m2 * MASK_LIGHT, MASK_DARK, MASK_LIGHT);
    gm *= m2;

    // 4. Final Polish
    vec3 col = gm * BRIGHT_BOOST;

    // 5. Output
    gl_FragColor = vec4(col, 1.0);
}
#endif