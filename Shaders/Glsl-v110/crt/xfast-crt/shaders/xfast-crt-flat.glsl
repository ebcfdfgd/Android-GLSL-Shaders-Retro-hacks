#version 110

/* 777-TURBO-ZFAST-QUILEZ-PURE-RGB + PAS700 MASK
    - INTEGRATED: Organic Quilez Scaling + ZFast Scanlines.
    - MASK: PAS700 Procedural Aperture Grille.
    - OPTIMIZED: Pure RGB Flat Projection (100% Branchless).
*/

#pragma parameter LOWLUMSCAN "Scanline Darkness - Low" 4.5 0.0 15.0 0.5
#pragma parameter BRIGHTBOOST "Brightness Boost" 1.25 0.5 2.0 0.05
#pragma parameter MASK_STR "Mask Intensity" 0.45 0.0 1.0 0.05
#pragma parameter MASK_W "PAS700 Mask Width" 6.0 1.0 16.0 1.0
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
uniform vec2 TextureSize;

uniform float LOWLUMSCAN, BRIGHTBOOST, MASK_STR, MASK_W, SCAN_FADE_POINT;

void main() {
    // 1. تطبيق خوارزمية Quilez Scaling للوضوح العضوي
    vec2 q_p = uv * TextureSize;
    vec2 q_i = floor(q_p) + 0.5;
    vec2 q_f = q_p - q_i;
    vec2 q_final = (q_i + 4.0 * q_f * q_f * q_f) / TextureSize;
    
    vec3 res = texture2D(Texture, q_final).rgb;

    // 2. سكان لاين Zfast
    float pos_y = uv.y * TextureSize.y;
    float dist = fract(pos_y) - 0.5;
    float Y = dist * dist;
    float YY = Y * Y;
    float scanWeightL = (BRIGHTBOOST - LOWLUMSCAN * (Y - 1.5 * YY));
    
    // 3. PAS700 Procedural RGB Mask
    float W = floor(MASK_W);
    float pos = mod(gl_FragCoord.x, W) / W;
    vec3 mcol = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), 0.0, 1.0);
    vec3 mask_rgb = mix(vec3(1.0), mcol, MASK_STR);

    // 4. الدمج الذكي (تلاشي السكان لاين)
    float luma = dot(res, vec3(0.299, 0.587, 0.114));
    float final_scan = mix(scanWeightL, 1.0, smoothstep(0.1, SCAN_FADE_POINT, luma));
    
    vec3 final_rgb = res * final_scan * mask_rgb;

    gl_FragColor = vec4(clamp(final_rgb, 0.0, 1.0), 1.0);
}
#endif