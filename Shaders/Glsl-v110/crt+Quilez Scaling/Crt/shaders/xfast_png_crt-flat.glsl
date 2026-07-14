#version 110

/* ULTIMATE-TURBO-HYBRID (V20-QUILEZ-PURE-FLAT)
    - INTEGRATED: Quilez Scaling for organic clarity.
    - SCANLINES: Zfast Pixel-Sync with Smart Fade.
    - MASK: Exact manual PNG texture control.
*/

#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.25 0.5 2.0 0.05
#pragma parameter MASK_STR "Mask Intensity (0=OFF)" 0.45 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width" 6.0 1.0 64.0 1.0
#pragma parameter MASK_H "Mask Height" 2.0 1.0 64.0 1.0
#pragma parameter LOWLUMSCAN "Scanline Darkness" 4.5 0.0 15.0 0.5
#pragma parameter SCAN_FADE_POINT "Scanline Fade Cutoff" 0.85 0.5 1.0 0.05

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
uniform sampler2D Texture, SamplerMask1;
uniform vec2 TextureSize;
uniform float BRIGHT_BOOST, MASK_STR, MASK_W, MASK_H, LOWLUMSCAN, SCAN_FADE_POINT;

void main() {
    // 1. Quilez Scaling (سحب اللون فائق النقاء بدلاً من السحب الخطي)
    vec2 q_p = TEX0 * TextureSize;
    vec2 q_i = floor(q_p) + 0.5;
    vec2 q_f = q_p - q_i;
    vec2 final_uv = (q_i + 4.0 * q_f * q_f * q_f) / TextureSize;

    vec3 res = texture2D(Texture, final_uv).rgb;

    // 2. Zfast Pixel-Sync Scanlines
    float pos_y = TEX0.y * TextureSize.y;
    float dist = fract(pos_y) - 0.5;
    float Y = dist * dist;
    float YY = Y * Y;

    float scanWeightL = (BRIGHT_BOOST - LOWLUMSCAN * (Y - 1.5 * YY));

    float luma = dot(res, vec3(0.299, 0.587, 0.114));
    float final_scan = mix(scanWeightL, 1.0, smoothstep(0.1, SCAN_FADE_POINT, luma));
    res *= final_scan;

    // 3. Sharp PNG Mask System
    vec2 mask_size = vec2(floor(MASK_W), floor(MASK_H));
    vec2 repeated_coord = mod(floor(gl_FragCoord.xy), mask_size);
    vec2 m_uv = (repeated_coord + 0.5) / mask_size;
    
    vec3 mcol = texture2D(SamplerMask1, m_uv).rgb * 1.5;
    res = mix(res, res * mcol, MASK_STR);

    // 4. Final Stage
    gl_FragColor = vec4(clamp(res * BRIGHT_BOOST, 0.0, 1.0), 1.0);
}
#endif