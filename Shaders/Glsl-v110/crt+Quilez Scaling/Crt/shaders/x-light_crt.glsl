#version 110

/* 777-LITE-TURBO-V2-QUILEZ-INTEGRATED
    - Quilez Scaling: Organic pixel reconstruction.
    - Geometry: Curve 20 Barrel Distortion.
    - Performance: 100% Branchless design.
*/

#pragma parameter BARREL_DISTORTION "Curve 0 Strength" 0.15 0.0 1.0 0.02
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.17 1.0 2.0 0.01
#pragma parameter VIG_STR "Vignette Intensity" 0.15 0.0 2.0 0.05
#pragma parameter SCAN_STR "Scanline Intensity" 0.30 0.0 1.0 0.05
#pragma parameter MASK_STR "Mask Strength" 0.15 0.0 1.0 0.05

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
uniform float BARREL_DISTORTION, BRIGHT_BOOST, VIG_STR, SCAN_STR, MASK_STR;

void main() {
    vec2 sc = TextureSize / InputSize;
    vec2 p = (uv * sc) - 0.5;

    // 1. Curve Geometry
    float r2 = dot(p, p);
    vec2 p_curved = p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8));

    // Branchless Boundary Check
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float edge_mask = bounds.x * bounds.y;

    // 2. Quilez Scaling Logic
    vec2 final_uv = (p_curved + 0.5) / sc;
    vec2 q_p = final_uv * TextureSize;
    vec2 q_i = floor(q_p) + 0.5;
    vec2 q_f = q_p - q_i;
    vec2 q_final = (q_i + 4.0 * q_f * q_f * q_f) / TextureSize;

    // Sample Texture
    vec3 res = texture2D(Texture, q_final).rgb;
    res *= edge_mask;

    // 3. Vignette
    res *= (1.0 - r2 * VIG_STR);

    // 4. Scanlines (Direct Multiplication)
    float pixel_y = (p_curved.y + 0.5) * InputSize.y;
    float scan = sin(pixel_y * 6.283185) * 0.5 + 0.5;
    res *= mix(1.0, scan, SCAN_STR);

    // 5. Balanced RGB Mask
    vec3 mcol = vec3(0.0);
    mcol[int(mod(gl_FragCoord.x, 3.0))] = 1.0;
    res *= mix(vec3(1.0), mcol, MASK_STR);

    // 6. Final Stage
    gl_FragColor = vec4(clamp(res * BRIGHT_BOOST, 0.0, 1.0), 1.0);
}
#endif