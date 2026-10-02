#version 110

/* ULTIMATE-TURBO-HYBRID (V21-QUILEZ-EDITION) */

#pragma parameter BARREL_DISTORTION "Screen Curve" 0.08 0.0 0.5 0.01
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.25 0.5 2.0 0.05
#pragma parameter MASK_STR "Mask Intensity" 0.45 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width" 6.0 1.0 64.0 1.0
#pragma parameter MASK_H "Mask Height" 2.0 1.0 64.0 1.0
#pragma parameter LOWLUMSCAN "Scanline Darkness" 4.5 0.0 15.0 0.5
#pragma parameter SCAN_FADE_POINT "Scanline Fade Cutoff" 0.85 0.5 1.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 TEX0;
uniform mat4 MVPMatrix;

void main() {
    TEX0 = TexCoord;
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 TEX0;
uniform sampler2D Texture, SamplerMask1;
uniform vec2 TextureSize, InputSize;
uniform float BARREL_DISTORTION, BRIGHT_BOOST, MASK_STR, MASK_W, MASK_H, LOWLUMSCAN, SCAN_FADE_POINT;

void main() {
    // 1. Geometry (Barrel Distortion)
    vec2 scale = TextureSize / InputSize;
    vec2 tex = TEX0 * scale;
    vec2 texcoord = tex - vec2(0.5);
    
    float rsq = dot(texcoord, texcoord);
    texcoord += texcoord * (BARREL_DISTORTION * rsq);
    texcoord *= (1.0 - (0.12 * BARREL_DISTORTION));

    vec2 bounds = step(abs(texcoord), vec2(0.5));
    float edge_mask = bounds.x * bounds.y;
    vec2 final_uv = (texcoord + vec2(0.5)) / scale;

    // 2. Quilez Scaling (التكبير العضوي فائق النقاء)
    vec2 q_p = final_uv * TextureSize;
    vec2 q_i = floor(q_p) + 0.5;
    vec2 q_f = q_p - q_i;
    vec2 q_final = (q_i + 4.0 * q_f * q_f * q_f) / TextureSize;
    
    vec3 res = texture2D(Texture, q_final).rgb;

    // 3. Zfast Pixel-Sync Scanlines
    float pos_y = final_uv.y * TextureSize.y;
    float dist = fract(pos_y) - 0.5;
    float Y = dist * dist;
    float YY = Y * Y;

    float scanWeightL = (BRIGHT_BOOST - LOWLUMSCAN * (Y - 1.5 * YY));
    float luma = dot(res, vec3(0.299, 0.587, 0.114));
    float final_scan = mix(scanWeightL, 1.0, smoothstep(0.1, SCAN_FADE_POINT, luma));
    res *= final_scan;

    // 4. Sharp PNG Mask
    vec2 mask_size = vec2(floor(MASK_W), floor(MASK_H));
    vec2 m_uv = (mod(floor(gl_FragCoord.xy), mask_size) + 0.5) / mask_size;
    vec3 mcol = texture2D(SamplerMask1, m_uv).rgb * 1.5;
    res = mix(res, res * mcol, MASK_STR);

    gl_FragColor = vec4(res * BRIGHT_BOOST * edge_mask, 1.0);
}
#endif