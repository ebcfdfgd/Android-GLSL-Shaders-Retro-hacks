#version 110

/* 777-LITE-TURBO-V4-FLAT-QUILEZ
    - FLAT: No distortion or vignette (Full-screen view).
    - QUILEZ: High-quality sub-pixel scaling retained.
    - FIXED: Scanlines locked to Game-Space (Perfect 1:1 scaling).
    - BRANCHLESS: Pure math logic for maximum speed.
*/

#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.17 1.0 2.0 0.01
#pragma parameter SCAN_STR "Scanline Intensity" 0.35 0.0 1.0 0.05
#pragma parameter SCAN_SIZE "Scanline Density" 1.0 0.5 2.0 0.05
#pragma parameter MASK_STR "Mask Strength" 0.15 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width" 3.0 1.0 10.0 1.0

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

#ifdef PARAMETER_UNIFORM
uniform float BRIGHT_BOOST, SCAN_STR, SCAN_SIZE, MASK_STR, MASK_W;
#endif

void main() {
    // [1] QUILEZ SCALING (تنعيم الصورة بدون انحناء)
    vec2 p_pix = uv * TextureSize;
    vec2 i = floor(p_pix);
    vec2 f = p_pix - i;
    f = f * f * (3.0 - 2.0 * f); 
    vec3 res = texture2D(Texture, (i + f + 0.5) / TextureSize).rgb;

    // [2] FIXED SCANLINES (ربط مباشر بالبكسلات الأصلية)
    // الحساب يتم مباشرة على محور Y الخاص بالصورة الأصلية
    float scan_pos = uv.y * TextureSize.y;
    float scanline = sin(scan_pos * 6.28318 * SCAN_SIZE) * 0.5 + 0.5;
    res = mix(res, res * scanline, SCAN_STR);

    // [3] اللمسات النهائية (السطوع والماسك)
    res *= BRIGHT_BOOST;

    float W = floor(MASK_W);
    float pos = mod(gl_FragCoord.x, W) / W;
    vec3 mcol = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), 0.6, 1.6);
    res = mix(res, res * mcol, MASK_STR);

    gl_FragColor = vec4(res, 1.0);
}
#endif