#version 110

/* ULTIMATE-TURBO-HYBRID-V6-SUPERSONIC
    - ZERO-BRANCHING: Replaced all IF/Return with Step/Mix/Check math.
    - HARDWARE-FETCH: Removed Quilez for 1:1 hardware texture speed.
    - OMNI-SPEED: Speed-matched with LCD-Grid for low-end mobile GPUs.
*/

#pragma parameter BARREL_DISTORTION "Toshiba Curve (0=OFF)" 0.12 0.0 0.5 0.01
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 2.5 0.05
#pragma parameter v_amount "Vignette Intensity (0=OFF)" 0.25 0.0 2.5 0.01
#pragma parameter MASK_TYPE "Mask: 0:RGB, 1:PNG" 0.0 0.0 1.0 1.0
#pragma parameter MASK_STR "Mask Intensity (0=OFF)" 0.45 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width" 3.0 1.0 15.0 1.0
#pragma parameter MASK_H "Mask Height" 3.0 1.0 15.0 1.0
#pragma parameter SCAN_STR "Scanline Intensity (0=OFF)" 0.40 0.0 1.0 0.05
#pragma parameter SCAN_DENS "Scanline Density" 1.0 0.2 10.0 0.1

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 TEX0, screen_scale;
uniform mat4 MVPMatrix;
uniform vec2 TextureSize, InputSize;

void main() {
    TEX0 = TexCoord;
    screen_scale = TextureSize / InputSize;
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 TEX0, screen_scale;
uniform sampler2D Texture, SamplerMask1;
uniform vec2 TextureSize, InputSize;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, BRIGHT_BOOST, v_amount, MASK_TYPE, MASK_STR, MASK_W, MASK_H, SCAN_STR, SCAN_DENS;
#endif

void main() {
    // 1. إحداثيات مركزية وحساب r2 (نستخدمه للكيرف والفنيت والحدود)
    vec2 uv = (TEX0 * screen_scale) - 0.5;
    float r2 = dot(uv, uv);

    // 2. انحناء الشاشة الرياضي (Branchless)
    vec2 d_uv = uv * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8)) * (1.0 - 0.12 * BARREL_DISTORTION);

    // 3. حدود الشاشة (Clipping) رياضياً بدلاً من IF
    vec2 bounds = step(abs(d_uv), vec2(0.5));
    float check = bounds.x * bounds.y;

    // 4. سحب اللون بالهاردوير مباشرة (أقصى سرعة ممكنة - وداعاً Quilez)
    vec2 tex_uv = (d_uv + 0.5) / screen_scale;
    vec3 res = texture2D(Texture, tex_uv).rgb;

    // 5. سكان لاينز اقتصادية (Direct Sin)
    float scanline = sin(tex_uv.y * InputSize.y * (6.28318 * SCAN_DENS)) * 0.5 + 0.5;
    res = mix(res, res * scanline, SCAN_STR);

    // 6. نظام الماسك الموحد (Branchless Mask Logic)
    float mw = floor(max(MASK_W, 1.0));
    float mh = floor(max(MASK_H, 1.0));
    float pos = mod(gl_FragCoord.x, mw);
    
    // حساب RGB Mask بطريقة الـ Vector (بدون IF)
    vec3 mcol_rgb = mix(
        vec3(clamp(abs((pos/mw)*6.0-3.0)-1.0, 0.0, 1.0), clamp(2.0-abs((pos/mw)*6.0-2.0), 0.0, 1.0), clamp(2.0-abs((pos/mw)*6.0-4.0), 0.0, 1.0)) * 1.6,
        (pos < 1.0) ? vec3(1.4, 0.6, 0.6) : (pos < 2.0) ? vec3(0.6, 1.4, 0.6) : vec3(0.6, 0.6, 1.4),
        step(mw, 3.5)
    );

    // دمج نوع الماسك (RGB أو PNG) رياضياً
    vec3 mcol = mix(mcol_rgb, texture2D(SamplerMask1, gl_FragCoord.xy / vec2(mw, mh)).rgb * 1.5, step(0.5, MASK_TYPE));
    res = mix(res, res * mcol, MASK_STR);

    // 7. اللمسات النهائية (السطوع + الفنيت + تطبيق الحدود)
    res *= BRIGHT_BOOST;
    res *= (1.0 - r2 * v_amount);
    
    gl_FragColor = vec4(res * check, 1.0);
}
#endif