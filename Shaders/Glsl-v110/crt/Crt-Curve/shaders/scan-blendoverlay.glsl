/* TOSHIBA-V3XEL-TURBO-HYBRID (L2 + Scan + Bloom)
    - REMOVED: Zoom, L1 Overlay logic.
    - KEPT: L2 Multiply (Overlay2).
    - ADDED: Lottes Scanlines + Luma-based Bloom.
    - CORE: Quilez Scaling & Barrel Distortion.
*/

#version 110

// --- PARAMETERS ---
#pragma parameter BARREL_DISTORTION "Toshiba Curve Strength" 0.12 0.0 0.5 0.01
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 5.0 0.05
#pragma parameter v_amount "Soft Vignette Intensity" 0.25 0.0 2.5 0.01

// L2: Fixed to Multiply
#pragma parameter OverlayMix2 "L2 Intensity (Multiply)" 0.0 0.0 1.0 0.05
#pragma parameter LUTWidth2 "L2 Width" 6.0 1.0 1024.0 1.0
#pragma parameter LUTHeight2 "L2 Height" 4.0 1.0 1024.0 1.0

// Effects
#pragma parameter SCAN_STRENGTH "Scanline Intensity" 0.35 0.0 1.0 0.05
#pragma parameter hardScan "Scanline Hardness" -8.0 -20.0 0.0 1.0
#pragma parameter BLOOM_INT "Bloom Intensity" 0.25 0.0 1.0 0.05
#pragma parameter BLOOM_TH "Bloom Threshold" 0.7 0.0 1.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec4 TexCoord;
varying vec2 TEX0, screen_scale, inv_tex_size;
uniform mat4 MVPMatrix;
uniform vec2 TextureSize, InputSize;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    TEX0 = TexCoord.xy;
    screen_scale = TextureSize / InputSize;
    inv_tex_size = 1.0 / TextureSize;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 TEX0, screen_scale, inv_tex_size;
uniform vec2 OutputSize, TextureSize, InputSize;
uniform sampler2D Texture, overlay2;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, BRIGHT_BOOST, v_amount, OverlayMix2, LUTWidth2, LUTHeight2, SCAN_STRENGTH, hardScan, BLOOM_INT, BLOOM_TH;
#endif

void main() {
    // 1. إعداد الإحداثيات والتقوس
    vec2 uv = (TEX0.xy * screen_scale) - 0.5;
    
    float kx = BARREL_DISTORTION * 0.2; 
    float ky = BARREL_DISTORTION * 0.9; 

    vec2 d_uv;
    d_uv.x = uv.x * (1.0 + (uv.y * uv.y) * kx);
    d_uv.y = uv.y * (1.0 + (uv.x * uv.x) * ky);
    d_uv *= (1.0 - 0.15 * BARREL_DISTORTION);
    
    if (abs(d_uv.x) > 0.5 || abs(d_uv.y) > 0.5) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // [B] محرك Quilez Scaling
    vec2 fetch_uv = (d_uv + 0.5) / screen_scale;
    vec2 p = fetch_uv * TextureSize;
    vec2 i = floor(p);
    vec2 f = p - i;
    f = f * f * (3.0 - 2.0 * f); 
    
    vec3 gm = texture2D(Texture, (i + f + 0.5) * inv_tex_size).rgb;

    // 2. الطبقة الثانية (L2): Multiply (تم الإبقاء عليها)
    vec2 mP = TEX0.xy * screen_scale;
    if (OverlayMix2 > 0.01) {
        vec2 maskUV2 = vec2(fract(mP.x * OutputSize.x / LUTWidth2), fract(mP.y * OutputSize.y / LUTHeight2));
        vec3 m2 = texture2D(overlay2, maskUV2).rgb;
        gm = mix(gm, gm * m2, OverlayMix2);
    }

    // 3. Scanlines (Lottes)
    float dst = fract(fetch_uv.y * TextureSize.y) - 0.5;
    float scan = exp2(hardScan * dst * dst);
    gm = mix(gm, gm * scan, SCAN_STRENGTH);

    // 4. Bloom (Luma-based)
    float luma = dot(gm, vec3(0.299, 0.587, 0.114));
    float bloom_mask = max(0.0, luma - BLOOM_TH);
    gm += gm * bloom_mask * BLOOM_INT;

    // 5. Soft Vignette
    float vignette_sq = dot(d_uv, d_uv);
    gm *= clamp(1.0 - (vignette_sq * vignette_sq * v_amount), 0.0, 1.0);

    // تطبيق الـ Boost النهائي
    gl_FragColor = vec4(clamp(gm * BRIGHT_BOOST, 0.0, 1.0), 1.0);
}
#endif