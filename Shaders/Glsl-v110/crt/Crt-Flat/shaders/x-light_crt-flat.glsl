#version 110

/* 777-LITE-TURBO-FLAT-VERSION
    - REMOVED: Barrel Distortion & Vignette (Full Screen Flat).
    - FIXED: Scanlines now lock perfectly to game pixels.
    - SPEED: Zero-cost math, Branchless logic.
*/

#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.20 1.0 2.0 0.01
#pragma parameter SCAN_STR "Scanline Intensity" 0.40 0.0 1.0 0.05
#pragma parameter SCAN_SIZE "Scanline Density" 1.0 0.5 2.0 0.05
#pragma parameter MASK_STR "Mask Strength" 0.20 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width (3=RGB)" 3.0 1.0 6.0 1.0

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
uniform vec2 TextureSize;

#ifdef PARAMETER_UNIFORM
uniform float BRIGHT_BOOST, SCAN_STR, SCAN_SIZE, MASK_STR, MASK_W;
#endif

void main() {
    // 1. Direct Sampling (بدون كيرف)
    vec3 res = texture2D(Texture, uv).rgb;

    // 2. FIXED SCANLINES
    // الحساب المباشر بناءً على ارتفاع التكستشر لضمان ثبات الخطوط
    float scan_pos = uv.y * TextureSize.y;
    float scanline = sin(scan_pos * 6.28318 * SCAN_SIZE) * 0.5 + 0.5;
    res = mix(res, res * scanline, SCAN_STR);

    // 3. Optimized RGB Mask
    float W = floor(MASK_W);
    float pos = mod(gl_FragCoord.x, W) / W;
    vec3 mcol = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), 0.6, 1.6);
    res = mix(res, res * mcol, MASK_STR);

    // 4. Final Polish
    res *= BRIGHT_BOOST;

    gl_FragColor = vec4(res, 1.0);
}
#endif