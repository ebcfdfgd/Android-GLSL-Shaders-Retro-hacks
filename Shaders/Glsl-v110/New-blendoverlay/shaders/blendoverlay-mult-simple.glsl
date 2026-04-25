#version 110

/* LIGHT-ULTIMATE (Toshiba V3XEL Turbo - 5050 DNA)
    - OPTIMIZED: Branchless pipeline.
    - UPDATED: Only L1 included, Zoom kept, Distortion/Vignette/L2 removed.
    - ADJUSTED: BRIGHT_BOOST moved to Final Output (Master Gain).
*/

// --- PARAMETERS ---
#pragma parameter ZOOM "Zoom Amount" 1.0 0.5 2.0 0.01
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 5.0 0.05

// L1: Multiply
#pragma parameter OverlayMix "L1 Intensity (Multiply)" 1.0 0.0 1.0 0.05
#pragma parameter LUTWidth "L1 Width" 6.0 1.0 1024.0 1.0
#pragma parameter LUTHeight "L1 Height" 4.0 1.0 1024.0 1.0

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
uniform sampler2D Texture, overlay;

#ifdef PARAMETER_UNIFORM
uniform float ZOOM, BRIGHT_BOOST, OverlayMix, LUTWidth, LUTHeight;
#endif

void main() {
    // 1. Coordinates (Zoom applied)
    vec2 uv = (TEX0.xy * screen_scale) - 0.5;
    uv /= ZOOM;
    
    // 2. Quilez Scaling
    // التحويل إلى إحداثيات النسيج (Texture Space)
    vec2 p = (uv + 0.5) * InputSize;
    vec2 i = floor(p);
    vec2 f = p - i;
    f = f * f * (3.0 - 2.0 * f);
    
    vec3 gm = texture2D(Texture, (i + f + 0.5) * inv_tex_size).rgb;

    // 3. Blending Logic (L1 Only)
    vec2 mP = TEX0.xy * screen_scale;
    
    // L1 Multiply
    vec2 maskUV1 = vec2(fract(mP.x * OutputSize.x / LUTWidth), fract(mP.y * OutputSize.y / LUTHeight));
    vec3 m1 = texture2D(overlay, maskUV1).rgb;
    gm = mix(gm, gm * m1, OverlayMix);

    // Final Output (BRIGHT_BOOST as Master Gain)
    gl_FragColor = vec4(clamp(gm * BRIGHT_BOOST, 0.0, 1.0), 1.0);
}
#endif