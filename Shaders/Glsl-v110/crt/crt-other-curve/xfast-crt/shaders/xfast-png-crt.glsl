#version 110

/* ULTIMATE-TURBO-HYBRID (Curved & Border Edition)
    - INTEGRATED: Quilez Scaling + Zfast Scanlines + Sharp PNG Mask[cite: 11].
    - GEOMETRY: CRT Barrel Warp, Smooth Border & Vignette from good-crt-curve[cite: 12].
*/

#pragma parameter CRT_WARP        "Curvature Amount"        0.10  0.0  0.5  0.01
#pragma parameter CRT_BORDER      "Border Sharpness"        0.02  0.001 0.1  0.001
#pragma parameter VIGNETTE_AMOUNT "Vignette Strength"      0.35  0.0  1.0  0.05
#pragma parameter VIGNETTE_RADIUS "Vignette Radius"        0.9   0.3  1.5  0.05
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.25 0.5 2.0 0.05
#pragma parameter MASK_STR "Mask Intensity" 0.45 0.0 1.0 0.05
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
uniform vec2 TextureSize, InputSize;
uniform float CRT_WARP, CRT_BORDER, VIGNETTE_AMOUNT, VIGNETTE_RADIUS, BRIGHT_BOOST, MASK_STR, MASK_W, MASK_H, LOWLUMSCAN, SCAN_FADE_POINT;

void main() {
    // 1. Texture Atlas Fix & Coordinate Mapping[cite: 12]
    vec2 frameScale = InputSize / TextureSize;
    vec2 framePos = TEX0 / frameScale;

    // 2. CRT Barrel Warp[cite: 12]
    vec2 cc = framePos - 0.5;
    float dist = dot(cc, cc) * CRT_WARP;
    vec2 warpedFramePos = framePos + cc * dist;

    // 3. Black Bounds & Smooth Border Mask[cite: 12]
    vec2 edgeDist = min(warpedFramePos, 1.0 - warpedFramePos);
    float inBounds = step(0.0, min(edgeDist.x, edgeDist.y));
    float borderMask = smoothstep(0.0, CRT_BORDER, min(edgeDist.x, edgeDist.y));

    // 4. Quilez Scaling[cite: 11]
    vec2 final_uv = warpedFramePos * frameScale;
    vec2 q_p = final_uv * TextureSize;
    vec2 q_i = floor(q_p) + 0.5;
    vec2 q_f = q_p - q_i;
    vec2 q_final = (q_i + 4.0 * q_f * q_f * q_f) / TextureSize;
    
    vec3 res = texture2D(Texture, q_final).rgb;

    // 5. Zfast Pixel-Sync Scanlines[cite: 11]
    float pos_y = final_uv.y * TextureSize.y;
    float scan_dist = fract(pos_y) - 0.5;
    float Y = scan_dist * scan_dist;
    float YY = Y * Y;

    float scanWeightL = (BRIGHT_BOOST - LOWLUMSCAN * (Y - 1.5 * YY));
    float luma = dot(res, vec3(0.299, 0.587, 0.114));
    float final_scan = mix(scanWeightL, 1.0, smoothstep(0.1, SCAN_FADE_POINT, luma));
    res *= final_scan;

    // 6. Sharp PNG Mask[cite: 11]
    vec2 mask_size = vec2(floor(MASK_W), floor(MASK_H));
    vec2 m_uv = (mod(floor(gl_FragCoord.xy), mask_size) + 0.5) / mask_size;
    vec3 mcol = texture2D(SamplerMask1, m_uv).rgb * 1.5;
    res = mix(res, res * mcol, MASK_STR);

    // 7. Vignette[cite: 12]
    float vignetteDist = length(cc) / VIGNETTE_RADIUS;
    float vignette = 1.0 - clamp(vignetteDist * vignetteDist, 0.0, 1.0) * VIGNETTE_AMOUNT;
    res *= vignette;

    // 8. Final Polish & Apply Bounds/Border[cite: 11, 12]
    res *= BRIGHT_BOOST;
    res *= borderMask * inBounds;

    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif