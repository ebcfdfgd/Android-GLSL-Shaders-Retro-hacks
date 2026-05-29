#version 110

/* GBA-LCD-ULTRA-LIGHT (NO GRAIN)
    - STRIPPED: Removed Gamma, Black Level, Saturation, Brightness, Plastic Grain, and unused Mask modes.
    - SPEED: Zero-Branching (No IF statements).
    - OPTIMIZED: Single texture fetch with pure hardware-accelerated math.
*/

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
    vGridCoord = vTexCoord * TextureSize;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 vTexCoord;
varying vec2 vGridCoord;
uniform sampler2D Texture;

// --- Parameters ---
#pragma parameter MASK_STR "Mask Strength" 0.4 0.0 1.0 0.05
#pragma parameter GBA_BRIGHT_BST "Final Brightness Boost" 1.0 1.0 2.0 0.05

#ifdef PARAMETER_UNIFORM
uniform float MASK_STR, GBA_BRIGHT_BST;
#endif

void main() {
    // [1] Sample raw color
    vec3 col = texture2D(Texture, vTexCoord).rgb;

    // [2] Calculate Grid
    // 6.28318 = 2 * PI
    vec3 angle = vGridCoord.xxx * 6.28318 + vec3(0.0, 2.09439, 4.18879);
    vec3 grid_rgb = mix(vec3(1.0), sin(angle) * 0.5 + 0.5, MASK_STR);
    float grid_y = mix(1.0, sin(vGridCoord.y * 6.28318) * 0.5 + 0.5, MASK_STR * 0.6);
    vec3 final_grid = grid_rgb * grid_y;

    // [3] Final Output
    gl_FragColor = vec4(clamp(col * final_grid * GBA_BRIGHT_BST, 0.0, 1.0), 1.0);
}
#endif