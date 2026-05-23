#version 110

/* ULTIMATE-CRT-CORE (Screen-Locked Mask)
    - INTEGRATED: Barrel Distortion (Curve 70).
    - LOGIC: Geometric distortion decoupled from Scanlines/Mask.
    - MASK: Screen-Locked via gl_FragCoord.x (Fixed grid for CRT realism).
*/

// --- CRT PARAMETERS ---
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 5.0 0.05
#pragma parameter OverlayMix "L1 Intensity (Scanlines)" 0.5 0.0 1.0 0.05
#pragma parameter SCAN_HARDNESS "Scanline Hardness" 8.0 2.0 20.0 0.5
#pragma parameter MASK_STRENGTH "Mask Strength" 0.5 0.0 1.0 0.05
#pragma parameter png_width "L2 Mask Width" 3.0 1.0 10.0 1.0
#pragma parameter BARREL_DISTORTION "Screen Curvature" 0.08 0.0 0.5 0.01

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
uniform vec2 TextureSize, InputSize;
uniform sampler2D Texture;
uniform float BRIGHT_BOOST, OverlayMix, SCAN_HARDNESS, MASK_STRENGTH, png_width, BARREL_DISTORTION;

float overlay_f(float a, float b) {
    return (a < 0.5) ? (2.0 * a * b) : (1.0 - 2.0 * (1.0 - a) * (1.0 - b));
}

void main() {
    // 1. BARREL DISTORTION (الهندسة)
    vec2 scale = TextureSize / InputSize;
    vec2 tex = TEX0 * scale;
    vec2 texcoord = tex - vec2(0.5);
    float rsq = dot(texcoord, texcoord);
    texcoord += texcoord * (BARREL_DISTORTION * rsq);
    texcoord *= (1.0 - (0.12 * BARREL_DISTORTION));

    if (abs(texcoord.x) > 0.5 || abs(texcoord.y) > 0.5) {
        gl_FragColor = vec4(0.0);
        return;
    }
    
    vec2 warped_uv = (texcoord + vec2(0.5)) / scale;
    vec3 gm = texture2D(Texture, warped_uv).rgb;

    // 2. SCANLINES (مربوطة بـ TEX0 لثبات المسافات)
    float dst = fract(TEX0.y * TextureSize.y) - 0.5;
    float scanline = exp2(-SCAN_HARDNESS * dst * dst); 
    vec3 ovl1 = vec3(overlay_f(gm.r, scanline), overlay_f(gm.g, scanline), overlay_f(gm.b, scanline));
    gm = mix(gm, clamp(ovl1, 0.0, 1.0), OverlayMix);

    // 3. RGB MASK (Screen-Locked: الآن يتبع الشاشة)
    // استخدام gl_FragCoord يجعله طبقة ثابتة (Static Overlay) فوق الصورة المشوهة
    float W = floor(png_width);
    float pos = mod(gl_FragCoord.x, W) / W;
    vec3 mcol = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), 0.0, 1.0);
    gm *= mix(vec3(1.0), mcol, MASK_STRENGTH);

    // 4. Output
    gl_FragColor = vec4(clamp(gm * BRIGHT_BOOST, 0.0, 1.0), 1.0);
}
#endif