#version 450

#pragma parameter TEXTURE_TAPS "1. Texture Fetches" 0.0 0.0 100.0 1.0
#pragma parameter ITER_POLY "2. Poly Loops" 0.0 0.0 100.0 1.0
#pragma parameter ITER_POW "3. Pow Loops" 0.0 0.0 100.0 1.0
#pragma parameter ITER_SIN "4. Sin Loops" 0.0 0.0 100.0 1.0
#pragma parameter ITER_EXP "5. Exp Loops" 0.0 0.0 100.0 1.0
#pragma parameter ITER_EXP2 "6. Exp2 Loops" 0.0 0.0 100.0 1.0
#pragma parameter ITER_MCOL "7. Mcol Loops" 0.0 0.0 100.0 1.0
#pragma parameter ITER_SMOOTH "8. Smoothstep Loops" 0.0 0.0 100.0 1.0

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float TEXTURE_TAPS;
	float ITER_POLY;
	float ITER_POW;
	float ITER_SIN;
	float ITER_EXP;
	float ITER_EXP2;
	float ITER_MCOL;
	float ITER_SMOOTH;
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
    uv = TexCoord;
    gl_Position = global.MVP * Position;
}

#pragma stage fragment
layout(location = 0) in vec2 uv;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main() {
    vec3 res = texture(Source, uv).rgb;
    float luma = dot(res, vec3(0.299, 0.587, 0.114));

    // 1. Texture Fetches (Memory Pressure)
    if (params.TEXTURE_TAPS > 0.5) {
        vec3 acc = vec3(0.0);
        for(int i = 0; i < 100; i++) {
            if (float(i) >= params.TEXTURE_TAPS) break;
            float seed = float(i) * 12.9898 + dot(uv, vec2(78.233, 151.718));
            vec2 offset = vec2(sin(seed), cos(seed)) * 0.01;
            acc += texture(Source, uv + offset).rgb;
        }
        res = acc / params.TEXTURE_TAPS;
    }

    // 2. Poly Loops
    for(int i = 0; i < 100; i++) {
        if (float(i) >= params.ITER_POLY) break;
        res = res * (1.92 - 0.92 * res) + 0.001;
    }

    // 3. Pow Loops
    for(int i = 0; i < 100; i++) {
        if (float(i) >= params.ITER_POW) break;
        res = pow(res, vec3(2.2)) + 0.001;
    }

    // 4. Sin Loops
    for(int i = 0; i < 100; i++) {
        if (float(i) >= params.ITER_SIN) break;
        res = sin(res * 1.57) + 0.001;
    }

    // 5. Exp Loops
    for(int i = 0; i < 100; i++) {
        if (float(i) >= params.ITER_EXP) break;
        res = exp(res * 0.5) * 0.99;
    }

    // 6. Exp2 Loops
    for(int i = 0; i < 100; i++) {
        if (float(i) >= params.ITER_EXP2) break;
        res = exp2(res * 0.5) * 0.99;
    }

    // 7. Mcol Loops
    for(int i = 0; i < 100; i++) {
        if (float(i) >= params.ITER_MCOL) break;
        res *= vec3(0.99, 0.98, 0.99); // Gradual color shift
    }

    // 8. Smoothstep Loops
    for(int i = 0; i < 100; i++) {
        if (float(i) >= params.ITER_SMOOTH) break;
        res = smoothstep(vec3(0.0), vec3(1.0), res);
    }

    FragColor = vec4(res, 1.0);
}
