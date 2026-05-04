#version 110

/* 777-LITE-TURBO-V4-OVERCUT-FIX
    - FEATURE: True Overcut Zoom (Image + Mask + Scanlines zoom together).
    - FIXED: Mask is locked to the game pixel, not the screen.
    - STABLE: No alignment shifts during zoom.
*/

#pragma parameter GAME_ZOOM "Global Zoom Scale" 0.964 0.5 2.0 0.001
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.10 1.0 2.0 0.01
#pragma parameter hardScan "Lottes Scan Hardness" -8.0 -20.0 0.0 1.0
#pragma parameter SCAN_STR "Scanline Intensity" 0.40 0.0 1.0 0.05
#pragma parameter MASK_STR "Mask Strength" 0.4 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width (3=RGB)" 7.0 1.0 12.0 1.0
#pragma parameter MASK_OFFSET "Mask Color Offset" 0.0 -10.0 10.0 1.0

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 TEX0;
uniform mat4 MVPMatrix;

void main() {
    TEX0 = TexCoord;
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 TEX0;
uniform sampler2D Texture;
uniform vec2 TextureSize;

#ifdef PARAMETER_UNIFORM
uniform float GAME_ZOOM, BRIGHT_BOOST, hardScan, SCAN_STR, MASK_STR, MASK_W, MASK_OFFSET;
#endif

void main() {
    // [1] Apply Zoom Logic (The "Magnifying Glass" effect)
    vec2 uv = (TEX0.xy - 0.5) / GAME_ZOOM + 0.5;

    // [2] Bounds Check
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // [3] Sampling Game Image
    vec3 res = texture2D(Texture, uv).rgb;

    // [4] التحويل إلى إحداثيات بكسل اللعبة (Pixel-Locked Coordinates)
    // هذا يجعل كل التأثيرات التالية تتبع الزوم تلقائياً
    vec2 game_pix = uv * TextureSize;

    // [5] LOTTES SCANLINES (Locked to zoomed pixels)
    float dst = fract(game_pix.y) - 0.5;
    float scanline = exp2(hardScan * dst * dst);
    res = mix(res, res * scanline, SCAN_STR);

    // [6] RGB Mask (Locked to zoomed pixels)
    // استخدمنا game_pix.x لضمان أن الماسك يزحف مع الصورة
    float W = floor(MASK_W);
    float pos = mod(game_pix.x * W + floor(MASK_OFFSET), W) / W;
    
    // معادلة ماسك RGB ثابتة ونقية
    vec3 mcol = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), 0.0, 1.0);
    res = mix(res, res * mcol, MASK_STR);

    // [7] Final Polish
    res *= BRIGHT_BOOST;

    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif