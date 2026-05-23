#version 110

/* LIGHT-ULTIMATE-SCANLINE-MOD (Screen-Locked Mask)
    - INTEGRATED: Barrel Distortion (Curve 70 Logic).
    - SYNCED: Scanlines synced to TEX0 (Fixed grid).
    - FIXED: Mask synced to gl_FragCoord (Screen-Locked).
    - PERFORMANCE: Optimized math (dot product).
*/

// --- PARAMETERS ---
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 5.0 0.05
#pragma parameter hardScan "Lottes Scan Hardness" -8.0 -20.0 0.0 1.0
#pragma parameter SCAN_STR "Scanline Intensity" 0.40 0.0 1.0 0.05
#pragma parameter MASK_STRENGTH "Mask Strength" 0.5 0.0 1.0 0.05
#pragma parameter LUTWidth2 "L2 Width" 6.0 1.0 1024.0 1.0
#pragma parameter LUTHeight2 "L2 Height" 4.0 1.0 1024.0 1.0
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
uniform sampler2D Texture, overlay2;
uniform float BRIGHT_BOOST, hardScan, SCAN_STR, MASK_STRENGTH, LUTWidth2, LUTHeight2, BARREL_DISTORTION;

float overlay_f(float a, float b) {
    return (a < 0.5) ? (2.0 * a * b) : (1.0 - 2.0 * (1.0 - a) * (1.0 - b));
}

void main() {
    // 1. BARREL DISTORTION
    vec2 scale = TextureSize / InputSize;
    vec2 texcoord = (TEX0 * scale) - vec2(0.5);
    
    float rsq = dot(texcoord, texcoord);
    texcoord += texcoord * (BARREL_DISTORTION * rsq);
    texcoord *= (1.0 - (0.12 * BARREL_DISTORTION));

    if (abs(texcoord.x) > 0.5 || abs(texcoord.y) > 0.5) {
        gl_FragColor = vec4(0.0);
        return;
    }
    
    vec2 warped_uv = (texcoord + vec2(0.5)) / scale;
    vec3 gm = texture2D(Texture, warped_uv).rgb;

    // 2. SCANLINES (Synced to TEX0)
    float dst = fract(TEX0.y * TextureSize.y) - 0.5;
    float scanline = exp2(hardScan * dst * dst);
    
    vec3 scan_col = vec3(
        overlay_f(gm.r, scanline), 
        overlay_f(gm.g, scanline), 
        overlay_f(gm.b, scanline)
    );
    gm = mix(gm, clamp(scan_col, 0.0, 1.0), SCAN_STR);

    // 3. MASK (SCREEN-LOCKED via gl_FragCoord)
    // الماسك الآن ثابت تماماً بالنسبة للشاشة ولا يتبع انحناء الصورة
    vec2 maskUV2 = gl_FragCoord.xy / vec2(LUTWidth2, LUTHeight2);
    vec3 m2 = texture2D(overlay2, maskUV2).rgb;
    gm *= mix(vec3(1.0), m2, MASK_STRENGTH);

    // 4. Final Output
    gl_FragColor = vec4(clamp(gm * BRIGHT_BOOST, 0.0, 1.0), 1.0);
}
#endif