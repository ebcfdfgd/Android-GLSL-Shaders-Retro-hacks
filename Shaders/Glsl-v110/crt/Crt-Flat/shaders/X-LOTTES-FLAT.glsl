#version 110

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

// دالة حساب الماسك (بدون تفرعات)
vec3 Mask(vec2 pos) {
    float x = fract(pos.x * 0.333333333);
    vec3 mask = vec3(maskDark);
    
    // استبدال الـ if بـ step و mix
    mask.b = mix(maskDark, maskLight, step(x, 0.333));
    mask.g = mix(maskDark, maskLight, step(0.333, x) * step(x, 0.666));
    mask.r = mix(maskDark, maskLight, step(0.666, x));
    
    return mask;
}

void main() {
    // [1] الإحداثيات الأساسية
    vec2 tex_uv = uv;
    vec3 res = texture2D(Texture, tex_uv).rgb;

    // [2] SCANLINES
    // حساب الإحداثيات بالنسبة لحجم النسيج الأصلي لضبط خطوط المسح
    float dst = fract(tex_uv.y * TextureSize.y) - 0.5;
    float scan = exp2(hardScan * dst * dst);
    res = mix(res, res * scan, SCAN_STR);

    // [3] MASK 
    res *= mix(vec3(1.0), Mask(gl_FragCoord.xy), step(0.001, maskDark));

    // [4] FINAL POLISH
    res *= BRIGHT_BOOST;

    gl_FragColor = vec4(res, 1.0);
}
#endif