#version 110

/* ULTIMATE-TURBO-HYBRID (V19-EXACT-PIXEL-FIXED)
    - INTEGRATED: Barrel Distortion (Curve 70 Logic).
    - SPEED: 100% Branchless design.
    - MASK: Sharp PNG pixel dimensions manual input.
    - SCANLINES: Integrated ultra-fast Lottes Scanlines (exp2 method).
*/

// --- 1. Coordinates & Curve ---
#pragma parameter BARREL_DISTORTION "Screen Curve" 0.08 0.0 0.5 0.01
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 2.5 0.05
#pragma parameter v_amount "Vignette Intensity (0=OFF)" 0.35 0.0 2.5 0.01

// --- 2. PNG Mask System ---
#pragma parameter MASK_STR "Mask Intensity (0=OFF)" 0.45 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width (Texture Pixels)" 6.0 1.0 64.0 1.0
#pragma parameter MASK_H "Mask Height (Texture Pixels)" 2.0 1.0 64.0 1.0

// --- 3. Lottes Scanlines ---
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

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, BRIGHT_BOOST, v_amount;
uniform float MASK_STR, MASK_W, MASK_H;
uniform float hardScan, SCAN_STR;
#endif

void main() {
    // 1. Geometry (Enhanced Curve 70 Logic)
    vec2 scale = TextureSize / InputSize;
    vec2 tex = TEX0 * scale;
    vec2 texcoord = tex - vec2(0.5);
    
    float rsq = texcoord.x * texcoord.x + texcoord.y * texcoord.y;
    texcoord += texcoord * (BARREL_DISTORTION * rsq);
    texcoord *= (1.0 - (0.12 * BARREL_DISTORTION));

    // Branchless Boundary Check
    vec2 bounds = step(abs(texcoord), vec2(0.5));
    float edge_mask = bounds.x * bounds.y;

    vec2 final_uv = (texcoord + vec2(0.5)) / scale;

    // 2. Texture Sampling
    vec3 res = texture2D(Texture, final_uv).rgb;

    // 3. Lottes Scanlines
    float dst = fract(final_uv.y * TextureSize.y) - 0.5;
    float scanline = exp2(hardScan * dst * dst);
    res = mix(res, res * scanline, SCAN_STR);

    // 4. Sharp PNG-Only Mask System
    vec2 mask_size = vec2(floor(MASK_W), floor(MASK_H));
    vec2 pixel_coord = floor(gl_FragCoord.xy);
    vec2 repeated_coord = mod(pixel_coord, mask_size);
    vec2 m_uv = (repeated_coord + 0.5) / mask_size;
    
    vec3 mcol = texture2D(SamplerMask1, m_uv).rgb * 1.5;
    res = mix(res, res * mcol, MASK_STR);

    // 5. Smooth Vignette
    vec2 p = (TEX0 * 2.0) - 1.0;
    res *= (1.0 - clamp(dot(p, p) * v_amount * 0.25, 0.0, 1.0));

    // 6. FINAL STAGE
    gl_FragColor = vec4(res * BRIGHT_BOOST * edge_mask, 1.0);
}
#endif