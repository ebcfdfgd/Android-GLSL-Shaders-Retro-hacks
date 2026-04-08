#version 110

/* 777-LITE-TURBO-V2-WITH-CUSTOM-MASK
    - Added: 6x4 Custom Mask (Option 1).
    - Pattern: Row1: RGBRGB | Row2: KKKRGB | Row3: RGBRGB | Row4: RGBKKK.
    - Fixed: Custom mask is independent of MASK_W zoom.
*/

#pragma parameter BARREL_DISTORTION "Screen Curve" 0.15 0.0 0.3 0.01
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.05 1.0 2.5 0.05
#pragma parameter VIG_STR "Vignette Intensity" 0.15 0.0 2.0 0.05

// --- Scanlines Control ---
#pragma parameter SCAN_STR "Scanline Intensity" 0.35 0.0 1.0 0.05
#pragma parameter SCAN_SIZE "Scanline Size (Zoom)" 5.0 1.0 10.0 0.5

// --- Advanced Mask Control ---
#pragma parameter MASK_TYPE "Mask Type: 0.Balanced|1.6x4 Custom" 0.0 0.0 1.0 1.0
#pragma parameter MASK_STR "Mask Strength" 0.15 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width (Option 0 only)" 3.0 1.0 10.0 1.0

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
uniform mat4 MVPMatrix;

void main() {
    uv = TexCoord;
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, BRIGHT_BOOST, VIG_STR, SCAN_STR, SCAN_SIZE, MASK_STR, MASK_W, MASK_TYPE;
#endif

void main() {
    vec2 sc = TextureSize / InputSize;
    vec2 p = (uv * sc) - 0.5;

    // 1. Simple Curve (Geometry)
    float ky = BARREL_DISTORTION * 0.8; 
    vec2 p_curved;
    p_curved.x = p.x * (1.0 + (p.y * p.y) * (BARREL_DISTORTION * 0.2));
    p_curved.y = p.y * (1.0 + (p.x * p.x) * ky);
    p_curved *= (1.0 - 0.1 * BARREL_DISTORTION);

    if (abs(p_curved.x) > 0.5 || abs(p_curved.y) > 0.5) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // 2. Sample & Brightness
    vec3 res = texture2D(Texture, (p_curved + 0.5) / sc).rgb;
    res *= BRIGHT_BOOST;

    // 3. Vignette
    res *= (1.0 - dot(p_curved, p_curved) * VIG_STR);

    // 4. Scanlines
    float scanline = sin(gl_FragCoord.y * (6.28318 / SCAN_SIZE)) * 0.5 + 0.5;
    res *= mix(1.0, scanline, SCAN_STR);

    // 5. Mask System
    vec3 mcol = vec3(1.0);

    if (MASK_TYPE < 0.5) {
        // الخيار 0: الماسك الأصلي المتوازن (يتاثر بـ MASK_W)
        float W = floor(MASK_W);
        float pos = mod(gl_FragCoord.x, W);
        mcol.r = clamp(2.0 - abs((pos / W) * 6.0 - 1.0), 0.6, 1.6);
        mcol.g = clamp(2.0 - abs((pos / W) * 6.0 - 3.0), 0.6, 1.6);
        mcol.b = clamp(2.0 - abs((pos / W) * 6.0 - 5.0), 0.6, 1.6);
    } 
    else {
        // الخيار 1: ماسك 6x4 مخصص (ثابت بدون زوم)
        // تحديد الإحداثيات داخل المصفوفة 6 في 4
        int px = int(mod(gl_FragCoord.x, 6.0));
        int py = int(mod(gl_FragCoord.y, 4.0));
        
        mcol = vec4(0.0).rgb; // افتراض السواد (K)

        if (py == 0 || py == 2) {
            // الصف الأول والثالث: RGBRGB
            if (mod(float(px), 3.0) < 1.0) mcol = vec3(1.0, 0.0, 0.0);
            else if (mod(float(px), 3.0) < 2.0) mcol = vec3(0.0, 1.0, 0.0);
            else mcol = vec3(0.0, 0.0, 1.0);
        }
        else if (py == 1) {
            // الصف الثاني: KKKRGB (أول 3 بكسل سوداء، آخر 3 RGB)
            if (px >= 3) {
                if (px == 3) mcol = vec3(1.0, 0.0, 0.0);
                else if (px == 4) mcol = vec3(0.0, 1.0, 0.0);
                else mcol = vec3(0.0, 0.0, 1.0);
            }
        }
        else if (py == 3) {
            // الصف الرابع: RGBKKK (أول 3 بكسل RGB، آخر 3 سوداء)
            if (px < 3) {
                if (px == 0) mcol = vec3(1.0, 0.0, 0.0);
                else if (px == 1) mcol = vec3(0.0, 1.0, 0.0);
                else mcol = vec3(0.0, 0.0, 1.0);
            }
        }
        // تقوية سطوع الماسك المخصص لتعويض السواد
        mcol *= 1.8; 
    }

    res = mix(res, res * mcol, MASK_STR);

    gl_FragColor = vec4(res, 1.0);
}
#endif