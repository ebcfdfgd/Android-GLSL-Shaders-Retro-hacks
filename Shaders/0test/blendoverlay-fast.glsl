/* ULTIMATE-HYBRID-LIGHT (Toshiba V3XEL Turbo - 5050 DNA)
   - LOGIC: Dynamic Threshold Overlay (L1) & Balanced Multiply (L2).
   - EFFECT: Barrel Distortion, Vignette & Brightness Boost.
*/

// --- PARAMETERS ---
#pragma parameter BARREL_DISTORTION "Curve 0 Strength" 0.15 0.0 1.0 0.02
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 5.0 0.05
#pragma parameter v_amount "Soft Vignette Intensity" 0.25 0.0 2.5 0.01

#pragma parameter overlay_str "L1 PNG Intensity (Overlay)" 0.35 0.0 1.0 0.05
#pragma parameter OverlayThreshold "L1 Switch Threshold (0.0 - 1.0)" 0.5 0.0 1.0 0.05
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
uniform sampler2D Texture, OverlayTexture, OverlayTexture2; 
uniform vec2 TextureSize, InputSize, OutputSize;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, BRIGHT_BOOST, v_amount;
uniform float overlay_str, OverlayThreshold, zoom_overlay, png_width, png_height;
uniform float overlay_str2, zoom_overlay2, png_width2, png_height2;
#endif

vec3 overlay_logic_dynamic(vec3 a, vec3 b, float threshold) {
    return mix(2.0 * a * b, 1.0 - 2.0 * (1.0 - a) * (1.0 - b), step(threshold, a));
}

void main() {
    // 1. Barrel Distortion & Coordinate Logic
    vec2 p = (TEX0.xy * screen_scale) - 0.5;
    float r2 = dot(p, p);
    vec2 p_curved = p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8));
    
    // Branchless bounds check
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float check = bounds.x * bounds.y;

    // Direct Sampling
    vec2 fetch_uv = (p_curved + 0.5) / screen_scale;
    vec3 res = texture2D(Texture, fetch_uv).rgb;

    // Vignette
    res *= clamp(1.0 - (r2 * v_amount), 0.0, 1.0);

    vec2 mP = TEX0.xy * screen_scale; 

    // 2. Layer 1 (Overlay Mode)
    if (overlay_str > 0.01) {
        vec2 maskUV1 = vec2(fract(mP.x * OutputSize.x / max(png_width * zoom_overlay, 1.0)), 
                            fract(mP.y * OutputSize.y / max(png_height * zoom_overlay, 1.0)));
        vec3 png1 = texture2D(OverlayTexture, maskUV1).rgb;
        vec3 ovl1 = overlay_logic_dynamic(res, png1, OverlayThreshold);
        res = mix(res, clamp(ovl1, 0.0, 1.0), overlay_str);
    }

    // 3. Layer 2 (Multiply Mode)
    if (overlay_str2 > 0.01) {
        vec2 maskUV2 = vec2(fract(mP.x * OutputSize.x / max(png_width2 * zoom_overlay2, 1.0)), 
                            fract(mP.y * OutputSize.y / max(png_height2 * zoom_overlay2, 1.0)));
        vec3 png2 = texture2D(OverlayTexture2, maskUV2).rgb;
        float avg2 = (png2.r + png2.g + png2.b) / 3.0;
        vec3 png2_balanced = png2 / max(avg2, 0.01); 
        res = mix(res, res * png2_balanced, overlay_str2);
    }

    // 4. Final Output with Boost & Border Check
    gl_FragColor = vec4(clamp(res * BRIGHT_BOOST * check, 0.0, 1.0), 1.0);
}
#endif