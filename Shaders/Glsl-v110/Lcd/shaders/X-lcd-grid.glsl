#version 110
#extension GL_OES_standard_derivatives : enable

/* 5060-ZOOM-GSTR-HYBRID
    - ZOOM: Integrated 5060 Global Zoom logic.
    - GREEN: Added G_STR Green Mask Power.
    - FIXED: Mask and Grid remain resolution-independent using fwidth.
*/

#pragma parameter GAME_ZOOM "Global Zoom Scale" 0.964 0.5 2.0 0.001
#pragma parameter G_STR "Green Mask Power" 1.0 0.0 2.0 0.05
#pragma parameter GRID_W "Grid Intensity X" 0.3 0.0 1.0 0.05
#pragma parameter GRID_H "Grid Intensity Y" 0.3 0.0 1.0 0.05
#pragma parameter THICK_X "Line Thickness X" 0.05 0.0 0.4 0.01
#pragma parameter THICK_Y "Line Thickness Y" 0.05 0.0 0.4 0.01
#pragma parameter SUBPIX_STR "Subpixel Strength" 0.5 0.0 1.0 0.05
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
uniform float GAME_ZOOM, G_STR, GRID_W, GRID_H, THICK_X, THICK_Y, SUBPIX_STR, BRIGHTNESS_LCD;
#endif

void main() {
    // 1. Zoom Logic from 5060
    vec2 uv = (vTexCoord - 0.5) / GAME_ZOOM + 0.5;

    // Bounds Check
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // 2. Pixel Coordinates based on Zoom
    vec2 pix_coord = uv * TextureSize;
    vec3 color = texture2D(Texture, uv).rgb;

    // 3. Grid Logic with fwidth
    vec2 pos = fract(pix_coord);
    vec2 df = fwidth(pix_coord);
    vec2 grid_coord = abs(pos - 0.5);
    
    float threshold_x = 0.5 - THICK_X;
    float threshold_y = 0.5 - THICK_Y;
    
    float mask_x = smoothstep(threshold_x - df.x, threshold_x, grid_coord.x);
    float mask_y = smoothstep(threshold_y - df.y, threshold_y, grid_coord.y);
    
    float mask = 1.0 - max(mask_x * GRID_W, mask_y * GRID_H);

    // 4. Subpixel Logic + Green Power (G_STR)
    float x = pos.x * 3.0;
    vec3 w;
    w.r = clamp(1.0 - abs(x - 0.5), 0.0, 1.0);
    w.g = clamp(1.0 - abs(x - 1.5), 0.0, 1.0) * G_STR;
    w.b = clamp(1.0 - abs(x - 2.5), 0.0, 1.0);
    
    vec3 subpixel = mix(vec3(1.0), w * 1.1, SUBPIX_STR);

    // 5. Final Output
    vec3 final = color * mask * subpixel * BRIGHTNESS_LCD;

    gl_FragColor = vec4(clamp(final, 0.0, 1.0), 1.0);
}
#endif