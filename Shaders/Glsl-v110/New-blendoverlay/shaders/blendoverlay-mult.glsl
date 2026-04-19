#version 110

/* LIGHT-ULTIMATE (Toshiba V3XEL Turbo - 5050 DNA)
    - OPTIMIZED: Branchless pipeline.
    - UPDATED: Both L1 & L2 are now Multiply blending for consistency.
*/

// --- PARAMETERS ---
#pragma parameter BARREL_DISTORTION "Toshiba Curve Strength" 0.12 0.0 0.5 0.01
#pragma parameter ZOOM "Zoom Amount" 1.0 0.5 2.0 0.01
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 5.0 0.05
#pragma parameter v_amount "Soft Vignette Intensity" 0.25 0.0 2.5 0.01

// L1: Multiply
#pragma parameter OverlayMix "L1 Intensity (Multiply)" 1.0 0.0 1.0 0.05
#pragma parameter LUTWidth "L1 Width" 6.0 1.0 1024.0 1.0
#pragma parameter LUTHeight "L1 Height" 4.0 1.0 1024.0 1.0

// L2: Multiply
#pragma parameter OverlayMix2 "L2 Intensity (Multiply)" 0.0 0.0 1.0 0.05
#pragma parameter LUTWidth2 "L2 Width" 6.0 1.0 1024.0 1.0
#pragma parameter LUTHeight2 "L2 Height" 4.0 1.0 1024.0 1.0

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec4 TexCoord;
varying vec2 TEX0, screen_scale, inv_tex_size;
uniform mat4 MVPMatrix;
uniform vec2 TextureSize, InputSize;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    TEX0 = TexCoord.xy;
    screen_scale = TextureSize / InputSize;
    inv_tex_size = 1.0 / TextureSize;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 TEX0, screen_scale, inv_tex_size;
uniform vec2 OutputSize, TextureSize, InputSize;
uniform sampler2D Texture, overlay, overlay2;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, ZOOM, BRIGHT_BOOST, v_amount, OverlayMix, LUTWidth, LUTHeight, OverlayMix2, LUTWidth2, LUTHeight2;
#endif

void main() {
    // 1. Distortion & Coordinates
    vec2 uv = (TEX0.xy * screen_scale) - 0.5;
    uv /= ZOOM;
    
    float kx = BARREL_DISTORTION * 0.2; 
    float ky = BARREL_DISTORTION * 0.9; 

    vec2 d_uv;
    d_uv.x = uv.x * (1.0 + (uv.y * uv.y) * kx);
    d_uv.y = uv.y * (1.0 + (uv.x * uv.x) * ky);
    d_uv *= (1.0 - 0.15 * BARREL_DISTORTION);
    
    // Boundary check
    float mask = step(abs(d_uv.x), 0.5) * step(abs(d_uv.y), 0.5);
    
    // 2. Quilez Scaling
    vec2 fetch_uv = (d_uv + 0.5) / screen_scale;
    vec2 p = fetch_uv * TextureSize;
    vec2 i = floor(p);
    vec2 f = p - i;
    f = f * f * (3.0 - 2.0 * f);
    
    vec3 gm = texture2D(Texture, (i + f + 0.5) * inv_tex_size).rgb * BRIGHT_BOOST;

    // 3. Vignette
    float vignette_sq = dot(d_uv, d_uv);
    gm *= clamp(1.0 - (vignette_sq * vignette_sq * v_amount), 0.0, 1.0);

    // 4. Blending Logic (Branchless & Unified)
    vec2 mP = TEX0.xy * screen_scale;
    
    // L1 Multiply
    vec2 maskUV1 = vec2(fract(mP.x * OutputSize.x / LUTWidth), fract(mP.y * OutputSize.y / LUTHeight));
    vec3 m1 = texture2D(overlay, maskUV1).rgb;
    gm = mix(gm, gm * m1, OverlayMix);

    // L2 Multiply
    vec2 maskUV2 = vec2(fract(mP.x * OutputSize.x / LUTWidth2), fract(mP.y * OutputSize.y / LUTHeight2));
    vec3 m2 = texture2D(overlay2, maskUV2).rgb;
    gm = mix(gm, gm * m2, OverlayMix2);

    // Final Output
    gl_FragColor = vec4(gm * mask, 1.0);
}
#endif