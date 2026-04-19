#version 110

/* ULTIMATE-HYBRID (300 Engine - Backported to 110)
   - REMOVED: Distortion and Vignette (Raw Performance Mode).
   - FIXED: Bright Boost moved to final stage for correct blending.
*/

// --- PARAMETERS ---
#pragma parameter GAME_ZOOM "Game Zoom Scale" 1.0 0.5 2.0 0.001
#pragma parameter BRIGHT_BOOST "Final Bright Boost" 1.2 1.0 5.0 0.05

#pragma parameter blend_mode "L1 Mode: Mult, Over, Soft, SUB, DODGE, DARK" 0.0 0.0 5.0 1.0
#pragma parameter overlay_str "L1 PNG Intensity" 0.35 0.0 1.0 0.05
#pragma parameter zoom_overlay "L1 PNG Scale" 1.0 0.1 10.0 0.1
#pragma parameter png_width "L1 PNG Width" 6.0 1.0 1024.0 1.0
#pragma parameter png_height "L1 PNG Height" 4.0 1.0 1024.0 1.0

#pragma parameter blend_mode2 "L2 Mode: Mult, Over, Soft, SUB, DODGE, DARK" 0.0 0.0 5.0 1.0
#pragma parameter overlay_str2 "L2 PNG Intensity" 0.20 0.0 1.0 0.05
#pragma parameter zoom_overlay2 "L2 PNG Scale" 1.0 0.1 10.0 0.1
#pragma parameter png_width2 "L2 PNG Width" 6.0 1.0 1024.0 1.0
#pragma parameter png_height2 "L2 PNG Height" 4.0 1.0 1024.0 1.0

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 TEX0, screen_scale, inv_tex_size;
uniform mat4 MVPMatrix;
uniform vec2 TextureSize, InputSize;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    TEX0 = TexCoord; 
    screen_scale = TextureSize / InputSize;
    inv_tex_size = 1.0 / TextureSize;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 TEX0, screen_scale, inv_tex_size;
uniform sampler2D Texture;         
uniform sampler2D OverlayTexture, OverlayTexture2; 
uniform vec2 TextureSize, InputSize, OutputSize;

#ifdef PARAMETER_UNIFORM
uniform float GAME_ZOOM, BRIGHT_BOOST;
uniform float blend_mode, overlay_str, zoom_overlay, png_width, png_height;
uniform float blend_mode2, overlay_str2, zoom_overlay2, png_width2, png_height2;
#endif

vec3 blend_logic(vec3 a, vec3 b, float mode) {
    if (mode < 0.5) return a * b;
    if (mode < 1.5) return mix(2.0 * a * b, 1.0 - 2.0 * (1.0 - a) * (1.0 - b), step(0.5, a.r));
    if (mode < 2.5) return (1.0 - 2.0 * b) * a * a + 2.0 * b * a;
    if (mode < 3.5) return clamp(a - b, 0.0, 1.0);
    if (mode < 4.5) return a / (1.00001 - b);
    return min(a, b);
}

void main() {
    // إحداثيات للشاشة (تستخدم للطبقات)
    vec2 mP = TEX0.xy * screen_scale; 
    
    // [1] إعداد إحداثيات الصورة (Zoom)
    vec2 uv = (TEX0.xy - 0.5) / GAME_ZOOM + 0.5;
    
    // [2] معادلة الشرب السريع (Quilez Scaling)
    vec2 p = uv * TextureSize;
    vec2 i = floor(p);
    vec2 f = p - i;
    f = f * f * (3.0 - 2.0 * f);
    
    vec3 res = texture2D(Texture, (i + f + 0.5) * inv_tex_size).rgb;

    // [3] Layer 1
    if (overlay_str > 0.01) {
        vec2 maskUV1 = vec2(fract(mP.x * OutputSize.x / (png_width * zoom_overlay)), 
                            fract(mP.y * OutputSize.y / (png_height * zoom_overlay)));
        vec3 png1 = texture2D(OverlayTexture, maskUV1).rgb;
        res = mix(res, clamp(blend_logic(res, png1, blend_mode), 0.0, 1.0), overlay_str);
    }

    // [4] Layer 2
    if (overlay_str2 > 0.01) {
        vec2 maskUV2 = vec2(fract(mP.x * OutputSize.x / (png_width2 * zoom_overlay2)), 
                            fract(mP.y * OutputSize.y / (png_height2 * zoom_overlay2)));
        vec3 png2 = texture2D(OverlayTexture2, maskUV2).rgb;
        res = mix(res, clamp(blend_logic(res, png2, blend_mode2), 0.0, 1.0), overlay_str2);
    }

    // [5] تطبيق الـ Boost النهائي
    res *= BRIGHT_BOOST;

    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif