/* ULTIMATE-HYBRID (300 Engine - Backported to 110)
   - FIXED: Bright Boost moved to final stage for correct blending math.
*/

// --- PARAMETERS ---
#pragma parameter GAME_ZOOM "Game Zoom Scale" 1.0 0.5 2.0 0.001
#pragma parameter BRIGHT_BOOST "Final Bright Boost" 1.2 1.0 5.0 0.05
#pragma parameter BARREL_DISTORTION "Toshiba Curve Strength" 0.12 0.0 0.5 0.01
#pragma parameter v_amount "Soft Vignette Intensity" 0.25 0.0 2.5 0.01

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
uniform float GAME_ZOOM, BRIGHT_BOOST, BARREL_DISTORTION, v_amount;
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
    vec2 mP = TEX0.xy * screen_scale; 
    
    // [1] إعداد الإحداثيات والتقوس
    vec2 uv = mP - 0.5;
    uv /= GAME_ZOOM; 
    
    float kx = BARREL_DISTORTION * 0.2; 
    float ky = BARREL_DISTORTION * 0.9; 

    vec2 d_uv;
    d_uv.x = uv.x * (1.0 + (uv.y * uv.y) * kx);
    d_uv.y = uv.y * (1.0 + (uv.x * uv.x) * ky);
    d_uv *= (1.0 - 0.15 * BARREL_DISTORTION);
    
    if (abs(d_uv.x) > 0.5 || abs(d_uv.y) > 0.5) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // [2] معادلة الشرب السريع
    vec2 fetch_uv = (d_uv + 0.5) / screen_scale;
    vec2 p = fetch_uv * TextureSize;
    vec2 i = floor(p);
    vec2 f = p - i;
    f = f * f * (3.0 - 2.0 * f);
    
    // تم حذف BRIGHT_BOOST من هنا
    vec3 res = texture2D(Texture, (i + f + 0.5) * inv_tex_size).rgb;

    // [3] Soft Vignette
    float vignette = d_uv.x * d_uv.x + d_uv.y * d_uv.y;
    res *= clamp(1.0 - (vignette * v_amount), 0.0, 1.0);

    // [4] Layer 1
    if (overlay_str > 0.01) {
        vec2 maskUV1 = vec2(fract(mP.x * OutputSize.x / (png_width * zoom_overlay)), 
                            fract(mP.y * OutputSize.y / (png_height * zoom_overlay)));
        vec3 png1 = texture2D(OverlayTexture, maskUV1).rgb;
        res = mix(res, clamp(blend_logic(res, png1, blend_mode), 0.0, 1.0), overlay_str);
    }

    // [5] Layer 2
    if (overlay_str2 > 0.01) {
        vec2 maskUV2 = vec2(fract(mP.x * OutputSize.x / (png_width2 * zoom_overlay2)), 
                            fract(mP.y * OutputSize.y / (png_height2 * zoom_overlay2)));
        vec3 png2 = texture2D(OverlayTexture2, maskUV2).rgb;
        res = mix(res, clamp(blend_logic(res, png2, blend_mode2), 0.0, 1.0), overlay_str2);
    }

    // [6] نطبق الـ Boost هنا بعد كل عمليات الدمج
    res *= BRIGHT_BOOST;

    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif