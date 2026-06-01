#version 110

/* LIGHT-ULTIMATE-SCANLINE-MOD (Screen-Locked Mask Revision)
   - PHILOSOPHY: Geometry is independent of Surface.
   - OPTIMIZATION: Zero-aliasing grid sampling.
   - MASK: Now screen-locked via gl_FragCoord.
*/

#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 5.0 0.05
#pragma parameter hardScan "Lottes Scan Hardness" -8.0 -20.0 0.0 1.0
#pragma parameter SCAN_STR "Scanline Intensity" 0.40 0.0 1.0 0.05
#pragma parameter SCAN_THRESH "Scanline Bloom Threshold" 0.8 0.5 1.0 0.05
#pragma parameter MASK_STRENGTH "Mask Strength" 0.5 0.0 1.0 0.05
#pragma parameter LUTWidth2 "L2 Width" 6.0 1.0 1024.0 1.0
#pragma parameter LUTHeight2 "L2 Height" 2.0 1.0 1024.0 1.0
#pragma parameter BARREL_DISTORTION "Screen Curve" 0.08 0.0 0.5 0.01

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec4 TexCoord;
varying vec2 TEX0;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    TEX0 = TexCoord.xy;
}

#elif defined(FRAGMENT)
precision highp float;
varying vec2 TEX0;
uniform vec2 OutputSize, TextureSize, InputSize;

// تعريف التكتشر بشكل صحيح
uniform sampler2D Texture;
uniform sampler2D overlay2; 

uniform float BRIGHT_BOOST, hardScan, SCAN_STR, SCAN_THRESH, MASK_STRENGTH, LUTWidth2, LUTHeight2, BARREL_DISTORTION;

float smart_overlay(float color, float scan, float thresh) {
    return (color < thresh) ? 
           ((1.0 / thresh) * color * scan) : 
           (1.0 - (1.0 / (1.0 - thresh)) * (1.0 - color) * (1.0 - scan));
}

void main() {
    // 1. الهندسة (Warping)
    vec2 scale = TextureSize / InputSize;
    vec2 texcoord = (TEX0 * scale) - vec2(0.5);
    float rsq = dot(texcoord, texcoord);
    texcoord += texcoord * (BARREL_DISTORTION * rsq);
    texcoord *= (1.0 - (0.12 * BARREL_DISTORTION));

    if (abs(texcoord.x) > 0.5 || abs(texcoord.y) > 0.5) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }
    
    vec2 warped_uv = (texcoord + vec2(0.5)) / scale;

    // 2. سحب اللون
    vec3 gm = texture2D(Texture, warped_uv).rgb;

    // 3. السكان لاين
    float dst = fract(TEX0.y * TextureSize.y) - 0.5;
    float scanline = exp2(hardScan * dst * dst);
    
    gm = mix(gm, clamp(vec3(
        smart_overlay(gm.r, scanline, SCAN_THRESH),
        smart_overlay(gm.g, scanline, SCAN_THRESH),
        smart_overlay(gm.b, scanline, SCAN_THRESH)
    ), 0.0, 1.0), SCAN_STR);

    // 4. الماسك: استخدام التكرار لضمان التوافق مع حجم التكتشر
    vec2 mask_res = vec2(LUTWidth2, LUTHeight2);
    vec2 maskUV2 = mod(gl_FragCoord.xy, mask_res) / mask_res;
    vec3 m2 = texture2D(overlay2, maskUV2).rgb;
    gm *= mix(vec3(1.0), m2, MASK_STRENGTH);

    // 5. الإخراج النهائي
    gl_FragColor = vec4(clamp(gm * BRIGHT_BOOST, 0.0, 1.0), 1.0);
}
#endif