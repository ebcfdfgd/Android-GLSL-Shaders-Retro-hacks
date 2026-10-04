#version 450

/* GBA-LCD-ULTRA-LIGHT (NO GRAIN)
    - STRIPPED: Removed Gamma, Black Level, Saturation, Brightness, Plastic Grain, and unused Mask modes.
    - SPEED: Zero-Branching (No IF statements).
    - OPTIMIZED: Single texture fetch with pure hardware-accelerated math.
*/

#pragma parameter MASK_STR "Mask Strength" 0.4 0.0 1.0 0.05
#pragma parameter SCANLINE_STR "Scanline Strength" 0.25 0.0 1.0 0.05
#pragma parameter GBA_BRIGHT_BST "Final Brightness Boost" 1.0 1.0 2.0 0.05

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float MASK_STR;
	float SCANLINE_STR;
	float GBA_BRIGHT_BST;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 vGridCoord;

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord.xy;
    vGridCoord = vTexCoord * params.SourceSize.xy;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 vGridCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

// --- Parameters ---

void main() {
    // [1] Sample raw color
    vec3 col = texture(Source, vTexCoord).rgb;

    // [2] Calculate Grid
    // 6.28318 = 2 * PI
    vec3 angle = vGridCoord.xxx * 6.28318 + vec3(0.0, 2.09439, 4.18879);
    vec3 grid_rgb = mix(vec3(1.0), sin(angle) * 0.5 + 0.5, params.MASK_STR);
    
    // Controlled by new SCANLINE_STR parameter
    float grid_y = mix(1.0, sin(vGridCoord.y * 6.28318) * 0.5 + 0.5, params.SCANLINE_STR);
    
    vec3 final_grid = grid_rgb * grid_y;

    // [3] Final Output
    FragColor = vec4(clamp(col * final_grid * params.GBA_BRIGHT_BST, 0.0, 1.0), 1.0);
}
