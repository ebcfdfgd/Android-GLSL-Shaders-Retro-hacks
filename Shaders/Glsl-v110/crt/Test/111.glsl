#version 110

/* 777-LITE-HYBRID-V3
    - Integrated: Zfast Quilez Scaling + Consumer Convergence.
    - Performance: Ultra-lite for mobile and low-end PC.
*/

#pragma parameter BARREL_DISTORTION "Screen Curve" 0.15 0.0 1.0 0.02
#pragma parameter BLURSCALEX "Sharpness X (Zfast)" 0.45 0.0 1.0 0.05
#pragma parameter CONV_X "TV Convergence X" 0.35 0.0 2.0 0.05
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.20 1.0 2.0 0.01
#pragma parameter SCAN_STR "Scanline Intensity" 0.30 0.0 1.0 0.05
#pragma parameter MASK_STR "Mask Strength" 0.15 0.0 1.0 0.05

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
uniform float BARREL_DISTORTION, BLURSCALEX, CONV_X, BRIGHT_BOOST, SCAN_STR, MASK_STR;
#endif

void main() {
    vec2 sc = TextureSize / InputSize;
    vec2 p = (uv * sc) - 0.5;

    // 1. Curve Logic (Geometry)
    vec2 p_curved;
    p_curved.x = p.x * (1.0 + (p.y * p.y) * (BARREL_DISTORTION * 0.2));
    p_curved.y = p.y * (1.0 + (p.x * p.x) * (BARREL_DISTORTION * 0.12));
    p_curved *= (1.0 - 0.1 * BARREL_DISTORTION);

    // Border Safety
    if (abs(p_curved.x) > 0.5 || abs(p_curved.y) > 0.5) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // 2. Zfast Quilez Core (The "Kwalls" Logic)
    vec2 z_uv = (p_curved + 0.5) / sc;
    vec2 z_p = z_uv * TextureSize;
    vec2 z_i = floor(z_p) + 0.5;
    vec2 z_f = z_p - z_i;

    vec2 final_uv;
    final_uv.y = (z_i.y + 4.0 * z_f.y * z_f.y * z_f.y) / TextureSize.y;
    final_uv.x = mix((z_i.x + 4.0 * z_f.x * z_f.x * z_f.x) / TextureSize.x, z_uv.x, BLURSCALEX);

    // 3. Convergence (Home TV Color Bleeding)
    // بنسحب اللون بإزاحة بسيطة عشان نحاكي التلفزيون القديم
    vec2 c_off = vec2(CONV_X, 0.0) / TextureSize;
    float r = texture2D(Texture, final_uv + c_off).r;
    vec2  gb = texture2D(Texture, final_uv - c_off).gb;
    vec3 res = vec3(r, gb.x, gb.y);

    // 4. Scanlines (Fixed Sin-wave for speed)
    float scanline = sin(gl_FragCoord.y * 1.25) * 0.5 + 0.5;
    res *= mix(1.0, scanline, SCAN_STR);

    // 5. Fast RGB Mask (Shadow Mask style)
    float pos = mod(gl_FragCoord.x, 3.0);
    vec3 mcol = vec3(1.0);
    if (pos < 1.0) mcol.r = 1.25; else if (pos < 2.0) mcol.g = 1.25; else mcol.b = 1.25;
    res = mix(res, res * mcol, MASK_STR);

    // 6. Final Stage
    gl_FragColor = vec4(res * BRIGHT_BOOST, 1.0);
}
#endif