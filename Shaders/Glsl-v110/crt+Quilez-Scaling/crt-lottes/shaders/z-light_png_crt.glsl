#version 110

/* ULTIMATE-TURBO-HYBRID (V19-QUILEZ-INTEGRATED)
    - INTEGRATED: Quilez Scaling for organic pixel reconstruction.
    - CURVE: Barrel Distortion (Curve 70).
    - SCANLINES: Lottes Scanlines (exp2 method).
    - MASK: Sharp PNG pixel dimensions manual input.
*/

// --- 1. Parameters ---
#pragma parameter BARREL_DISTORTION "Screen Curve" 0.08 0.0 0.5 0.01
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 2.5 0.05
#pragma parameter v_amount "Vignette Intensity" 0.35 0.0 2.5 0.01
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
uniform float BARREL_DISTORTION, BRIGHT_BOOST, v_amount, MASK_STR, MASK_W, MASK_H, hardScan, SCAN_STR;

void main() {
    // 1. Geometry (Barrel Distortion)
    vec2 scale = TextureSize / InputSize;
    vec2 texcoord = (TEX0 * scale) - 0.5;
    float rsq = dot(texcoord, texcoord);
    texcoord += texcoord * (BARREL_DISTORTION * rsq);
    texcoord *= (1.0 - (0.12 * BARREL_DISTORTION));

    // 2. Quilez Scaling (Organic Pixel Reconstruction)
    vec2 final_uv = (texcoord + 0.5) / scale;
    vec2 q_p = final_uv * TextureSize;
    vec2 q_i = floor(q_p) + 0.5;
    vec2 q_f = q_p - q_i;
    vec2 q_final = (q_i + 4.0 * q_f * q_f * q_f) / TextureSize;
    
    vec3 res = texture2D(Texture, q_final).rgb;

    // 3. Branchless Boundary Check
    vec2 bounds = step(abs(texcoord), vec2(0.5));
    res *= (bounds.x * bounds.y);

    // 4. Lottes Scanlines
    float dst = fract(final_uv.y * TextureSize.y) - 0.5;
    float scanline = exp2(hardScan * dst * dst);
    res = mix(res, res * scanline, SCAN_STR);

    // 5. Sharp PNG-Only Mask
    vec2 mask_size = vec2(floor(MASK_W), floor(MASK_H));
    vec2 m_uv = (mod(floor(gl_FragCoord.xy), mask_size) + 0.5) / mask_size;
    vec3 mcol = texture2D(SamplerMask1, m_uv).rgb * 1.5;
    res = mix(res, res * mcol, MASK_STR);

    // 6. Smooth Vignette
    vec2 p = (TEX0 * 2.0) - 1.0;
    res *= (1.0 - clamp(dot(p, p) * v_amount * 0.25, 0.0, 1.0));

    // 7. Final Polish
    gl_FragColor = vec4(clamp(res * BRIGHT_BOOST, 0.0, 1.0), 1.0);
}
#endif