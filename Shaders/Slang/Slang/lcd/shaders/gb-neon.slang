#version 450

/* 777-NEON-ARCADE-FULL-CONTROL
    - FEATURES: Individual Hue, Saturation, and Value for each of the 4 colors.
    - MATH: Branchless execution with per-color HSV optimization.
*/

#pragma parameter NEON_ON "Enable Neon Mode" 1.0 0.0 1.0 1.0
#pragma parameter INVERT "Invert Neon Logic" 1.0 0.0 1.0 1.0
#pragma parameter GLOW_STR "Neon Glow Strength" 0.6 0.0 2.0 0.05
#pragma parameter HUE_1 "C1 Hue" 60.0 0.0 360.0 5.0
#pragma parameter SAT_1 "C1 Saturation" 1.0 0.0 1.5 0.05
#pragma parameter VAL_1 "C1 Brightness" 1.0 0.0 1.5 0.05
#pragma parameter HUE_2 "C2 Hue" 30.0 0.0 360.0 5.0
#pragma parameter SAT_2 "C2 Saturation" 1.0 0.0 1.5 0.05
#pragma parameter VAL_2 "C2 Brightness" 0.8 0.0 1.5 0.05
#pragma parameter HUE_3 "C3 Hue" 300.0 0.0 360.0 5.0
#pragma parameter SAT_3 "C3 Saturation" 1.0 0.0 1.5 0.05
#pragma parameter VAL_3 "C3 Brightness" 0.6 0.0 1.5 0.05
#pragma parameter HUE_4 "C4 Hue" 340.0 0.0 360.0 5.0
#pragma parameter SAT_4 "C4 Saturation" 1.0 0.0 1.5 0.05
#pragma parameter VAL_4 "C4 Brightness" 0.1 0.0 1.5 0.05

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float NEON_ON;
	float INVERT;
	float GLOW_STR;
	float HUE_1;
	float SAT_1;
	float VAL_1;
	float HUE_2;
	float SAT_2;
	float VAL_2;
	float HUE_3;
	float SAT_3;
	float VAL_3;
	float HUE_4;
	float SAT_4;
	float VAL_4;
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

// --- بارامترات التحكم المنفصلة ---

// Color 1 (High)

// Color 2

// Color 3 (Red Zone)

// Color 4 (Low)

vec3 hsv2rgb(float h, float s, float v) {
    h = h / 60.0;
    float i = floor(h);
    float f = h - i;
    float p = v * (1.0 - s);
    float q = v * (1.0 - s * f);
    float t = v * (1.0 - s * (1.0 - f));
    vec3 res = vec3(v, t, p) * step(abs(h-0.0), 0.5) +
               vec3(q, v, p) * step(abs(h-1.0), 0.5) +
               vec3(p, v, t) * step(abs(h-2.0), 0.5) +
               vec3(p, q, v) * step(abs(h-3.0), 0.5) +
               vec3(t, p, v) * step(abs(h-4.0), 0.5) +
               vec3(v, p, q) * step(abs(h-5.0), 0.5);
    return res;
}

void main() {
    vec3 raw_col = texture(Source, uv).rgb;
    float luma = dot(raw_col, vec3(0.299, 0.587, 0.114));
    luma = mix(luma, 1.0 - luma, params.INVERT);

    // [تعديل] كل لون يأخذ بارامتراته الخاصة الآن
    vec3 c1 = hsv2rgb(params.HUE_1, params.SAT_1, params.VAL_1);
    vec3 c2 = hsv2rgb(params.HUE_2, params.SAT_2, params.VAL_2);
    vec3 c3 = hsv2rgb(params.HUE_3, params.SAT_3, params.VAL_3);
    vec3 c4 = hsv2rgb(params.HUE_4, params.SAT_4, params.VAL_4); 

    vec3 col = mix(c4, c3, step(0.25, luma));
    col = mix(col, c2, step(0.50, luma));
    col = mix(col, c1, step(0.75, luma));

    float glow_luma = dot(col, vec3(0.299, 0.587, 0.114));
    vec3 neon_final = col + (col * glow_luma * glow_luma * params.GLOW_STR * 5.0);

    FragColor = vec4(mix(raw_col, neon_final, params.NEON_ON), 1.0);
}
