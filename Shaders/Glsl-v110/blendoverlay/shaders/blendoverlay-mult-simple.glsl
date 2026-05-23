#version 110

/* LIGHT-ULTIMATE (Toshiba V3XEL Turbo - Zoom Edition)
   - ADDED: 6070 Zoom logic for the base game image.
   - CORE: Direct sampling with single Multiply blending layer.
   - STABLE: Overlay texture mapping remains independent of zoom.
   - UPDATE: Added AVG Luminance Normalization for Layer 1.
*/

// --- PARAMETERS ---
#pragma parameter GAME_ZOOM "Global Zoom Scale" 1.0 0.5 2.0 0.001
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 5.0 0.05

// L1: Multiply
#pragma parameter OverlayMix "L1 Intensity (Multiply)" 1.0 0.0 1.0 0.05
#pragma parameter LUTWidth "L1 Width" 6.0 1.0 1024.0 1.0
#pragma parameter LUTHeight "L1 Height" 4.0 1.0 1024.0 1.0

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec4 TexCoord;
varying vec2 TEX0, screen_scale;
uniform mat4 MVPMatrix;
uniform vec2 TextureSize, InputSize;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    TEX0 = TexCoord.xy;
    screen_scale = TextureSize / InputSize;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 TEX0, screen_scale;
uniform vec2 OutputSize, TextureSize;
uniform sampler2D Texture, overlay;

#ifdef PARAMETER_UNIFORM
uniform float GAME_ZOOM, BRIGHT_BOOST, OverlayMix, LUTWidth, LUTHeight;
#endif

void main() {
    // [1] 6070 Zoom Logic applied ONLY to the game image
    vec2 uv = (TEX0 - 0.5) / GAME_ZOOM + 0.5;

    // Bounds Check (Black borders when zoomed out)
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // Direct game image sampling using zoomed coordinates
    vec3 gm = texture2D(Texture, uv).rgb;

    // [2] Layer 1 Logic (Multiply) + AVG Normalization
    // Using original TEX0 so the overlay remains untouched and static
    vec2 mP = TEX0 * screen_scale;
    
    vec2 maskUV1 = vec2(fract(mP.x * OutputSize.x / LUTWidth), fract(mP.y * OutputSize.y / LUTHeight));
    vec3 m1 = texture2D(overlay, maskUV1).rgb;

    // حساب متوسط الإضاءة لتعويض الفقد الناتج عن الـ Multiply
    float avg1 = (m1.r + m1.g + m1.b) / 3.0;
    
    // دمج الصورة مع الماسك الموزون (Normalized Mask)
    gm = mix(gm, gm * (m1 / max(avg1, 0.01)), OverlayMix);

    // [3] Final Output
    gl_FragColor = vec4(clamp(gm * BRIGHT_BOOST, 0.0, 1.0), 1.0);
}
#endif