#version 110

/* ULTIMATE-HYBRID-LIGHT (L1: Overlay, L2: Multi)
    - REMOVED: Game Zoom logic.
    - KEPT: Dual Layering (Overlay & Multiply).
    - PERFORMANCE: Maximum speed for standard view.
*/

// --- PARAMETERS ---
#pragma parameter BRIGHT_BOOST "Final Bright Boost" 1.2 1.0 5.0 0.05

#pragma parameter overlay_str "L1 PNG Intensity (Overlay)" 0.35 0.0 1.0 0.05
#pragma parameter zoom_overlay "L1 PNG Scale" 1.0 0.1 10.0 0.1
#pragma parameter png_width "L1 PNG Width" 6.0 1.0 1024.0 1.0
#pragma parameter png_height "L1 PNG Height" 4.0 1.0 1024.0 1.0

#pragma parameter overlay_str2 "L2 PNG Intensity (Multi)" 0.20 0.0 1.0 0.05
#pragma parameter zoom_overlay2 "L2 PNG Scale" 1.0 0.1 10.0 0.1
#pragma parameter png_width2 "L2 PNG Width" 6.0 1.0 1024.0 1.0
#pragma parameter png_height2 "L2 PNG Height" 4.0 1.0 1024.0 1.0

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 TEX0, screen_scale;
uniform mat4 MVPMatrix;
uniform vec2 TextureSize, InputSize;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    TEX0 = TexCoord; 
    screen_scale = TextureSize / InputSize;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 TEX0, screen_scale;
uniform sampler2D Texture;           
uniform sampler2D OverlayTexture, OverlayTexture2; 
uniform vec2 TextureSize, InputSize, OutputSize;

#ifdef PARAMETER_UNIFORM
uniform float BRIGHT_BOOST;
uniform float overlay_str, zoom_overlay, png_width, png_height;
uniform float overlay_str2, zoom_overlay2, png_width2, png_height2;
#endif

// دالة الـ Overlay
vec3 overlay_logic(vec3 a, vec3 b) {
    return mix(2.0 * a * b, 1.0 - 2.0 * (1.0 - a) * (1.0 - b), step(0.5, a));
}

void main() {
    // إحداثيات للشاشة (تستخدم للطبقات)
    vec2 mP = TEX0.xy * screen_scale; 
    
    // [1] DIRECT SAMPLING (Standard View - No Zoom)
    vec3 res = texture2D(Texture, TEX0).rgb;

    // [2] Layer 1 (Overlay Mode)
    if (overlay_str > 0.01) {
        vec2 maskUV1 = vec2(fract(mP.x * OutputSize.x / (png_width * zoom_overlay)), 
                            fract(mP.y * OutputSize.y / (png_height * zoom_overlay)));
        vec3 png1 = texture2D(OverlayTexture, maskUV1).rgb;
        
        vec3 ovl1 = overlay_logic(res, png1);
        res = mix(res, clamp(ovl1, 0.0, 1.0), overlay_str);
    }

    // [3] Layer 2 (Multiply Mode)
    if (overlay_str2 > 0.01) {
        vec2 maskUV2 = vec2(fract(mP.x * OutputSize.x / (png_width2 * zoom_overlay2)), 
                            fract(mP.y * OutputSize.y / (png_height2 * zoom_overlay2)));
        vec3 png2 = texture2D(OverlayTexture2, maskUV2).rgb;
        
        res = mix(res, res * png2, overlay_str2);
    }

    // [4] Final Brightness Boost
    res *= BRIGHT_BOOST;

    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif