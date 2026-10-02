#version 110

/* ULTIMATE-TURBO-HYBRID (Curved & Sharp PNG Mask Edition)
    - INTEGRATED: Quilez Scaling & Lottes Scanlines.
    - MASK: Sharp PNG pixel dimensions manual input.
    - GEOMETRY: CRT Barrel Warp, Smooth Border & Vignette from good-crt-curve.
*/

#pragma parameter CRT_WARP        "Curvature Amount"        0.10  0.0  0.5  0.01
#pragma parameter CRT_BORDER      "Border Sharpness"        0.02  0.001 0.1  0.001
#pragma parameter VIGNETTE_AMOUNT "Vignette Strength"      0.35  0.0  1.0  0.05
#pragma parameter VIGNETTE_RADIUS "Vignette Radius"        0.9   0.3  1.5  0.05
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 2.5 0.05
#pragma parameter MASK_STR "Mask Intensity" 0.45 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width" 6.0 1.0 64.0 1.0
#pragma parameter MASK_H "Mask Height" 2.0 1.0 64.0 1.0
#pragma parameter hardScan "Lottes Scan Hardness" -8.0 -20.0 0.0 1.0
#pragma parameter SCAN_STR "Scanline Intensity" 0.40 0.0 1.0 0.05

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
precision mediump float;
#endif

varying vec2 TEX0;
uniform sampler2D Texture, SamplerMask1;
uniform vec2 TextureSize, InputSize;
uniform float CRT_WARP, CRT_BORDER, VIGNETTE_AMOUNT, VIGNETTE_RADIUS, BRIGHT_BOOST, MASK_STR, MASK_W, MASK_H, hardScan, SCAN_STR;

void main() {
    // 1. Texture Atlas Fix & Coordinate Mapping
    vec2 frameScale = InputSize / TextureSize;
    vec2 framePos = TEX0 / frameScale;

    // 2. CRT Barrel Warp
    vec2 cc = framePos - 0.5;
    float dist = dot(cc, cc) * CRT_WARP;
    vec2 warpedFramePos = framePos + cc * dist;

    // 3. Black Bounds & Smooth Border Mask
    vec2 edgeDist = min(warpedFramePos, 1.0 - warpedFramePos);
    float inBounds = step(0.0, min(edgeDist.x, edgeDist.y));
    float borderMask = smoothstep(0.0, CRT_BORDER, min(edgeDist.x, edgeDist.y));

    // 4. Quilez Scaling (Organic Pixel Reconstruction)
    vec2 final_uv = warpedFramePos * frameScale;
    vec2 q_p = final_uv * TextureSize;
    vec2 q_i = floor(q_p) + 0.5;
    vec2 q_f = q_p - q_i;
    vec2 q_final = (q_i + 4.0 * q_f * q_f * q_f) / TextureSize;
    
    vec3 res = texture2D(Texture, q_final).rgb;

    // 5. Lottes Scanlines
    float scan_dist = fract(final_uv.y * TextureSize.y) - 0.5;
    float scanline = exp2(hardScan * scan_dist * scan_dist);
    res = mix(res, res * scanline, SCAN_STR);

    // 6. Sharp PNG-Only Mask
    vec2 mask_size = vec2(floor(MASK_W), floor(MASK_H));
    vec2 m_uv = (mod(floor(gl_FragCoord.xy), mask_size) + 0.5) / mask_size;
    vec3 mcol = texture2D(SamplerMask1, m_uv).rgb * 1.5;
    res = mix(res, res * mcol, MASK_STR);

    // 7. Vignette
    float vignetteDist = length(cc) / VIGNETTE_RADIUS;
    float vignette = 1.0 - clamp(vignetteDist * vignetteDist, 0.0, 1.0) * VIGNETTE_AMOUNT;
    res *= vignette;

    // 8. Final Polish & Apply Bounds/Border
    res *= BRIGHT_BOOST;
    res *= borderMask * inBounds;

    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif