#version 110

/* 777-EXTREME-TURBO-GEOMETRY
    - PERFORMANCE: Fixed ~22 Poly budget / 0 SFU cycles.
    - FEATURES: 
        1. CRT Geometric Curve (1:1 Center Warp).
        2. Texture Atlas Fix & Strict Black Corners (0 Branching).
        3. 0-SFU Polynomial Scanline Beam (Curves with the screen).
        4. Hardware-Locked RGB Sony Aperture Grille.
        5. Integrated Brightness Boost.
*/

// --- PARAMETERS ---
#pragma parameter WARP_X "CRT Curve Strength" 0.03 0.0 0.1 0.01
#pragma parameter SCAN_INTENSITY "Scanline Darkness" 0.6 0.0 1.0 0.05
#pragma parameter BRIGHTNESS "Brightness Boost" 1.3 1.0 2.0 0.05
#pragma parameter MASK_STRENGTH "Sony Aperture Grille" 0.3 0.0 1.0 0.05
#pragma parameter CRT_GAMMA "CRT Gamma Input" 1.0 0.0 3.0 0.05

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
uniform float WARP_X;
uniform float SCAN_INTENSITY;
uniform float BRIGHTNESS;
uniform float MASK_STRENGTH;
uniform float CRT_GAMMA;
#else
#define WARP_X 0.03
#define SCAN_INTENSITY 0.6
#define BRIGHTNESS 1.3
#define MASK_STRENGTH 0.3
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

    // Fetch the warped pixel color
    vec3 color = texture2D(Texture, final_uv).rgb;
    float w = CRT_GAMMA - 2.0;
    color = color * color * ((1.0 - w) + w * color);
    // -----------------------------------------------------------------------
    // NEW REQ: 0-SFU DYNAMIC SCANLINE BEAM (CURVED & OPTIMIZED)
    // -----------------------------------------------------------------------
    // Calculate pixel luma (brightness) to control the scanline fade
    float luma = dot(color, vec3(0.299, 0.587, 0.114));

    // We use warped_norm_uv.y so that the scanlines curve beautifully along with the CRT warp
    float pos_y = warped_norm_uv.y * InputSize.y;
    float f_y = fract(pos_y) - 0.5;
    float Y = f_y * f_y; 
    
    // Pure polynomial mix (0 SFU - No sin used)
    // Thick scanlines on dark areas, fades completely out on pure white
    float scanline = mix(1.0 - 4.0 * Y * SCAN_INTENSITY, 1.0, luma);

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
    color = color * (1.92 - 0.92 * color);
    gl_FragColor = vec4(color, 1.0);
}
#endif