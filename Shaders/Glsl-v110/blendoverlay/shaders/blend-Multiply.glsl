#version 110

/* LIGHT-ULTIMATE (Toshiba V3XEL Turbo - 5050 DNA)
    - PERFORMANCE: Optimized, Zero-Define, Solid Logic.
    - LOGIC: Smart Multiply with static-optimized transparency.
*/

// --- PARAMETERS ---
#pragma parameter BARREL_DISTORTION "Curve 0 Strength" 0.15 0.0 1.0 0.02
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 5.0 0.05
#pragma parameter v_amount "Soft Vignette Intensity" 0.25 0.0 2.5 0.01

#pragma parameter OverlayMix2 "L2 Intensity" 0.5 0.0 1.0 0.05
#pragma parameter LUTWidth2 "L2 Width" 3.0 1.0 1024.0 1.0
#pragma parameter LUTHeight2 "L2 Height" 0.0 1.0 1024.0 1.0

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
uniform vec2 OutputSize, TextureSize, InputSize;
uniform sampler2D Texture, overlay2;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, BRIGHT_BOOST, v_amount, OverlayMix2, LUTWidth2, LUTHeight2;
#endif

void main() {
    vec2 p = (TEX0.xy * screen_scale) - 0.5;
    float r2 = dot(p, p);
    vec2 p_curved = p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8));
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float check = bounds.x * bounds.y;

    vec2 fetch_uv = (p_curved + 0.5) / screen_scale;
    vec3 gm = texture2D(Texture, fetch_uv).rgb;
    gm *= clamp(1.0 - (r2 * v_amount), 0.0, 1.0);

    vec2 mP = TEX0.xy * screen_scale;
    
    if (OverlayMix2 > 0.01) {
        vec2 maskUV2 = vec2(fract(mP.x * OutputSize.x / max(LUTWidth2, 1.0)), 
                            fract(mP.y * OutputSize.y / max(LUTHeight2, 1.0)));
        vec3 m2 = texture2D(overlay2, maskUV2).rgb;
        
        float lum = dot(m2, vec3(0.299, 0.587, 0.114));
        
        // Smart Multiply: القيم ثابتة 0.3 للعتبة و 0.2 للإضاءة
        vec3 smart_mult = mix(gm * m2, gm * (1.0 - (1.0 - m2) * 0.0), lum);
        vec3 final_l2 = mix(smart_mult, m2, lum * 0.2);
        
        gm = mix(gm, clamp(final_l2, 0.0, 1.0), OverlayMix2);
    }

    gl_FragColor = vec4(clamp(gm * BRIGHT_BOOST * check, 0.0, 1.0), 1.0);
}
#endif