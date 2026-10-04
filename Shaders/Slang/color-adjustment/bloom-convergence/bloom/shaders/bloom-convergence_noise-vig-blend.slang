#version 450

// Convergence + Bloom + Film Grain + Vignette + SGPT Blend
// license: public domain

#pragma parameter BOGUS_FILM_NOISE "-------------------CONVERG./FILM NOISE/BLOOM-------------------" 0.0 0.0 0.0 0.0
#pragma parameter CONV_STR "Convergence Strength" 0.05 -1.0 1.0 0.01
#pragma parameter grain_str "Grain Strength" 0.1 0.0 100.0 0.1
#pragma parameter BLOOM_STR "Bloom Intensity" 0.3 0.0 1.0 0.05
#pragma parameter BLOOM_THR "Bloom Threshold" 0.6 0.0 1.0 0.05
#pragma parameter VIG_STR "Vignette Intensity" 0.15 0.0 2.0 0.05
#pragma parameter SGPT_BLEND_LEVEL "Blend Level" 1.0 0.0 1.0 0.05

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float BOGUS_FILM_NOISE;
	float CONV_STR;
	float grain_str;
	float BLOOM_STR;
	float BLOOM_THR;
	float VIG_STR;
	float SGPT_BLEND_LEVEL;
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
    uv = TexCoord.xy;
}

#pragma stage fragment
layout(location = 0) in vec2 uv;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

const vec3 Y = vec3(0.299, 0.587, 0.114);

float filmGrain(vec2 uv, float strength, float timer) {
    float x = (uv.x + 4.0) * (uv.y + 4.0) *
              ((mod(timer, 800.0) + 10.0) * 10.0);

    return (mod((mod(x, 13.0) + 1.0) *
                (mod(x, 123.0) + 1.0), 0.01) - 0.005) * strength;
}

void main() {

    // ============================================================
    // 1. Horizontal Convergence
    // ============================================================

    vec2 conv = vec2(0.01 * params.CONV_STR, 0.0);

    // ============================================================
    // 2. Three Texture Fetches
    // ============================================================

    vec3 colR = texture(Source, uv + conv).rgb;
    vec3 colG = texture(Source, uv).rgb;
    vec3 colB = texture(Source, uv - conv).rgb;

    // ============================================================
    // 3. Convergence
    // ============================================================

    vec3 film = vec3(
        colR.r,
        colG.g,
        colB.b
    );

    // ============================================================
    // 4. Bloom
    // ============================================================

    vec3 bloom_src =
        (colR + colG + colB) / 3.0;

    vec3 bloom_final =
        max(bloom_src - params.BLOOM_THR, 0.0) *
        params.BLOOM_STR;

    film += bloom_final;

    // ============================================================
    // 5. Film Grain
    // ============================================================

    film += filmGrain(
        uv,
        params.grain_str,
        float(params.FrameCount)
    );

    // ============================================================
    // 6. Vignette
    // ============================================================

    vec2 p = uv - 0.5;
    float r2 = dot(p, p);

    film *= (1.0 - r2 * params.VIG_STR);

    // ============================================================
    // 7. SGPT Blend
    // ============================================================

    vec2 dx = vec2(1.0 / params.SourceSize.x, 0.0);

    // قراءة البكسلات المجاورة
    vec3 C = film;
    vec3 L = texture(Source, uv - dx).rgb;
    vec3 R = texture(Source, uv + dx).rgb;

    // الفروقات
    vec3 diffL = C - L;
    vec3 diffR = C - R;

    // تحديد الجانب الأقل حدة
    float wL = dot(abs(diffL), Y);
    float wR = dot(abs(diffR), Y);

    // Direct Blend
    vec3 color = (wR < wL)
        ? (C - 0.5 * params.SGPT_BLEND_LEVEL * diffR)
        : (C - 0.5 * params.SGPT_BLEND_LEVEL * diffL);

    // Clamp نهائي
    color = clamp(
        color,
        min(C, min(L, R)),
        max(C, max(L, R))
    );

    FragColor = vec4(color, 1.0);
}
