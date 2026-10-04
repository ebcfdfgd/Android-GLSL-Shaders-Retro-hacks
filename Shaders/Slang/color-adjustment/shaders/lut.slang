#version 450

/* 777-COLOR-LUT-CLEAN
   - OPTIMIZED: Pipeline strictly limited to LUT and essential post-processing.
*/

// --- 1. Shader Parameters ---

//#pragma parameter CLR_SAT "Saturation" 1.0 0.0 2.0 0.05

#pragma parameter CLU_LUT_Size "LUT: Size (16, 32, 64)" 32.0 4.0 64.0 4.0
#pragma parameter CLU_LUT_OPACITY "LUT: Opacity" 1.0 0.0 1.0 0.05

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float CLU_LUT_Size;
	float CLU_LUT_OPACITY;
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
layout(set = 0, binding = 3) uniform sampler2D SamplerLUT1;

// [LUT Helper]
vec3 apply_3d_lut(sampler2D sampler_in, vec3 color, float size) {
    float red = (color.r * (size - 1.0) + 0.4999) / (size * size);
    float green = (color.g * (size - 1.0) + 0.4999) / size;
    float blue = color.b * (size - 1.0);
    float b_low = floor(blue) / size;
    float b_high = ceil(blue) / size;
    vec4 c1 = texture(sampler_in, vec2(b_low + red, green));
    vec4 c2 = texture(sampler_in, vec2(b_high + red, green));
    return mix(c1.rgb, c2.rgb, fract(blue));
}

void main() {
    vec3 col = texture(Source, uv).rgb;
    vec3 lum_coeff = vec3(0.299, 0.587, 0.114);

    // 1. LUT Engine
    if (params.CLU_LUT_OPACITY > 0.0) {
        vec3 l_res = apply_3d_lut(SamplerLUT1, clamp(col, 0.0, 1.0), params.CLU_LUT_Size);
        col = mix(col, l_res, params.CLU_LUT_OPACITY);
    }

    // 3. Saturation
   // float luma_sat = dot(col, lum_coeff);
   // col = mix(vec3(luma_sat), col, CLR_SAT);

    // 5. Output
    FragColor = vec4(col, 1.0);
}
