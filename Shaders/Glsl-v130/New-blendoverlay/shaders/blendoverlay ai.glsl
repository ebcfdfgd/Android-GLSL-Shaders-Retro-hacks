#version 130

/* ULTIMATE-HYBRID (300 Engine - Performance Optimized)
   - Feature: Smart Branching (GPU ignores unused layers).
   - Added: Toshiba Cylindrical Curve & Soft Vignette.
   - Optimized: No texture fetch if Intensity is 0.0.
*/

// --- VERTEX SHADER ---
#if defined(VERTEX)
in vec4 VertexCoord;
in vec2 TexCoord;
out vec2 TEX0;
out vec2 vTexCoord;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    TEX0 = TexCoord; 
    vTexCoord = TexCoord; 
}

// --- FRAGMENT SHADER ---
#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

in vec2 TEX0;
in vec2 vTexCoord;
out vec4 FragColor;

#if __VERSION__ >= 130
#define COMPAT_TEXTURE texture
#else
#define COMPAT_TEXTURE texture2D
#endif

uniform sampler2D Texture;        
uniform sampler2D OverlayTexture; 
uniform sampler2D OverlayTexture2; 
uniform vec2 TextureSize;
uniform vec2 InputSize;
uniform vec2 OutputSize;

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

#ifdef PARAMETER_UNIFORM
uniform float GAME_ZOOM, BRIGHT_BOOST, BARREL_DISTORTION, v_amount, blend_mode, overlay_str, zoom_overlay, png_width, png_height;
uniform float blend_mode2, overlay_str2, zoom_overlay2, png_width2, png_height2;
#endif

vec3 blend_logic(vec3 a, vec3 b, float mode) {
    if (mode < 0.5) return a * b; // Multiply
    if (mode < 1.5) return mix(2.0 * a * b, 1.0 - 2.0 * (1.0 - a) * (1.0 - b), step(0.5, a.r)); // Overlay
    if (mode < 2.5) return (1.0 - 2.0 * b) * a * a + 2.0 * b * a; // Soft Light
    if (mode < 3.5) return clamp(a - b, 0.0, 1.0); // Subtract
    if (mode < 4.5) return a / (1.00001 - b); // Color Dodge
    return min(a, b); // Darken
}

void main() {
    vec2 sc = TextureSize / InputSize;
    vec2 mP = TEX0.xy * TextureSize / InputSize; 
    
    vec2 uv = (TEX0.xy * sc) - 0.5;
    uv /= GAME_ZOOM; 
    
    float kx = BARREL_DISTORTION * 0.2; 
    float ky = BARREL_DISTORTION * 0.9; 

    vec2 d_uv;
    d_uv.x = uv.x * (1.0 + (uv.y * uv.y) * kx);
    d_uv.y = uv.y * (1.0 + (uv.x * uv.x) * ky);
    d_uv *= (1.0 - 0.15 * BARREL_DISTORTION);
    
    if (abs(d_uv.x) > 0.5 || abs(d_uv.y) > 0.5) {
        FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    vec2 fetch_uv = (d_uv + 0.5) / sc;
    vec3 res = COMPAT_TEXTURE(Texture, fetch_uv).rgb * BRIGHT_BOOST;

    // --- Soft Vignette ---
    float vignette = d_uv.x * d_uv.x + d_uv.y * d_uv.y;
    res *= clamp(1.0 - (vignette * v_amount), 0.0, 1.0);

    // --- Smart Branching Layer 1 ---
    if (overlay_str > 0.0) {
        vec2 maskUV1 = vec2(fract(mP.x * OutputSize.x / (png_width * zoom_overlay)), 
                            fract(mP.y * OutputSize.y / (png_height * zoom_overlay)));
        vec3 png1 = COMPAT_TEXTURE(OverlayTexture, maskUV1).rgb;
        res = mix(res, clamp(blend_logic(res, png1, blend_mode), 0.0, 1.0), overlay_str);
    }

    // --- Smart Branching Layer 2 ---
    if (overlay_str2 > 0.0) {
        vec2 maskUV2 = vec2(fract(mP.x * OutputSize.x / (png_width2 * zoom_overlay2)), 
                            fract(mP.y * OutputSize.y / (png_height2 * zoom_overlay2)));
        vec3 png2 = COMPAT_TEXTURE(OverlayTexture2, maskUV2).rgb;
        res = mix(res, clamp(blend_logic(res, png2, blend_mode2), 0.0, 1.0), overlay_str2);
    }

    FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif