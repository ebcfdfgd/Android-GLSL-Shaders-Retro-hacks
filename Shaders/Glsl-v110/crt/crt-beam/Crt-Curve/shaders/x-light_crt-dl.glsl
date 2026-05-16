#version 110

/* 777-LITE-TURBO-V4-ULTRA-FIXED (Dynamic Beam Edition)
    - INTEGRATED: Dynamic Pixel-Synced Scan_Beam (reacts to luma).
    - UPDATED: Replaced Mask Strength with Dark/Light Mask logic.
    - FEATURES: Curved CRT geometry intact, Branchless math.
    - CONTROLS: mask_dark (0.50) and mask_light (1.50) standard.
*/

#pragma parameter BARREL_DISTORTION "Screen Curve" 0.15 0.0 1.0 0.02
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.20 1.0 2.0 0.01
#pragma parameter VIG_STR "Vignette Intensity" 0.15 0.0 2.0 0.05

// --- Dynamic Scan_Beam Parameters ---
#pragma parameter SCAN_STR "Scanline Intensity (0=OFF)" 0.40 0.0 1.0 0.05
#pragma parameter SCAN_BEAM "Beam Glow (Fast React)" 1.2 0.5 3.0 0.1

// --- New Mask Parameters ---
#pragma parameter mask_dark "Mask Dark Color" 0.80 0.0 2.0 0.05
#pragma parameter mask_light "Mask Light Color" 1.20 0.0 2.0 0.05
#pragma parameter MASK_W "Mask Width (3=RGB)" 3.0 1.0 6.0 1.0

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
varying vec2 screen_scale; 
uniform mat4 MVPMatrix;
uniform vec2 TextureSize, InputSize;

void main() {
    uv = TexCoord;
    screen_scale = TextureSize / InputSize; 
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 uv;
varying vec2 screen_scale;
uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;

#ifdef PARAMETER_UNIFORM
// تم تبديل بارميتر hardScan ببارميتر SCAN_BEAM الخاص بالشعاع الديناميكي
uniform float BARREL_DISTORTION, BRIGHT_BOOST, VIG_STR, SCAN_STR, SCAN_BEAM, mask_dark, mask_light, MASK_W;
#endif

void main() {
    // 1. Coordinates & Curve (تأثير الكيرف سليم دون تغيير)
    vec2 p = (uv * screen_scale) - 0.5;
    float r2 = dot(p, p);
    vec2 p_curved = p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8));
    
    // 2. Exact Game UVs
    vec2 tex_uv = (p_curved + 0.5) / screen_scale;
    vec3 res = texture2D(Texture, tex_uv).rgb;

    // 3. Branchless Bounds Check
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float check = bounds.x * bounds.y;

    // 4. DYNAMIC SCAN_BEAM INTEGRATION (تعديل السكان فقط)
    float lum = dot(res, vec3(0.299, 0.587, 0.114));
    float pos_y = tex_uv.y * TextureSize.y;
    float dist = abs(fract(pos_y - 0.5) - 0.5);
    
    float beam_calc = dist * (SCAN_BEAM + (lum * 1.5));
    float scan = exp2(-(beam_calc * beam_calc)); 
    
    float scan_weight = mix(1.0, scan, SCAN_STR);
    res *= mix(1.0, scan_weight, step(0.01, SCAN_STR));

    // 5. RGB Mask (Dark/Light Logic - سليم دون تغيير)
    float W = floor(MASK_W);
    float pos = mod(gl_FragCoord.x, W) / W;
    vec3 mcol = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), mask_dark, mask_light);
    res *= mcol;

    // 6. Final Polish
    res *= BRIGHT_BOOST;
    res *= (1.0 - r2 * VIG_STR);

    gl_FragColor = vec4(res * check, 1.0);
}
#endif