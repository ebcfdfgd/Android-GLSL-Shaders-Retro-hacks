#version 110

/* 777-LOTTES-ULTRA-TURBO-V5.5
    - PERFORMANCE: Flattened Grid-Mask logic (No heavy if/else).
    - OPTIMIZATION: Moved pre-calculations to Vertex.
    - SPEED: Combined BrightBoost and SRGB conversion.
*/

#pragma parameter BARREL_DISTORTION "Screen Curve" 0.12 0.0 0.5 0.01
#pragma parameter VIG_STR "Vignette Intensity" 0.15 0.0 1.0 0.05
#pragma parameter hardScan "Scanline Hardness" -8.0 -20.0 0.0 1.0
#pragma parameter scan_str "Scanline Intensity" 0.70 0.0 1.0 0.05
#pragma parameter hardPix "Pixel Hardness" -3.0 -20.0 0.0 1.0
#pragma parameter maskDark "Mask Dark" 0.5 0.0 2.0 0.1
#pragma parameter maskLight "Mask Light" 1.5 0.0 2.0 0.1
#pragma parameter shadowMask "Mask Type: 0:Sony, 1:Retro-Grid" 0.0 0.0 1.0 1.0
#pragma parameter brightBoost "Bright Boost" 1.25 0.0 2.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv_orig;
varying vec2 sc;
varying vec2 inv_res;
uniform mat4 MVPMatrix;
uniform vec2 TextureSize, InputSize;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    uv_orig = TexCoord;
    sc = TextureSize / InputSize;
    inv_res = 1.0 / TextureSize;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 uv_orig, sc, inv_res;
uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, VIG_STR, hardScan, scan_str, hardPix, maskDark, maskLight, shadowMask, brightBoost;
#endif

void main() {
    // 1. نظام الإيقاف الفوري الصارم
    if (BARREL_DISTORTION <= 0.0 && scan_str <= 0.0 && maskDark >= 1.0 && maskLight <= 1.0) {
        gl_FragColor = vec4(texture2D(Texture, uv_orig).rgb * brightBoost, 1.0);
        return;
    }

    vec2 p = (uv_orig * sc) - 0.5;
    vec2 p_curved = p;

    // 2. Optimized Geometry
    if (BARREL_DISTORTION > 0.0) {
        float r2 = dot(p, p);
        p_curved = p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8));
        p_curved *= (1.0 - 0.15 * BARREL_DISTORTION);
        
        if (abs(p_curved.x) > 0.5 || abs(p_curved.y) > 0.5) {
            gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
            return;
        }
    }

    // 3. Fast Sharp-Bilinear (Anti-Moire)
    vec2 tex_uv = (p_curved + 0.5) / sc;
    vec2 tc = tex_uv * TextureSize;
    vec2 i = floor(tc);
    vec2 f = tc - i;
    float region = 0.5 - (hardPix * 0.05); 
    f = clamp(f / (1.0 - region * 2.0) - region / (1.0 - region * 2.0), 0.0, 1.0);
    
    vec3 color = texture2D(Texture, (i + f + 0.5) * inv_res).rgb;
    color *= color; // Linearize

    // 4. Turbo Gaussian Scanlines
    if (scan_str > 0.0) {
        float dst = fract(tex_uv.y * TextureSize.y) - 0.5;
        color *= mix(1.0, exp2(hardScan * dst * dst), scan_str);
    }

    // 5. High-Speed Shadow Mask (Sony & Retro-Grid)
    if (maskDark < 1.0 || maskLight > 1.0) {
        vec2 pos = gl_FragCoord.xy;
        vec3 m = vec3(maskDark);
        
        // حساب الـ RGB Mask (Sony Trinitron Style)
        float x_rgb = fract(pos.x * 0.333333);
        if (x_rgb < 0.333) m.r = maskLight;
        else if (x_rgb < 0.666) m.g = maskLight;
        else m.b = maskLight;

        // دمج الـ Grid (Slot Mask) بدون استهلاك If/Else ثقيلة
        if (shadowMask > 0.5) {
            // معادلة ذكية لصنع التعرج (Staggered Grid)
            float grid_y = fract(pos.y * 0.25);
            float grid_x = fract(pos.x * 0.166666);
            float check = step(0.5, grid_y); // تتبادل بين 0 و 1 كل بكسلين عمودياً
            float black_bar = step(0.5, fract(grid_x + check * 0.5));
            m *= mix(1.0, 0.3, black_bar);
        }
        color *= m;
    }

    // 6. Final Polish
    color *= brightBoost;
    if (VIG_STR > 0.0) color *= (1.0 - dot(p_curved, p_curved) * VIG_STR);

    gl_FragColor = vec4(sqrt(max(color, 0.0)), 1.0);
}
#endif