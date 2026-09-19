#version 110

/* 777-EXTREME-TURBO-GEOMETRY
    - FEATURES: 
        1. CRT Geometric Curve (1:1 Center Warp).
        2. Texture Atlas Fix & Strict Black Corners (0 Branching).
        3. Accurate SIN-based Scanlines (Curves with the screen).
        4. Hardware-Locked RGB Sony Aperture Grille.
        5. Dynamic Polynomial Gamma Input & Fast Gamma Out.
        6. Curved Vignette Effect.
        7. Integrated Brightness Boost.
        8. Smooth Cubic Texture Interpolation.
*/

// --- PARAMETERS ---
#pragma parameter WARP_X "CRT Curve Strength" 0.03 0.0 0.1 0.01
#pragma parameter SCAN_INTENSITY "Scanline Darkness" 0.6 0.0 1.0 0.05
#pragma parameter BRIGHTNESS "Brightness Boost" 1.3 1.0 2.0 0.05
#pragma parameter MASK_STRENGTH "Sony Aperture Grille" 0.3 0.0 1.0 0.05
#pragma parameter CRT_GAMMA "CRT Gamma Input" 1.0 0.0 3.0 0.05
#pragma parameter VIGNETTE_STR "Vignette Strength" 0.15 0.0 0.5 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
uniform mat4 MVPMatrix;

void main() {
    uv = TexCoord;
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform vec2 InputSize;

#ifdef PARAMETER_UNIFORM
uniform float WARP_X, SCAN_INTENSITY, BRIGHTNESS, MASK_STRENGTH, CRT_GAMMA, VIGNETTE_STR;
#else
#define WARP_X 0.03
#define SCAN_INTENSITY 0.6
#define BRIGHTNESS 1.3
#define MASK_STRENGTH 0.3
#define CRT_GAMMA 2.38
#define VIGNETTE_STR 0.15
#endif

void main() {
    // -----------------------------------------------------------------------
    // REQ 1: TEXTURE ATLAS FIX
    // -----------------------------------------------------------------------
    vec2 frame_scale = TextureSize / InputSize;
    vec2 norm_uv = uv * frame_scale; // Converts to strict 0.0 to 1.0 range

    // -----------------------------------------------------------------------
    // REQ 0 & 2: NO FORCED ZOOM + 1:1 CENTER WARP
    // -----------------------------------------------------------------------
    vec2 cc = norm_uv - 0.5; // Center is exactly at 0.0
    
    float dist = dot(cc, cc);
    cc = cc * (1.0 + WARP_X * dist); 
    
    // Convert back to 0.0 -> 1.0 range
    vec2 warped_norm_uv = cc + 0.5;

    // Re-apply the frame scale to fetch from the RetroArch texture atlas correctly
    vec2 final_uv = warped_norm_uv / frame_scale;

    // -----------------------------------------------------------------------
    // REQ 3: STRICT BLACK CORNERS (ALU ONLY)
    // -----------------------------------------------------------------------
    vec2 bounds = step(vec2(0.0), warped_norm_uv) * step(warped_norm_uv, vec2(1.0));
    float in_bounds = bounds.x * bounds.y; // 1.0 if inside, 0.0 if in the empty curved corners

    // -----------------------------------------------------------------------
    // SMOOTH TEXTURE FETCH (Interpolation)
    // -----------------------------------------------------------------------
    vec2 Q_p = final_uv * TextureSize;
    vec2 Q_i = floor(Q_p) + 0.50;
    vec2 Q_f = Q_p - Q_i;
    vec2 Q_final = (Q_i + 4.0*Q_f*Q_f*Q_f) / TextureSize;
    
    // Fetch the warped and smoothed pixel color
    vec3 color = texture2D(Texture, Q_final).rgb;

    // -----------------------------------------------------------------------
    // REQ 4: DYNAMIC GAMMA INPUT (Linearization)
    // -----------------------------------------------------------------------
    float w = CRT_GAMMA - 2.0;
    color = color * color * ((1.0 - w) + w * color);

    // -----------------------------------------------------------------------
    // NEW REQ: CURVED VIGNETTE
    // -----------------------------------------------------------------------
    float vignette = 1.0 - dist * VIGNETTE_STR;
    color *= vignette;

    // -----------------------------------------------------------------------
    // NEW REQ: SIN-BASED DYNAMIC SCANLINE BEAM
    // -----------------------------------------------------------------------
    // Calculate pixel luma (brightness) to control the scanline fade
    float luma = dot(color, vec3(0.299, 0.587, 0.114));

    // The scanline depth dynamically reduces as luma approaches 1.0 (bright light)
    float current_scan_depth = SCAN_INTENSITY * (1.0 - luma * 0.85); 
    float scan_phase = warped_norm_uv.y * InputSize.y * 6.2831853;
    float scan_wave = sin(scan_phase);
    float scanline = mix(1.0 - current_scan_depth, 1.0, scan_wave * 0.5 + 0.5);

    // -----------------------------------------------------------------------
    // SONY APERTURE GRILLE (0 SFU, Pure ALU)
    // -----------------------------------------------------------------------
    float pixel_x = mod(gl_FragCoord.x, 3.0);
    vec3 mask = vec3(1.0 - MASK_STRENGTH); // Base dark level for the grille
    
    // Boost specific color channels based on horizontal screen pixel position
    mask.r += MASK_STRENGTH * step(pixel_x, 1.0);
    mask.g += MASK_STRENGTH * step(1.0, pixel_x) * step(pixel_x, 2.0);
    mask.b += MASK_STRENGTH * step(2.0, pixel_x);

    // Final Output: Combine color, physical curved scanlines, phosphor mask, brightness, and corner bounds
    color = color * scanline * mask * BRIGHTNESS * in_bounds;

    // -----------------------------------------------------------------------
    // REQ 8: FAST GAMMA OUT (Display Correction)
    // -----------------------------------------------------------------------
    color = color * (1.92 - 0.92 * color);

    gl_FragColor = vec4(color, 1.0);
}
#endif