#version 110

/* 777-LITE-TURBO-V4-QUILEZ-LOTTES + PAS700 MASK (Curved & Border Edition)
    - INTEGRATED: Quilez Scaling & Lottes Scanlines.
    - MASK: PAS700 Procedural Aperture Grille.
    - GEOMETRY: CRT Barrel Warp, Smooth Border & Vignette from good-crt-curve.
*/

#pragma parameter CRT_WARP        "Curvature Amount"        0.10  0.0  0.5  0.01
#pragma parameter CRT_BORDER      "Border Sharpness"        0.02  0.001 0.1  0.001
#pragma parameter VIGNETTE_AMOUNT "Vignette Strength"      0.35  0.0  1.0  0.05
#pragma parameter VIGNETTE_RADIUS "Vignette Radius"        0.9   0.3  1.5  0.05
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.20 1.0 2.0 0.01
#pragma parameter hardScan "Lottes Scan Hardness" -8.0 -20.0 0.0 1.0
#pragma parameter SCAN_STR "Scanline Intensity" 0.40 0.0 1.0 0.05
#pragma parameter MASK_STR "Mask Strength" 0.20 0.0 1.0 0.05
#pragma parameter MASK_W "PAS700 Mask Width" 6.0 1.0 16.0 1.0

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
uniform vec2 InputSize;

uniform float CRT_WARP, CRT_BORDER, VIGNETTE_AMOUNT, VIGNETTE_RADIUS, BRIGHT_BOOST, hardScan, SCAN_STR, MASK_STR, MASK_W;

void main() {
    // 1. Texture Atlas Fix & Coordinate Mapping
    vec2 frameScale = InputSize / TextureSize;
    vec2 framePos = uv / frameScale;

    // 2. CRT Barrel Warp
    vec2 cc = framePos - 0.5;
    float dist = dot(cc, cc) * CRT_WARP;
    vec2 warpedFramePos = framePos + cc * dist;

    // 3. Black Bounds & Smooth Border Mask
    vec2 edgeDist = min(warpedFramePos, 1.0 - warpedFramePos);
    float inBounds = step(0.0, min(edgeDist.x, edgeDist.y));
    float borderMask = smoothstep(0.0, CRT_BORDER, min(edgeDist.x, edgeDist.y));

    // 4. Quilez Scaling (Organic Pixel Reconstruction)
    vec2 tex_uv = warpedFramePos * frameScale;
    vec2 q_p = tex_uv * TextureSize;
    vec2 q_i = floor(q_p) + 0.5;
    vec2 q_f = q_p - q_i;
    vec2 q_final = (q_i + 4.0 * q_f * q_f * q_f) / TextureSize;
    
    vec3 res = texture2D(Texture, q_final).rgb;

    // 5. LOTTES SCANLINES
    float scan_dist = fract(tex_uv.y * TextureSize.y) - 0.5;
    float scanline = exp2(hardScan * scan_dist * scan_dist);
    res = mix(res, res * scanline, SCAN_STR);

    // 6. RGB Mask (PAS700)
    if (MASK_STR > 0.01) {
        float W = floor(MASK_W);
        float pos = mod(gl_FragCoord.x, W) / W;
        vec3 mcol = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), 0.0, 1.0);
        res = mix(res, res * mcol, MASK_STR);
    }

    // 7. Vignette
    float vignetteDist = length(cc) / VIGNETTE_RADIUS;
    float vignette = 1.0 - clamp(vignetteDist * vignetteDist, 0.0, 1.0) * VIGNETTE_AMOUNT;
    res *= vignette;

    // 8. Final Polish & Apply Bounds/Border
    res *= BRIGHT_BOOST;
    res *= borderMask * inBounds;

    gl_FragColor = vec4(res, 1.0);
}
#endif