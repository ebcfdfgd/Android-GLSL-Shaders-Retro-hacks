#version 110

/* 777-TURBO-ZFAST-QUILEZ-EDITION + PAS700 MASK (Curved & Border Edition)
    - INTEGRATED: Quilez Scaling + ZFast Scanlines[cite: 10].
    - MASK: PAS700 Procedural Aperture Grille[cite: 10].
    - GEOMETRY: CRT Barrel Warp, Smooth Border & Vignette from good-crt-curve[cite: 12].
*/

#pragma parameter CRT_WARP        "Curvature Amount"        0.10  0.0  0.5  0.01
#pragma parameter CRT_BORDER      "Border Sharpness"        0.02  0.001 0.1  0.001
#pragma parameter VIGNETTE_AMOUNT "Vignette Strength"      0.35  0.0  1.0  0.05
#pragma parameter VIGNETTE_RADIUS "Vignette Radius"        0.9   0.3  1.5  0.05
#pragma parameter LOWLUMSCAN "Scanline Darkness - Low" 4.5 0.0 15.0 0.5
#pragma parameter BRIGHTBOOST "Brightness Boost" 1.25 0.5 2.0 0.05
#pragma parameter MASK_STR "Mask Intensity" 0.45 0.0 1.0 0.05
#pragma parameter MASK_W "PAS700 Mask Width" 6.0 1.0 16.0 1.0
#pragma parameter SCAN_FADE_POINT "Scanline Fade Cutoff" 0.85 0.5 1.0 0.05

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
uniform float CRT_WARP, CRT_BORDER, VIGNETTE_AMOUNT, VIGNETTE_RADIUS, LOWLUMSCAN, BRIGHTBOOST, MASK_STR, MASK_W, SCAN_FADE_POINT;

void main() {
    // 1. Texture Atlas Fix & Coordinate Mapping[cite: 12]
    vec2 frameScale = InputSize / TextureSize;
    vec2 framePos = uv / frameScale;

    // 2. CRT Barrel Warp[cite: 12]
    vec2 cc = framePos - 0.5;
    float dist = dot(cc, cc) * CRT_WARP;
    vec2 warpedFramePos = framePos + cc * dist;

    // 3. Black Bounds & Smooth Border Mask[cite: 12]
    vec2 edgeDist = min(warpedFramePos, 1.0 - warpedFramePos);
    float inBounds = step(0.0, min(edgeDist.x, edgeDist.y));
    float borderMask = smoothstep(0.0, CRT_BORDER, min(edgeDist.x, edgeDist.y));

    // 4. Quilez Scaling Algorithm[cite: 10]
    vec2 texCoord = warpedFramePos * frameScale;
    vec2 q_p = texCoord * TextureSize;
    vec2 q_i = floor(q_p) + 0.5;
    vec2 q_f = q_p - q_i;
    vec2 q_final = (q_i + 4.0 * q_f * q_f * q_f) / TextureSize;
    
    vec3 res = texture2D(Texture, q_final).rgb;

    // 5. ZFast Scanlines[cite: 10]
    float pos_y = texCoord.y * TextureSize.y;
    float scan_dist = fract(pos_y) - 0.5;
    float Y = scan_dist * scan_dist;
    float scanWeightL = (BRIGHTBOOST - LOWLUMSCAN * (Y - 1.5 * Y * Y));
    
    // 6. PAS700 Procedural RGB Mask[cite: 10]
    float W = floor(MASK_W);
    float pos = mod(gl_FragCoord.x, W) / W;
    vec3 mcol = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), 0.0, 1.0);
    vec3 mask_rgb = mix(vec3(1.0), mcol, MASK_STR);

    // 7. Vignette[cite: 12]
    float vignetteDist = length(cc) / VIGNETTE_RADIUS;
    float vignette = 1.0 - clamp(vignetteDist * vignetteDist, 0.0, 1.0) * VIGNETTE_AMOUNT;
    res *= vignette;

    // 8. Final Blend & Border Mask[cite: 10, 12]
    float luma = dot(res, vec3(0.299, 0.587, 0.114));
    float final_scan = mix(scanWeightL, 1.0, smoothstep(0.1, SCAN_FADE_POINT, luma));
    vec3 final_rgb = res * final_scan * mask_rgb;
    final_rgb *= borderMask * inBounds;

    gl_FragColor = vec4(clamp(final_rgb, 0.0, 1.0), 1.0);
}
#endif