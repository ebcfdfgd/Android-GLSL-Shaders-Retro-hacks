#version 110

/* 777-LITE-TURBO-V2-QUILEZ-FLAT
    - INTEGRATED: Quilez Scaling for perfect pixel reconstruction.
    - OPTIMIZED: 100% Branchless (No 'if' conditions).
    - SCANLINES: Pixel-Sync with Flat Projection.
*/

#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.17 1.0 2.0 0.01
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
uniform vec2 TextureSize;
uniform float BRIGHT_BOOST, SCAN_STR, MASK_STR;

void main() {
    // 1. Quilez Scaling (سحب بكسلات دقيق جداً للمنظور المسطح)
    vec2 q_p = uv * TextureSize;
    vec2 q_i = floor(q_p) + 0.5;
    vec2 q_f = q_p - q_i;
    vec2 q_final = (q_i + 4.0 * q_f * q_f * q_f) / TextureSize;
    
    vec3 res = texture2D(Texture, q_final).rgb;

    // 2. Scanlines (مربوطة بـ uv مباشرة لضمان الثبات)
    float pixel_y = uv.y * TextureSize.y;
    float scan = sin(pixel_y * 6.283185) * 0.5 + 0.5;
    res *= mix(1.0, scan, SCAN_STR);

    // 3. Balanced RGB Mask
    vec3 mcol = vec3(0.0);
    mcol[int(mod(gl_FragCoord.x, 3.0))] = 1.0;
    res *= mix(vec3(1.0), mcol, MASK_STR);

    // 4. Final Output
    gl_FragColor = vec4(clamp(res * BRIGHT_BOOST, 0.0, 1.0), 1.0);
}
#endif