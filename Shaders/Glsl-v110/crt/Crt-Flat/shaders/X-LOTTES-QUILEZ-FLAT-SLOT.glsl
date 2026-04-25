// --- Parameters ---
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.17 1.0 2.0 0.01
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
uniform float BRIGHT_BOOST, hardScan, SCAN_STR, maskDark, maskLight;
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
    // [1] الإحداثيات (تم إزالة الكيرف)
    vec2 tex_uv = uv;

    // [2] QUILEZ SCALING
    vec2 p_pix = tex_uv * TextureSize;
    vec2 i = floor(p_pix);
    vec2 f = p_pix - i;
    f = f * f * (3.0 - 2.0 * f); 
    vec3 res = texture2D(Texture, (i + f + 0.5) / TextureSize).rgb;

    // [3] SCANLINES
    float dst = fract(tex_uv.y * TextureSize.y) - 0.5;
    float scan = exp2(hardScan * dst * dst);
    res = mix(res, res * scan, SCAN_STR);

    // [4] MASK (مفعل دائماً)
    res *= Mask(gl_FragCoord.xy);

    // [5] FINAL POLISH
    res *= BRIGHT_BOOST;

    gl_FragColor = vec4(res, 1.0);
}
#endif