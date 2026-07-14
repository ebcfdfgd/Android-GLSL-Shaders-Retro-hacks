#version 110

/* 777-TURBO-ZFAST-QUILEZ-EDITION */

#pragma parameter BARREL_DISTORTION "Curve 0 Strength" 0.15 0.0 1.0 0.02
#pragma parameter LOWLUMSCAN "Scanline Darkness - Low" 4.5 0.0 15.0 0.5
#pragma parameter BRIGHTBOOST "Brightness Boost" 1.25 0.5 2.0 0.05
#pragma parameter MASK_STR "Mask Intensity" 0.45 0.0 1.0 0.05
#pragma parameter SCAN_FADE_POINT "Scanline Fade Cutoff" 0.85 0.5 1.0 0.05

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
uniform float BARREL_DISTORTION, LOWLUMSCAN, BRIGHTBOOST, MASK_STR, SCAN_FADE_POINT;

void main() {
    // 1. إحداثيات الكيرف
    vec2 sc = TextureSize / InputSize;
    vec2 p = (uv * sc) - 0.5;
    float r2 = dot(p, p);
    vec2 p_curved = p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8));

    // فحص الحدود (Branchless)
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float check = bounds.x * bounds.y;
    
    // 2. تطبيق خوارزمية Quilez Scaling
    vec2 texCoord = (p_curved + 0.5) / sc;
    vec2 q_p = texCoord * TextureSize;
    vec2 q_i = floor(q_p) + 0.5;
    vec2 q_f = q_p - q_i;
    vec2 q_final = (q_i + 4.0 * q_f * q_f * q_f) / TextureSize;
    
    vec3 res = texture2D(Texture, q_final).rgb;
    res *= check;

    // 3. سكان لاين Zfast
    float pos_y = texCoord.y * TextureSize.y;
    float dist = fract(pos_y) - 0.5;
    float Y = dist * dist;
    float scanWeightL = (BRIGHTBOOST - LOWLUMSCAN * (Y - 1.5 * Y * Y));
    
    // 4. ماسك RGB ثابت
    vec3 mcol = vec3(0.0);
    mcol[int(mod(gl_FragCoord.x, 3.0))] = 1.0;
    vec3 mask_rgb = mix(vec3(1.0), mcol * 1.5, MASK_STR);

    // 5. الدمج النهائي
    float luma = dot(res, vec3(0.299, 0.587, 0.114));
    float final_scan = mix(scanWeightL, 1.0, smoothstep(0.1, SCAN_FADE_POINT, luma));
    vec3 final_rgb = res * final_scan * mask_rgb;

    gl_FragColor = vec4(clamp(final_rgb, 0.0, 1.0), 1.0);
}
#endif