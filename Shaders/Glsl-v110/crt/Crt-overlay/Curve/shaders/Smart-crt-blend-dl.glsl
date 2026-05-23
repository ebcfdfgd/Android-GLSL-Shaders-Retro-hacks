#version 110

/* ULTIMATE-CRT-CORE-ADAPTIVE (Screen-Locked Mask Revision)
    - OPTIMIZED: Scanlines synced to uv (Static grid).
    - MASK: Screen-Locked via gl_FragCoord (Static Overlay).
    - PERFORMANCE: Vectorized math & zero-lag curvature.
*/

// --- CRT PARAMETERS ---
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.20 1.0 2.0 0.01
#pragma parameter BARREL_DISTORTION "Screen Curve" 0.08 0.0 0.5 0.01
#pragma parameter hardScan "Lottes Scan Hardness" -8.0 -20.0 0.0 1.0
#pragma parameter SCAN_STR "Scanline Intensity" 0.40 0.0 1.0 0.05
#pragma parameter SCAN_THRESH "Scanline Bloom Threshold" 0.8 0.5 1.0 0.05
#pragma parameter MASK_LIGHT "Mask Light Strength" 1.5 1.0 2.0 0.05
#pragma parameter MASK_DARK "Mask Dark Strength" 0.5 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width (3=RGB)" 3.0 1.0 6.0 1.0

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    uv = TexCoord;
}

#elif defined(FRAGMENT)
precision highp float;
varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform vec2 InputSize;
uniform float BRIGHT_BOOST, hardScan, SCAN_STR, SCAN_THRESH, MASK_LIGHT, MASK_DARK, MASK_W, BARREL_DISTORTION;

float smart_overlay(float a, float b, float thresh) {
    return (a < thresh) ? ((1.0 / thresh) * a * b) : (1.0 - (1.0 / (1.0 - thresh)) * (1.0 - a) * (1.0 - b));
}

void main() {
    // 1. BARREL DISTORTION (الهندسة فقط)
    vec2 scale = TextureSize / InputSize;
    vec2 texcoord = (uv * scale) - vec2(0.5);
    
    float rsq = dot(texcoord, texcoord); 
    texcoord += texcoord * (BARREL_DISTORTION * rsq);
    texcoord *= (1.0 - (0.12 * BARREL_DISTORTION));

    if (abs(texcoord.x) > 0.5 || abs(texcoord.y) > 0.5) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }
    
    vec2 warped_uv = (texcoord + vec2(0.5)) / scale;
    vec3 res = texture2D(Texture, warped_uv).rgb;

    // 2. SMART LOTTES SCANLINES (ثابتة على شبكة الشاشة)
    float dst = fract(uv.y * TextureSize.y) - 0.5;
    float scanline = exp2(hardScan * dst * dst);
    
    vec3 smart_res = vec3(
        smart_overlay(res.r, scanline, SCAN_THRESH),
        smart_overlay(res.g, scanline, SCAN_THRESH),
        smart_overlay(res.b, scanline, SCAN_THRESH)
    );
    res = mix(res, clamp(smart_res, 0.0, 1.0), SCAN_STR);

    // 3. RGB MASK (SCREEN-LOCKED: ثابت على الشاشة)
    // الآن الماسك يعتمد على gl_FragCoord.x ليظل ثابتاً فوق نافذة العرض
    float W = floor(MASK_W);
    float pos = mod(gl_FragCoord.x, W) / W;
    vec3 mcol = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), MASK_DARK, MASK_LIGHT);
    res *= mcol;

    // 4. Final Polish
    gl_FragColor = vec4(clamp(res * BRIGHT_BOOST, 0.0, 1.0), 1.0);
}
#endif