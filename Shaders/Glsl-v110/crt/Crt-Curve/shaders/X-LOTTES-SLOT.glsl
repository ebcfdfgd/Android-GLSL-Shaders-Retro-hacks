// --- Parameters ---
#pragma parameter BARREL_DISTORTION "Screen Curve" 0.15 0.0 1.0 0.02
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.17 1.0 2.0 0.01
#pragma parameter VIG_STR "Vignette Intensity" 0.15 0.0 2.0 0.05
#pragma parameter hardScan "Lottes Scan Hardness" -8.0 -20.0 0.0 1.0
#pragma parameter SCAN_STR "Scanline Strength" 0.50 0.0 1.0 0.05
#pragma parameter maskDark "LOTTES MASK DARK" 0.5 0.0 2.0 0.05
#pragma parameter maskLight "LOTTES MASK LIGHT" 1.5 0.0 2.0 0.05

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
uniform float BARREL_DISTORTION, BRIGHT_BOOST, VIG_STR, hardScan, SCAN_STR, maskDark, maskLight;
#endif

// دالة حساب الـ Slot Mask (يعمل دائماً)
vec3 Mask(vec2 pos) {
    float line = maskLight;
    // حساب التداخل (Odd/Even rows)
    float odd = step(0.5, fract(pos.x * 0.166666666));
    float line_dark = step(0.5, fract((pos.y + odd) * 0.5));
    line = mix(maskLight, maskDark, line_dark);
    
    float x1 = fract(pos.x * 0.333333333);
    vec3 m1 = vec3(maskDark);
    m1.b = mix(m1.b, maskLight, step(0.0, x1) * (1.0 - step(0.333, x1)));
    m1.g = mix(m1.g, maskLight, step(0.333, x1) * (1.0 - step(0.666, x1)));
    m1.r = mix(m1.r, maskLight, step(0.666, x1));
    
    // دمج الإضاءة مع الشبكة
    return m1 * line;
}

void main() {
    // [1] حساب الإحداثيات والإنحناء
    vec2 p = (uv * screen_scale) - 0.5;
    float r2 = dot(p, p);
    
    vec2 p_distorted = p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8));
    p_distorted *= (1.0 - 0.1 * BARREL_DISTORTION);
    vec2 p_curved = mix(p, p_distorted, step(0.001, BARREL_DISTORTION));

    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float check = bounds.x * bounds.y;

    // [2] TEXTURE SAMPLING (سحب مباشر للصورة بدون Quilez)
    vec2 tex_uv = (p_curved + 0.5) / screen_scale;
    vec3 res = texture2D(Texture, tex_uv).rgb;

    // [3] SCANLINES
    // ملاحظة: نستخدم UV الأصلية لحساب الخطوط لمنع التشويه في الـ Scanlines
    float dst = fract(tex_uv.y * TextureSize.y) - 0.5;
    float scan = exp2(hardScan * dst * dst);
    res = mix(res, res * scan, SCAN_STR);

    // [4] MASK (مفعل دائماً)
    res *= Mask(gl_FragCoord.xy);

    // [5] FINAL POLISH
    res *= BRIGHT_BOOST;
    
    res *= mix(1.0, (1.0 - r2 * VIG_STR), step(0.001, VIG_STR));

    gl_FragColor = vec4(res * check, 1.0);
}
#endif