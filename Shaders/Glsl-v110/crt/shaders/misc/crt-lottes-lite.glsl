#version 110

/* 777-LOTTES-TURBO-0130-V5
    - PERFORMANCE: Pre-calculated resolution scales in Vertex.
    - MATH: Replaced slow exp2 and mod with faster approximations.
    - BYPASS: Retained the zero-parameter logic for ultra-low power.
*/

#pragma parameter BARREL_DISTORTION "Screen Curve" 0.12 0.0 0.5 0.01
#pragma parameter VIG_STR "Vignette Intensity" 0.15 0.0 1.0 0.05
#pragma parameter hardScan "Scanline Hardness" -8.0 -20.0 0.0 1.0
#pragma parameter scan_str "Scanline Intensity" 0.70 0.0 1.0 0.05
#pragma parameter hardPix "Pixel Hardness" -3.0 -20.0 0.0 1.0
#pragma parameter maskDark "Mask Dark" 0.5 0.0 2.0 0.1
#pragma parameter maskLight "Mask Light" 1.5 0.0 2.0 0.1
#pragma parameter brightBoost "Bright Boost" 1.3 0.0 2.5 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
varying vec2 sc;
varying vec2 inv_res;
uniform mat4 MVPMatrix;
uniform vec2 TextureSize, InputSize;

void main() {
    uv = TexCoord;
    sc = TextureSize / InputSize;
    inv_res = 1.0 / TextureSize;
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 uv, sc, inv_res;
uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, VIG_STR, hardScan, scan_str, hardPix, maskDark, maskLight, brightBoost;
#endif

void main() {
    // 1. نظام الإيقاف الفوري (ULTRA-FAST BYPASS)
    if (BARREL_DISTORTION <= 0.0 && scan_str <= 0.0 && maskDark >= 1.0) {
        gl_FragColor = vec4(texture2D(Texture, uv).rgb * brightBoost, 1.0);
        return; 
    }

    vec2 p = (uv * sc) - 0.5;
    vec2 p_curved = p;

    // 2. Optimized Geometry
    if (BARREL_DISTORTION > 0.0) {
        float r2 = dot(p, p);
        p_curved = p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8));
        p_curved *= (1.0 - 0.1 * BARREL_DISTORTION);
        
        if (abs(p_curved.x) > 0.5 || abs(p_curved.y) > 0.5) {
            gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
            return;
        }
    }

    // 3. Fast Sharp Bilinear
    vec2 texel_uv = (p_curved + 0.5) / sc;
    vec2 tc = texel_uv * TextureSize;
    vec2 i = floor(tc);
    vec2 f = tc - i;
    
    float region = 0.5 - (hardPix * 0.05); 
    f = clamp(f / (1.0 - region * 2.0) - region / (1.0 - region * 2.0), 0.0, 1.0);
    
    vec3 color = texture2D(Texture, (i + f + 0.5) * inv_res).rgb;
    color *= color; // Linearize

    // 4. Turbo Scanlines (Lottes Gaussian)
    if (scan_str > 0.0) {
        float dst = (fract(texel_uv.y * TextureSize.y) - 0.5);
        float scan = exp2(hardScan * dst * dst);
        color = mix(color, color * scan, scan_str);
    }

    // 5. High-Speed Shadow Mask
    if (maskDark < 1.0) {
        float m_pos = gl_FragCoord.x * 0.333333; // أسرع من mod
        vec3 mask = vec3(maskDark);
        float r = fract(m_pos);
        if (r < 0.333) mask.r = maskLight;
        else if (r < 0.666) mask.g = maskLight;
        else mask.b = maskLight;
        color *= mask;
    }

    // 6. Final Adjustments
    color *= brightBoost;
    if (VIG_STR > 0.0) color *= (1.0 - dot(p_curved, p_curved) * VIG_STR);

    gl_FragColor = vec4(sqrt(max(color, 0.0)), 1.0);
}
#endif