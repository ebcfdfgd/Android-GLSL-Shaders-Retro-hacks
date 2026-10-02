#version 110

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord;
varying vec2 vGridCoord;
uniform mat4 MVPMatrix;
uniform vec2 TextureSize;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord.xy;
    vGridCoord = vTexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 vTexCoord;
uniform sampler2D Texture;
uniform vec2 OutputSize;

// --- Parameters ---
#pragma parameter MASK_STR "Mask Strength" 0.4 0.0 1.0 0.05
#pragma parameter SCANLINE_STR "Scanline Strength" 0.3 0.0 1.0 0.05
#pragma parameter LINE_COUNT "Number of Scanlines (Y)" 240.0 50.0 500.0 1.0
#pragma parameter MASK_SIZE "Mask Horizontal Size (X)" 240.0 50.0 1000.0 1.0
#pragma parameter GBA_BRIGHT_BST "Final Brightness Boost" 1.0 1.0 2.0 0.05

#ifdef PARAMETER_UNIFORM
uniform float MASK_STR, SCANLINE_STR, LINE_COUNT, MASK_SIZE, GBA_BRIGHT_BST;
#endif

void main() {
    // [1] Sample raw color
    vec3 col = texture2D(Texture, vTexCoord).rgb;

    // [2] Calculate Grid based on MASK_SIZE (X) and LINE_COUNT (Y)
    vec2 gridCoord = vec2(vTexCoord.x * MASK_SIZE, vTexCoord.y * LINE_COUNT);
    
    // 6.28318 = 2 * PI
    vec3 angle = gridCoord.xxx * 6.28318 + vec3(0.0, 2.09439, 4.18879);
    vec3 grid_rgb = mix(vec3(1.0), sin(angle) * 0.5 + 0.5, MASK_STR);
    
    // Controlled by SCANLINE_STR parameter
    float grid_y = mix(1.0, sin(gridCoord.y * 6.28318) * 0.5 + 0.5, SCANLINE_STR);
    
    vec3 final_grid = grid_rgb * grid_y;

    // [3] Final Output
    gl_FragColor = vec4(clamp(col * final_grid * GBA_BRIGHT_BST, 0.0, 1.0), 1.0);
}
#endif