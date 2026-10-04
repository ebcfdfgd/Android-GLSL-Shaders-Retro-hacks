#version 450

/* 777-CRT-ANALOG-MASTER (RAW SIGNAL - CLEAN)
    - OPTIMIZED: Removed RGB Channel manipulation.
    - REMOVED: Bloom processing.
    - READY: Global signal processing only.
*/

// Color Adjustment Parameters (Global Signal Only)

#pragma parameter CLR_SAT "Saturation" 1.0 0.0 2.0 0.05
#pragma parameter CLR_CONT "Contrast" 1.0 0.0 2.0 0.01
#pragma parameter CLR_BRIGHT "Brightness" 0.0 -0.5 0.5 0.01
#pragma parameter CLR_BLK_LVL "Black Level" 0.0 -0.5 0.5 0.01
#pragma parameter CLR_GAMMA "Gamma Correction" 1.0 0.1 3.0 0.01
#pragma parameter CLR_TEMP "Color Temperature" 0.0 -1.0 1.0 0.05

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float CLR_SAT;
	float CLR_CONT;
	float CLR_BRIGHT;
	float CLR_BLK_LVL;
	float CLR_GAMMA;
	float CLR_TEMP;
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
    vec3 col = texture(Source, uv).rgb;
    vec3 lum_coeff = vec3(0.299, 0.587, 0.114);

    // 1. Brightness & Contrast (Global)
    col += params.CLR_BRIGHT;
    col = (col - 0.5) * params.CLR_CONT + 0.5;

    // 2. Black Level (Global Adjustment)
    col += params.CLR_BLK_LVL;

    // 3. Saturation (Luminance based, not channel based)
    float luma_sat = dot(col, lum_coeff);
    col = mix(vec3(luma_sat), col, params.CLR_SAT);

    // 4. Color Temperature (Warm/Cool Adjustment)
    // Positive values = Warm (Red/Yellow shift), Negative values = Cool (Blue shift)
    vec3 temp_adjust = vec3(1.0 + params.CLR_TEMP * 0.15, 1.0, 1.0 - params.CLR_TEMP * 0.15);
    col *= temp_adjust;

    // 5. Gamma Correction
    col = pow(clamp(col, 0.0, 1.0), vec3(params.CLR_GAMMA));

    // 6. Safety Clamp & Output
    FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
