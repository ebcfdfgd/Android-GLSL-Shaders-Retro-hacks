#version 450

/* 777-CRT-ANALOG-MASTER - PURE GLASS ONLY PASS (NO POW)
    - FEATURES: Fresnel Edge (Linear), Top-Left Specular, and Ambient Surface Gloss.
    - FLAT: No curvature, pure flat glass simulation over original game colors.
*/

// --- GLASS PARAMETERS ---

#pragma parameter GLASS_STR "Glass Reflection Strength" 0.15 0.0 1.0 0.05
#pragma parameter BORDER_GLOSS "Edge Gloss Intensity" 0.20 0.0 1.0 0.05

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float GLASS_STR;
	float BORDER_GLOSS;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 uv;

void main() {
    gl_Position = global.MVP * Position;
    uv = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 uv;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main() {
    // 1. Fetch Original Game Pixels (No color/bloom alterations)
    vec3 col = texture(Source, uv).rgb;

    // 2. Setup Glass Coordinates
    vec2 sc = params.SourceSize.xy / params.SourceSize.xy;
    vec2 p_glass = (uv * sc) - 0.5;
    float r2_glass = dot(p_glass, p_glass);

    // 3. Fresnel Effect (Linearized without pow function)
    float fresnel = r2_glass * r2_glass * 4.84 * params.BORDER_GLOSS;

    // 4. Specular Highlight (Simulated bulb reflection at top-left)
    float spec = smoothstep(0.4, 0.0, length(p_glass - vec2(-0.35, 0.35)));
    spec *= 0.15 * params.GLASS_STR;

    // 5. Ambient Gloss (Center-out surface glow)
    float gloss = (1.0 - length(p_glass)) * 0.05 * params.GLASS_STR;

    // 6. Final Composite & Safety Clamp
    vec3 final_color = col + fresnel + spec + gloss;
    FragColor = vec4(clamp(final_color, 0.0, 1.0), 1.0);
}
