#version 110

/* 777-LITE-TURBO-V4-QUILEZ-FLAT-LOTTES
    - INTEGRATED: Quilez Scaling for perfect pixel reconstruction.
    - SCANLINES: Lottes Scanline model (Flat Projection).
    - OPTIMIZED: 100% Branchless (No 'if' conditions).
*/

#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.20 1.0 2.0 0.01
#pragma parameter hardScan "Lottes Scan Hardness" -8.0 -20.0 0.0 1.0
#pragma parameter SCAN_STR "Scanline Intensity" 0.40 0.0 1.0 0.05
#pragma parameter MASK_STR "Mask Strength" 0.20 0.0 1.0 0.05

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
uniform float BRIGHT_BOOST, hardScan, SCAN_STR, MASK_STR;

void main() {
    // 1. Quilez Scaling (سحب بكسلات دقيق جداً للمنظور المسطح)
    vec2 q_p = uv * TextureSize;
    vec2 q_i = floor(q_p) + 0.5;
    vec2 q_f = q_p - q_i;
    vec2 q_final = (q_i + 4.0 * q_f * q_f * q_f) / TextureSize;
    
    vec3 res = texture2D(Texture, q_final).rgb;

    // 2. Lottes Scanlines
    float dst = fract(uv.y * TextureSize.y) - 0.5;
    float scanline = exp2(hardScan * dst * dst);
    res = mix(res, res * scanline, SCAN_STR);

    // 3. RGB Mask
    vec3 mcol = vec3(0.0);
    mcol[int(mod(gl_FragCoord.x, 3.0))] = 1.0;
    res *= mix(vec3(1.0), mcol, MASK_STR);

    // 4. Final Polish
    res *= BRIGHT_BOOST;

    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif