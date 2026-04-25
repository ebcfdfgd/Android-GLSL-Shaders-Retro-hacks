/* ULTIMATE-TURBO-HYBRID-V6-QUILEZ-BLOOM
    - BLOOM-INTEGRATION: Added Luma-threshold based glow.
    - 5050-SAMPLING: Perfect texture mapping retained.
    - QUILEZ-SCALING: S-Curve anti-moire logic.
    - ZERO-BRANCHING: Pure mathematical efficiency.
*/

#pragma parameter BARREL_DISTORTION "Toshiba Curve (0=OFF)" 0.12 0.0 0.5 0.01
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 2.5 0.05
#pragma parameter v_amount "Vignette Intensity (0=OFF)" 0.25 0.0 2.5 0.01

// --- Mask System ---
#pragma parameter MASK_TYPE "Mask: 0:RGB, 1:PNG" 0.0 0.0 1.0 1.0
#pragma parameter MASK_STR "Mask Intensity (0=OFF)" 0.45 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width" 3.0 1.0 15.0 1.0
#pragma parameter MASK_H "Mask Height" 3.0 1.0 15.0 1.0

// --- Scanlines & Bloom ---
#pragma parameter SCAN_STR "Scanline Intensity (0=OFF)" 0.40 0.0 1.0 0.05
#pragma parameter SCAN_DENS "Scanline Density" 1.0 0.2 10.0 0.1
#pragma parameter BLOOM_INT "Bloom Intensity" 0.35 0.0 1.0 0.05
#pragma parameter BLOOM_TH "Bloom Threshold" 0.75 0.0 1.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 TEX0, screen_scale, inv_tex_size;
uniform mat4 MVPMatrix;
uniform vec2 TextureSize, InputSize;

void main() {
    TEX0 = TexCoord;
    screen_scale = TextureSize / InputSize;
    inv_tex_size = 1.0 / TextureSize;
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 TEX0, screen_scale, inv_tex_size;
uniform sampler2D Texture, SamplerMask1;
uniform vec2 TextureSize, InputSize;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, BRIGHT_BOOST, v_amount;
uniform float MASK_TYPE, MASK_STR, MASK_W, MASK_H;
uniform float SCAN_STR, SCAN_DENS, BLOOM_INT, BLOOM_TH;
#endif

void main() {
    // 1. حساب الإحداثيات والمركز
    vec2 uv = (TEX0.xy * screen_scale) - 0.5;
    float r2 = dot(uv, uv);

    // 2. انحناء الشاشة (Curvature)
    vec2 d_uv = uv * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.9)) * (1.0 - 0.15 * BARREL_DISTORTION);
    vec2 bounds = step(abs(d_uv), vec2(0.5));
    float check = bounds.x * bounds.y;

    // 3. 5050-EXACT SAMPLING + QUILEZ
    vec2 tex_uv = (d_uv + 0.5) / screen_scale;
    vec2 p = tex_uv * TextureSize;
    vec2 i = floor(p);
    vec2 f = p - i;
    f = f * f * (3.0 - 2.0 * f); 
    vec3 res = texture2D(Texture, (i + f + 0.5) * inv_tex_size).rgb;
    
    // 4. FIXED SCANLINES
    float scan_pos = (d_uv.y + 0.5) * InputSize.y;
    float scanline = sin(scan_pos * 6.28318 * SCAN_DENS) * 0.5 + 0.5;
    res = mix(res, res * scanline, SCAN_STR);

    // 5. RGB MASK (Vectorized)
    float mw = floor(max(MASK_W, 1.0));
    float mh = floor(max(MASK_H, 1.0));
    float pos = mod(gl_FragCoord.x, mw);
    
    vec3 m_thin = (pos < 1.0) ? vec3(1.4, 0.6, 0.6) : (pos < 2.0) ? vec3(0.6, 1.4, 0.6) : vec3(0.6, 0.6, 1.4);
    float ratio = pos / mw;
    vec3 m_wide = vec3(clamp(abs(ratio * 6.0 - 3.0) - 1.0, 0.0, 1.0),
                       clamp(2.0 - abs(ratio * 6.0 - 2.0), 0.0, 1.0),
                       clamp(2.0 - abs(ratio * 6.0 - 4.0), 0.0, 1.0)) * 1.6;
    
    vec3 mcol_rgb = mix(m_wide, m_thin, step(mw, 3.5));
    vec3 mcol_png = texture2D(SamplerMask1, gl_FragCoord.xy / vec2(mw, mh)).rgb * 1.5;
    
    vec3 mcol_final = mix(mcol_rgb, mcol_png, step(0.5, MASK_TYPE));
    res = mix(res, res * mcol_final, MASK_STR);

    // 6. BLOOM (Luma Threshold)
    // نطبق البلوم بعد الماسك عشان يسيح فوقه (Phosphor Glow)
    float luma = dot(res, vec3(0.299, 0.587, 0.114));
    float bloom_mask = max(0.0, luma - BLOOM_TH);
    res += res * bloom_mask * BLOOM_INT;

    // 7. Final Polish
    res *= BRIGHT_BOOST;
    res *= mix(1.0, clamp(1.0 - (r2 * v_amount), 0.0, 1.0), step(0.01, v_amount));

    gl_FragColor = vec4(clamp(res * check, 0.0, 1.0), 1.0);
}
#endif