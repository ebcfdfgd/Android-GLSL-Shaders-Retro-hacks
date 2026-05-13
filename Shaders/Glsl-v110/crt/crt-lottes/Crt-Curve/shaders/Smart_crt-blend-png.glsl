#version 110

/* LIGHT-ULTIMATE-SCANLINE-MOD (Hybrid 012 Curve)
    - FIXED: Stabilized Lottes Scanlines for PS1/Variable Res.
    - INTEGRATED: 012 Radial Distortion Logic.
    - SMART SCANLINES: Fades in bright areas to mimic CRT Beam Blooming.
    - PERFORMANCE: Branchless bounds checking & Stable Masking.
*/

// --- PARAMETERS ---
#pragma parameter BARREL_DISTORTION "Screen Curve Strength" 0.15 0.0 1.0 0.02
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 5.0 0.05
#pragma parameter v_amount "Soft Vignette Intensity" 0.15 0.0 2.5 0.01

// --- SCANLINE PARAMETERS ---
#pragma parameter hardScan "Lottes Scan Hardness" -8.0 -20.0 0.0 1.0
#pragma parameter SCAN_STR "Scanline Intensity" 0.40 0.0 1.0 0.05
#pragma parameter SCAN_THRESH "Scanline Bloom Threshold" 0.8 0.5 1.0 0.05

// L2: Fixed to Multiply
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
uniform vec2 OutputSize, TextureSize, InputSize;
uniform sampler2D Texture, overlay2;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, BRIGHT_BOOST, v_amount, hardScan, SCAN_STR, SCAN_THRESH, OverlayMix2, LUTWidth2, LUTHeight2;
#endif

// Smart Overlay function: Dynamic Bloom logic
float smart_overlay(float color, float scan, float thresh) {
    return (color < thresh) ? 
           ( (1.0 / thresh) * color * scan ) : 
           ( 1.0 - (1.0 / (1.0 - thresh)) * (1.0 - color) * (1.0 - scan) );
}

void main() {
    // 1. Coordinates & 012 Curve Logic
    vec2 p = (TEX0.xy * screen_scale) - 0.5;
    float r2 = dot(p, p);
    
    // تطبيق انحناء 012 المتطور
    vec2 p_curved = p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8));
    
    // 2. Branchless Bounds Check
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float check = bounds.x * bounds.y;

    // 3. Direct Sampling (Exact Game UVs)
    vec2 fetch_uv = (p_curved + 0.5) / screen_scale;
    vec3 gm = texture2D(Texture, fetch_uv).rgb;

    // 4. SMART LOTTES SCANLINES (FIXED & STABILIZED)
    // ربط الحساب بدقة بكسل اللعبة لضمان عدم الاهتزاز في PS1
    float pos_y = fetch_uv.y * TextureSize.y;
    float dst = fract(pos_y) - 0.5;
    float scanline = exp2(hardScan * dst * dst);
    
    vec3 smart_gm;
    smart_gm.r = smart_overlay(gm.r, scanline, SCAN_THRESH);
    smart_gm.g = smart_overlay(gm.g, scanline, SCAN_THRESH);
    smart_gm.b = smart_overlay(gm.b, scanline, SCAN_THRESH);
    
    gm = mix(gm, clamp(smart_gm, 0.0, 1.0), SCAN_STR);

    // 5. الطبقة الثانية (L2): Fixed Multiply Logic
    // تم تحسين الحساب ليعتمد على إحداثيات الشاشة الفعلية لثبات الماسك
    vec2 maskUV2 = vec2(fract(gl_FragCoord.x / LUTWidth2), 
                        fract(gl_FragCoord.y / LUTHeight2));
    vec3 m2 = texture2D(overlay2, maskUV2).rgb;
    gm = mix(gm, gm * m2, OverlayMix2);

    // 6. Final Polish (012 Style Vignette & Boost)
    gm *= (1.0 - r2 * v_amount);
    vec3 col = gm * BRIGHT_BOOST;

    gl_FragColor = vec4(col * check, 1.0);
}
#endif