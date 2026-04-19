#version 110

/* LIGHT-ULTIMATE (Clean Edition - DNA 5050)
    - OPTIMIZED: Removed all distortion, zoom, and vignette math.
    - CORE: Quilez Scaling + Brightness Boost + Dual Multiply Blending.
*/

// --- PARAMETERS ---
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 5.0 0.05

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
varying vec2 TEX0, inv_tex_size;
uniform mat4 MVPMatrix;
uniform vec2 TextureSize;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    TEX0 = TexCoord.xy;
    inv_tex_size = 1.0 / TextureSize;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 TEX0, inv_tex_size;
uniform vec2 OutputSize, TextureSize;
uniform sampler2D Texture, overlay, overlay2;

#ifdef PARAMETER_UNIFORM
uniform float BRIGHT_BOOST, OverlayMix, LUTWidth, LUTHeight, OverlayMix2, LUTWidth2, LUTHeight2;
#endif

void main() {
    // 1. Quilez Scaling (Base Image)
    vec2 p = TEX0 * TextureSize;
    vec2 i = floor(p);
    vec2 f = p - i;
    f = f * f * (3.0 - 2.0 * f);
    
    vec3 gm = texture2D(Texture, (i + f + 0.5) * inv_tex_size).rgb * BRIGHT_BOOST;

    // 2. Blending Logic (Multiply)
    // L1 Multiply
    vec2 maskUV1 = vec2(fract(TEX0.x * OutputSize.x / LUTWidth), fract(TEX0.y * OutputSize.y / LUTHeight));
    vec3 m1 = texture2D(overlay, maskUV1).rgb;
    gm = mix(gm, gm * m1, OverlayMix);

    // L2 Multiply
    vec2 maskUV2 = vec2(fract(TEX0.x * OutputSize.x / LUTWidth2), fract(TEX0.y * OutputSize.y / LUTHeight2));
    vec3 m2 = texture2D(overlay2, maskUV2).rgb;
    gm = mix(gm, gm * m2, OverlayMix2);

    // Final Output
    gl_FragColor = vec4(gm, 1.0);
}
#endif