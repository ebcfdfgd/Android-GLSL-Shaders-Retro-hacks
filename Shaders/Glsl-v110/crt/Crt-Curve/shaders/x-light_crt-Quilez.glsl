/* 777-LITE-TURBO-V4-HYBRID-STABLE-FIXED-BLOOM
    - FIXED: Scanlines locked to Game-Space.
    - QUILEZ RETAINED: For high-quality sub-pixel scaling.
    - ADDED: Single-Pass Luma-Bloom.
*/

#pragma parameter BARREL_DISTORTION "Screen Curve" 0.15 0.0 1.0 0.02
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.17 1.0 2.0 0.01
#pragma parameter VIG_STR "Vignette Intensity" 0.15 0.0 2.0 0.05
#pragma parameter SCAN_STR "Scanline Intensity" 0.35 0.0 1.0 0.05
#pragma parameter SCAN_SIZE "Scanline Density" 1.0 0.5 2.0 0.05
#pragma parameter MASK_STR "Mask Strength" 0.15 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width" 3.0 1.0 10.0 1.0
#pragma parameter BLOOM_INT "Bloom Intensity" 0.3 0.0 1.0 0.05
#pragma parameter BLOOM_TH "Bloom Threshold" 0.7 0.0 1.0 0.05

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
uniform float BARREL_DISTORTION, BRIGHT_BOOST, VIG_STR, SCAN_STR, SCAN_SIZE, MASK_STR, MASK_W, BLOOM_INT, BLOOM_TH;
#endif

void main() {
    // [1] حساب الإحداثيات والإنحناء
    vec2 p = (uv * screen_scale) - 0.5;
    float r2 = dot(p, p);
    vec2 p_curved = p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8));
    p_curved *= (1.0 - 0.1 * BARREL_DISTORTION);

    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float check = bounds.x * bounds.y;

    // [2] QUILEZ SCALING
    vec2 tex_uv = (p_curved + 0.5) / screen_scale;
    vec2 p_pix = tex_uv * TextureSize;
    vec2 i = floor(p_pix);
    vec2 f = p_pix - i;
    f = f * f * (3.0 - 2.0 * f); 
    vec3 res = texture2D(Texture, (i + f + 0.5) / TextureSize).rgb;

    // [3] SCANLINES (Locked)
    float scan_pos = (p_curved.y + 0.5) * InputSize.y;
    float scanline = sin(scan_pos * 6.28318 * SCAN_SIZE) * 0.5 + 0.5;
    res = mix(res, res * scanline, SCAN_STR);

    // [4] RGB MASK
    float W = floor(MASK_W);
    float pos = mod(gl_FragCoord.x, W) / W;
    vec3 mcol = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), 0.6, 1.6);
    res = mix(res, res * mcol, MASK_STR);

    // [5] BLOOM (Luma Threshold)
    // بنحسب الإضاءة وبنعمل Bloom للمناطق اللي معدية الـ Threshold فقط
    float luma = dot(res, vec3(0.299, 0.587, 0.114));
    float bloom_mask = max(0.0, luma - BLOOM_TH);
    res += res * bloom_mask * BLOOM_INT;

    // [6] FINAL POLISH
    res *= BRIGHT_BOOST;
    res *= (1.0 - r2 * VIG_STR);

    gl_FragColor = vec4(res * check, 1.0);
}
#endif