#version 110

/* ARCADE MASTER PRO - HYBRID 1013 (Optimized)
    - REMOVED: Dither Blur logic.
    - BYPASS ENGINE: Any parameter at 0.0 skips its computation.
    - FIXED: Toshiba Curve and Mask logic for absolute zero performance cost.
*/

#pragma parameter BARREL_DISTORTION "Arcade: Screen Curve" 0.08 0.0 0.5 0.01
#pragma parameter bright_boost "Arcade: Brightness" 1.30 0.0 2.5 0.05
#pragma parameter contrast_val "Arcade: Contrast" 1.15 0.0 2.0 0.05
#pragma parameter sat_val "Arcade: Saturation" 1.25 0.0 2.0 0.05
#pragma parameter glow_str "Arcade: Glow/Halo" 0.25 0.0 1.0 0.05
#pragma parameter conv_shift "Arcade: Chrom Fringing" 0.40 0.0 1.0 0.05
#pragma parameter mask_type "CRT Mask: (0:Trin 1:Slot)" 1.0 0.0 1.0 1.0
#pragma parameter mask_str "CRT Mask: Strength" 0.45 0.0 1.0 0.05
#pragma parameter scan_str "CRT: Scanline Intensity" 0.70 0.0 1.0 0.05
#pragma parameter black_level "CRT: Black Depth" 0.05 0.0 0.5 0.01
#pragma parameter v_amount "Arcade: Vignette" 0.25 0.0 2.5 0.01

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;
varying vec2 vTexCoord;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, bright_boost, contrast_val, sat_val, glow_str, conv_shift;
uniform float mask_type, mask_str, scan_str, black_level, v_amount;
#endif

vec3 ToLinear(vec3 c) { return c * c; } 
vec3 ToSrgb(vec3 c)   { return sqrt(max(c, 0.0)); } 

void main() {
    vec2 sc = TextureSize / InputSize;
    vec2 uv = (vTexCoord * sc) - 0.5;
    vec2 d_uv = uv;

    // [1] Toshiba Curve Bypass (0.0 = Flat Screen)
    if (BARREL_DISTORTION > 0.0) {
        float kx = BARREL_DISTORTION * 0.2; 
        float ky = BARREL_DISTORTION * 0.9; 
        d_uv.x = uv.x * (1.0 + (uv.y * uv.y) * kx);
        d_uv.y = uv.y * (1.0 + (uv.x * uv.x) * ky);
        d_uv *= (1.0 - 0.15 * BARREL_DISTORTION);
        
        if (abs(d_uv.x) > 0.5 || abs(d_uv.y) > 0.5) {
            gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
            return;
        }
    }

    vec2 pos = (d_uv + 0.5) / sc;

    // [2] Color Fetching (Single or 5-Tap depending on shift)
    vec3 col_c = texture2D(Texture, pos).rgb;
    vec3 col = ToLinear(col_c);

    if (conv_shift > 0.0 || glow_str > 0.0) {
        vec2 off = (1.0 / TextureSize.xy) * (1.0 + conv_shift * 2.0);
        vec3 col_l = ToLinear(texture2D(Texture, pos - vec2(off.x, 0.0)).rgb);
        vec3 col_r = ToLinear(texture2D(Texture, pos + vec2(off.x, 0.0)).rgb);
        vec3 col_u = ToLinear(texture2D(Texture, pos - vec2(0.0, off.y)).rgb);
        vec3 col_d = ToLinear(texture2D(Texture, pos + vec2(0.0, off.y)).rgb);
        
        vec3 blur = (col_l + col_r + col_u + col_d) * 0.25;
        
        if (glow_str > 0.0) col += (blur * blur) * glow_str;
        if (conv_shift > 0.0) {
            col.r = mix(col.r, col_l.r * 1.2, conv_shift);
            col.b = mix(col.b, col_r.b * 1.2, conv_shift);
        }
    }

    // [3] Scanlines Bypass
    if (scan_str > 0.0) {
        float scan_sin = 0.5 + 0.5 * sin(pos.y * TextureSize.y * 6.28318);
        col *= mix(1.0, scan_sin * scan_sin, scan_str);
    }

    // [4] Mask Bypass
    if (mask_str > 0.0) {
        vec2 coord = gl_FragCoord.xy;
        vec3 mask = vec3(1.0);
        if (mask_type < 0.5) {
            float m = fract(coord.x * 0.3333);
            mask = (m < 0.333) ? vec3(1.05, 0.75, 0.75) : (m < 0.666) ? vec3(0.75, 1.05, 0.75) : vec3(0.75, 0.75, 1.05);
        } else {
            vec2 grid = floor(coord * vec2(0.5, 0.2));
            mask = (fract(coord.x * 0.5 + grid.y * 0.5) < 0.5) ? vec3(1.1, 0.8, 1.1) : vec3(0.8, 1.1, 0.8);
        }
        col *= mix(vec3(1.0), mask, mask_str);
    }

    // [5] Final Grade & Boost
    if (black_level > 0.0) col = max(col - black_level, 0.0) / (1.0 - black_level);
    
    col *= bright_boost;
    
    if (contrast_val != 1.0) col = (col - 0.5) * contrast_val + 0.5;
    if (sat_val != 1.0) col = mix(vec3(dot(col, vec3(0.3, 0.59, 0.11))), col, sat_val);

    // [6] Vignette Bypass
    if (v_amount > 0.0) col *= clamp(1.0 - (dot(d_uv, d_uv) * v_amount), 0.0, 1.0);

    gl_FragColor = vec4(ToSrgb(clamp(col, 0.0, 1.0)), 1.0);
}
#endif