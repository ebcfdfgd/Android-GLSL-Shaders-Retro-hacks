#version 110
#extension GL_OES_standard_derivatives : enable

/* 5060-PURE-SQUARE-ZOOM-FIXED
    - ZOOM: Kept the exact original 5060 Global Zoom logic.
    - FIXED: Clamped fwidth to prevent mask destruction on Zoom Out.
    - FIXED: Centered smoothstep for perfect Anti-Aliasing at any scale.
*/

#pragma parameter GAME_ZOOM "Global Zoom Scale" 0.964 0.5 2.0 0.001
#pragma parameter SQ_STR "Square Mask Intensity" 0.5 0.0 1.0 0.05
#pragma parameter SQ_THICK "Square Edge Thickness" 0.15 0.0 0.4 0.01
#pragma parameter BRIGHTNESS_LCD "Brightness Boost" 1.2 1.0 2.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec4 TexCoord;
varying vec2 vTexCoord;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord.xy;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 vTexCoord;
uniform sampler2D Texture;
uniform vec2 TextureSize;

#ifdef PARAMETER_UNIFORM
uniform float GAME_ZOOM, SQ_STR, SQ_THICK, BRIGHTNESS_LCD;
#endif

void main() {
    // 1. Zoom Logic from 5060 (Untouched)
    vec2 uv = (vTexCoord - 0.5) / GAME_ZOOM + 0.5;

    // Bounds Check
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // 2. Pixel Coordinates based on Zoom
    vec2 pix_coord = uv * TextureSize;
    vec3 color = texture2D(Texture, uv).rgb;

    // 3. Hollow Square Mask Logic (ANTI-DESTRUCTION FIX)
    vec2 pos = fract(pix_coord);
    
    // SAFETY CLAMP: Limits fwidth so it never destroys the math when zoomed out
    vec2 df = clamp(fwidth(pix_coord), 0.0001, SQ_THICK * 0.8);
    
    vec2 grid_coord = abs(pos - 0.5);
    float threshold = 0.5 - SQ_THICK;
    
    // CENTERED SMOOTHSTEP: Keeps lines crisp and prevents math inversion
    float mask_x = smoothstep(threshold - df.x, threshold + df.x, grid_coord.x);
    float mask_y = smoothstep(threshold - df.y, threshold + df.y, grid_coord.y);
    
    // Using max to combine X and Y into a hollow square frame
    float frame = max(mask_x, mask_y);
    float mask = 1.0 - (frame * SQ_STR);

    // 4. Final Output (Pure color * Mask * Brightness)
    vec3 final = color * mask * BRIGHTNESS_LCD;

    gl_FragColor = vec4(clamp(final, 0.0, 1.0), 1.0);
}
#endif