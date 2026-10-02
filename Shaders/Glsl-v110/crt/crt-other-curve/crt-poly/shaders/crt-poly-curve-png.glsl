#version 110

/* =====================================================
   PURE MATH CRT - ULTRA LIGHTWEIGHT v4.1 
   (Curved + Sharp PNG Mask Edition + good-crt-curve Geometry)
===================================================== */

// --- PARAMETERS ---
#pragma parameter CRT_WARP        "Curvature Amount"        0.10  0.0  0.5  0.01
#pragma parameter CRT_BORDER      "Border Sharpness"        0.02  0.001 0.1  0.001
#pragma parameter VIGNETTE_AMOUNT "Vignette Strength"      0.35  0.0  1.0  0.05
#pragma parameter VIGNETTE_RADIUS "Vignette Radius"        0.9   0.3  1.5  0.05
#pragma parameter BRIGHTNESS      "Brightness Boost"        1.4   1.0  3.0  0.02
#pragma parameter GAMMA           "Gamma Curve Depth"       0.4   0.0  2.0  0.05
#pragma parameter SCAN_LINES      "Scanline Count"          1080.0 240.0 1440.0 10.0
#pragma parameter SCAN_FADE       "Scanline Fade on Brights" 0.8  0.0  1.0  0.05
#pragma parameter MASK_STR        "Mask Intensity"          0.7   0.0  1.0  0.05
#pragma parameter MASK_W          "Mask Width"              6.0   1.0  64.0 1.0
#pragma parameter MASK_H          "Mask Height"             2.0   1.0  64.0 1.0

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
precision highp float;
varying vec2 uv;
uniform sampler2D Texture, SamplerMask1;

uniform vec2 TextureSize;
uniform vec2 InputSize;

uniform float CRT_WARP;
uniform float CRT_BORDER;
uniform float VIGNETTE_AMOUNT;
uniform float VIGNETTE_RADIUS;
uniform float BRIGHTNESS;
uniform float GAMMA;
uniform float SCAN_LINES;
uniform float SCAN_FADE;
uniform float MASK_STR;
uniform float MASK_W;
uniform float MASK_H;

void main() {
    // 1. Texture Atlas Fix & Coordinate Mapping (from good-crt-curve)[cite: 7]
    vec2 frameScale = InputSize / TextureSize;
    vec2 framePos = uv / frameScale;

    // 2. CRT Barrel Warp (from good-crt-curve)[cite: 7]
    vec2 cc = framePos - 0.5;
    float dist = dot(cc, cc) * CRT_WARP;
    vec2 warpedFramePos = framePos + cc * dist;

    // 3. Black Bounds & Smooth Border Mask (from good-crt-curve)[cite: 7]
    vec2 edgeDist = min(warpedFramePos, 1.0 - warpedFramePos);
    float inBounds = step(0.0, min(edgeDist.x, edgeDist.y));
    float borderMask = smoothstep(0.0, CRT_BORDER, min(edgeDist.x, edgeDist.y));

    vec2 warped_uv = warpedFramePos * frameScale;

    // --- SMOOTH TEXTURE FETCH (Interpolation) ---
    vec2 Q_p = warped_uv * TextureSize;
    vec2 Q_i = floor(Q_p) + 0.50;
    vec2 Q_f = Q_p - Q_i;
    vec2 Q_final = (Q_i + 4.0 * Q_f * Q_f * Q_f) / TextureSize;
    vec3 res = texture2D(Texture, Q_final).rgb;

    // 4. Vignette (from good-crt-curve)[cite: 7]
    float vignetteDist = length(cc) / VIGNETTE_RADIUS;
    float vignette = 1.0 - clamp(vignetteDist * vignetteDist, 0.0, 1.0) * VIGNETTE_AMOUNT;
    res = res * vignette;

    // Apply Brightness
    res = res * BRIGHTNESS;

    // 5. SCANLINE BEAM & FADE (Anti-Moiré Clamped)
    float y_pos = warped_uv.y * SCAN_LINES;
    float scan_phase = fract(y_pos);
    
    float scan_beam = 4.0 * scan_phase * (1.0 - scan_phase);
    scan_beam = clamp(scan_beam, 0.25, 1.0); 
    
    float luma = (res.r + res.g + res.b) * 0.333;
    scan_beam = scan_beam + (1.0 - scan_beam) * luma * SCAN_FADE;
    res = res * scan_beam;

    // 6. SHARP PNG MASK
    vec2 mask_size = vec2(floor(MASK_W), floor(MASK_H));
    vec2 m_uv = (mod(floor(gl_FragCoord.xy), mask_size) + 0.5) / mask_size;
    vec3 mcol = texture2D(SamplerMask1, m_uv).rgb * 1.5;
    res = mix(res, res * mcol, MASK_STR);

    // 7. GAMMA S-CURVE
    vec3 s_curve = res * res * (vec3(3.0) - vec3(2.0) * res);
    res = res * (1.0 - GAMMA) + s_curve * GAMMA;

    // Apply smooth bounds and border mask[cite: 7]
    res = res * borderMask * inBounds;

    gl_FragColor = vec4(res, 1.0);
}
#endif