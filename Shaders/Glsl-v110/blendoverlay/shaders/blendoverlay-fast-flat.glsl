#version 110

/* ULTIMATE-HYBRID-LIGHT (L1: Overlay, L2: Multi)
    - UPDATED: Added AVG Luminance Normalization for L2.
    - LOGIC: Prevents "Black Crush" when using Multiply masks.
*/

// --- PARAMETERS ---
#pragma parameter GAMMA_POW "Gamma Power (Pro)" 1.0 0.1 3.0 0.05
#pragma parameter overlay_str "L1 PNG Intensity (Overlay)" 0.35 0.0 1.0 0.05
#pragma parameter zoom_overlay "L1 PNG Scale" 1.0 0.1 10.0 0.1
#pragma parameter png_width "L1 PNG Width" 0.0 0.0 1024.0 1.0
#pragma parameter png_height "L1 PNG Height" 5.0 1.0 1024.0 1.0

#pragma parameter overlay_str2 "L2 PNG Intensity (Multi)" 0.10 0.0 1.0 0.05
#pragma parameter zoom_overlay2 "L2 PNG Scale" 1.0 0.1 10.0 0.1
#pragma parameter png_width2 "L2 PNG Width" 6.0 1.0 1024.0 1.0
#pragma parameter png_height2 "L2 PNG Height" 2.0 1.0 1024.0 1.0

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
uniform float GAMMA_POW;
uniform float overlay_str, zoom_overlay, png_width, png_height;
uniform float overlay_str2, zoom_overlay2, png_width2, png_height2;
#endif

// دالة الـ Overlay
vec3 overlay_logic(vec3 a, vec3 b) {
    return mix(2.0 * a * b, 1.0 - 2.0 * (1.0 - a) * (1.0 - b), step(0.5, a));
}

void main() {
    vec2 mP = TEX0.xy * screen_scale; 
    
    // [1] DIRECT SAMPLING
    vec3 res = texture2D(Texture, TEX0).rgb;

    // [2] Layer 1 (Overlay Mode)
    if (overlay_str > 0.01) {
        vec2 maskUV1 = vec2(fract(mP.x * OutputSize.x / max(png_width * zoom_overlay, 1.0)), 
                            fract(mP.y * OutputSize.y / max(png_height * zoom_overlay, 1.0)));
        vec3 png1 = texture2D(OverlayTexture, maskUV1).rgb;
        
        vec3 ovl1 = overlay_logic(res, png1);
        res = mix(res, clamp(ovl1, 0.0, 1.0), overlay_str);
    }

    // [3] Layer 2 (Multiply Mode) مع إضافة الـ AVG
    if (overlay_str2 > 0.01) {
        vec2 maskUV2 = vec2(fract(mP.x * OutputSize.x / max(png_width2 * zoom_overlay2, 1.0)), 
                            fract(mP.y * OutputSize.y / max(png_height2 * zoom_overlay2, 1.0)));
        vec3 png2 = texture2D(OverlayTexture2, maskUV2).rgb;
        
        // --- سطر الـ AVG لتعويض الإضاءة المفقودة ---
        float avg2 = (png2.r + png2.g + png2.b) / 3.0;
        vec3 png2_balanced = png2 / max(avg2, 0.01); 
        
        // استخدام النسخة الموزونة (Balanced) للحفاظ على السطوع
        res = mix(res, res * png2_balanced, overlay_str2);
    }

  
res = pow(res, vec3(1.0 / GAMMA_POW));

    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif