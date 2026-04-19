#version 110

/* 777-LITE-TURBO-V4-HYBRID-STABLE-FIXED
    - FIXED: Scanlines locked to Game-Space (No more giant lines).
    - QUILEZ RETAINED: For high-quality sub-pixel scaling.
    - BRANCHLESS: Pure math for maximum mobile performance.
*/

#pragma parameter BARREL_DISTORTION "Screen Curve" 0.15 0.0 1.0 0.02
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.17 1.0 2.0 0.01
#pragma parameter VIG_STR "Vignette Intensity" 0.15 0.0 2.0 0.05
#pragma parameter SCAN_STR "Scanline Intensity" 0.35 0.0 1.0 0.05
#pragma parameter SCAN_SIZE "Scanline Density" 1.0 0.5 2.0 0.05
#pragma parameter MASK_STR "Mask Strength" 0.15 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width" 3.0 1.0 10.0 1.0

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv, screen_scale; 
uniform mat4 MVPMatrix;
uniform vec2 TextureSize, InputSize;

void main() {
    uv = TexCoord;
    screen_scale = TextureSize / InputSize; 
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 uv, screen_scale;
uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, BRIGHT_BOOST, VIG_STR, SCAN_STR, SCAN_SIZE, MASK_STR, MASK_W;
#endif

void main() {
    // [1] حساب الإحداثيات المركزية
    vec2 p = (uv * screen_scale) - 0.5;
    float r2 = dot(p, p);

    // [2] انحناء الشاشة (Branchless)
    vec2 p_curved = p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8));
    p_curved *= (1.0 - 0.1 * BARREL_DISTORTION);

    // حدود الشاشة رياضياً
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float check = bounds.x * bounds.y;

    // [3] QUILEZ SCALING (لجودة الصورة ومنع الـ Moire)
    vec2 tex_uv = (p_curved + 0.5) / screen_scale;
    vec2 p_pix = tex_uv * TextureSize;
    vec2 i = floor(p_pix);
    vec2 f = p_pix - i;
    f = f * f * (3.0 - 2.0 * f); 
    vec3 res = texture2D(Texture, (i + f + 0.5) / TextureSize).rgb;

    // [4] FIXED SCANLINES (إصلاح السكان لاين فقط)
    // نربط الحساب بـ p_curved.y لضمان التوافق 1:1 مع بكسلات اللعبة
    float scan_pos = (p_curved.y + 0.5) * InputSize.y;
    float scanline = sin(scan_pos * 6.28318 * SCAN_SIZE) * 0.5 + 0.5;
    res = mix(res, res * scanline, SCAN_STR);

    // [5] اللمسات النهائية (السطوع، الفنيت، الماسك)
    res *= BRIGHT_BOOST;
    res *= (1.0 - r2 * VIG_STR);

    float W = floor(MASK_W);
    float pos = mod(gl_FragCoord.x, W) / W;
    vec3 mcol = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), 0.6, 1.6);
    res = mix(res, res * mcol, MASK_STR);

    gl_FragColor = vec4(res * check, 1.0);
}
#endif