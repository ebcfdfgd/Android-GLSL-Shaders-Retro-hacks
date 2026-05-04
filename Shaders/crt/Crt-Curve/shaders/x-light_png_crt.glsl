/* ULTIMATE-TURBO-HYBRID-V6-SUPERSONIC
    - UPDATED: Replaced Sine scanlines with Lottes Scanlines.
    - SPEED: Pure Branchless Math.
    - REMOVED: Bloom and PNG Mask.
*/

#pragma parameter BARREL_DISTORTION "Toshiba Curve (0=OFF)" 0.12 0.0 0.5 0.01
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 2.5 0.05
#pragma parameter v_amount "Vignette Intensity (0=OFF)" 0.25 0.0 2.5 0.01
#pragma parameter MASK_STR "Mask Intensity (0=OFF)" 0.45 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width" 3.0 1.0 15.0 1.0

// --- Lottes Scanline Parameters ---
#pragma parameter hardScan "Lottes Scan Hardness" -8.0 -20.0 0.0 1.0
#pragma parameter SCAN_STR "Scanline Intensity (0=OFF)" 0.40 0.0 1.0 0.05

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
uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, BRIGHT_BOOST, v_amount, MASK_STR, MASK_W, hardScan, SCAN_STR;
#endif

void main() {
    // 1. Centered Coordinates
    vec2 uv = (TEX0 * screen_scale) - 0.5;
    float r2 = dot(uv, uv);

    // 2. Curvature Math
    vec2 d_uv = uv * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8)) * (1.0 - 0.12 * BARREL_DISTORTION);

    // 3. Branchless Bounds Check
    vec2 bounds = step(abs(d_uv), vec2(0.5));
    float check = bounds.x * bounds.y;

    // 4. Hardware Sampling
    vec2 tex_uv = (d_uv + 0.5) / screen_scale;
    vec3 res = texture2D(Texture, tex_uv).rgb;

    // 5. LOTTES SCANLINES
    float dst = fract(tex_uv.y * TextureSize.y) - 0.5;
    float scanline = exp2(hardScan * dst * dst);
    res = mix(res, res * scanline, SCAN_STR);

    // 6. Pure RGB Mask Logic (Always Active)
    float mw = floor(max(MASK_W, 1.0));
    float pos = mod(gl_FragCoord.x, mw);
    
    vec3 mcol = mix(
        vec3(clamp(abs((pos/mw)*6.0-3.0)-1.0, 0.0, 1.0), clamp(2.0-abs((pos/mw)*6.0-2.0), 0.0, 1.0), clamp(2.0-abs((pos/mw)*6.0-4.0), 0.0, 1.0)) * 1.6,
        (pos < 1.0) ? vec3(1.4, 0.6, 0.6) : (pos < 2.0) ? vec3(0.6, 1.4, 0.6) : vec3(0.6, 0.6, 1.4),
        step(mw, 3.5)
    );

    res = mix(res, res * mcol, MASK_STR);

    // 7. Final Polish
    res *= BRIGHT_BOOST;
    res *= (1.0 - r2 * v_amount);
    
    gl_FragColor = vec4(res * check, 1.0);
}
#endif