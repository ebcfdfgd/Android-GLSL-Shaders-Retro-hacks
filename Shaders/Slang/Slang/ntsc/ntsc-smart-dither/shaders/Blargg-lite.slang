#version 450

#pragma parameter SATURATION "Global Saturation" 1.0 0.0 2.0 0.05
#pragma parameter BRIGHTNESS "Signal Brightness" 1.0 0.0 2.0 0.05
#pragma parameter ntsc_hue "NTSC Phase Shift" 0.0 -3.14 3.14 0.05
#pragma parameter COL_BLEED "Chroma Bleed Strength" 1.5 0.0 5.0 0.1
#pragma parameter rb_global_strength "Rainbow Master Power" 1.0 0.0 5.0 0.1
#pragma parameter rb_power "Rainbow Transparency (Mix)" 0.35 0.0 2.0 0.01
#pragma parameter dot_crawl "Dot Crawl Intensity" 0.25 0.0 1.0 0.01
#pragma parameter de_dither "Dither Blending Strength" 0.50 0.0 1.0 0.01
#pragma parameter pi_mod "Subcarrier Phase Angle" 131.5 0.0 360.0 0.1
#pragma parameter vert_scal "Vertical Phase Scale" 0.5 0.0 2.0 0.01
#pragma parameter sig_noise "Signal RF Grain" 0.04 0.0 0.5 0.01

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float SATURATION;
    float BRIGHTNESS;
    float ntsc_hue;
    float COL_BLEED;
    float rb_global_strength;
    float rb_power;
    float dot_crawl;
    float de_dither;
    float pi_mod;
    float vert_scal;
    float sig_noise;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 hue_trig;

// محاكاة تقريبية للدوران بدون sin/cos
void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
    float h = params.ntsc_hue;
    hue_trig = vec2(1.0 - 0.5 * h * h, h); // تقريب لـ cos/sin
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 hue_trig;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

const mat3 RGB_to_YIQ = mat3(
    0.299,  0.596,  0.211,
    0.587, -0.274, -0.523,
    0.114, -0.322,  0.312
);

const mat3 YIQ_to_RGB = mat3(
    1.0,    1.0,    1.0,
    0.956, -0.272, -1.106,
    0.621, -0.647,  1.703
);

// دالة المثلث السريعة (بديلة sin/cos)
vec2 triangle_wave(float x) {
    vec2 val = abs(fract(vec2(x * 0.159, x * 0.159 + 0.25)) * 2.0 - 1.0) * 2.0 - 1.0;
    return val;
}

// دالة ضجيج خطي سريع
float hash(vec2 co) { return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453); }

void main() {
    vec2 ps = 1.0 / params.SourceSize.xy;
    float time = float(params.FrameCount);
    
    vec3 col_m = texture(Source, vTexCoord).rgb;
    vec3 col_l = texture(Source, vTexCoord - vec2(ps.x, 0.0)).rgb;
    vec3 col_r = texture(Source, vTexCoord + vec2(ps.x, 0.0)).rgb;

    vec3 yiq_m = RGB_to_YIQ * col_m;
    vec3 yiq_l = RGB_to_YIQ * col_l;
    vec3 yiq_r = RGB_to_YIQ * col_r;

    float auto_detect = clamp(abs(yiq_l.x - yiq_m.x) + abs(yiq_r.x - yiq_m.x) - abs(yiq_l.x - yiq_r.x), 0.0, 1.0);
    float rb_mask = clamp(auto_detect * 10.0, 0.0, 1.0); // بديل لـ smoothstep

    float final_y = (params.de_dither > 0.0) ? mix(yiq_m.x, (yiq_l.x * 0.25 + yiq_m.x * 0.5 + yiq_r.x * 0.25), params.de_dither * rb_mask) : yiq_m.x;

    float phase = (vTexCoord.x * params.SourceSize.x * params.pi_mod * 0.017) + (vTexCoord.y * params.SourceSize.y * params.vert_scal * 3.14) + (mod(time, 2.0) * 3.14);
    vec2 wave = triangle_wave(phase);
    
    final_y += wave.x * params.dot_crawl * rb_mask;

    if (params.sig_noise > 0.0) {
        final_y += (hash(vTexCoord + time * 0.01) - 0.5) * params.sig_noise;
    }

    float i = yiq_m.y + (wave.x * rb_mask * params.rb_global_strength * params.rb_power);
    float q = yiq_m.z + (wave.y * rb_mask * params.rb_global_strength * params.rb_power);

    if (params.COL_BLEED > 0.0) {
        float bleed_step = ps.x * params.COL_BLEED;
        vec3 col_bleed_l = RGB_to_YIQ * texture(Source, vTexCoord - vec2(bleed_step, 0.0)).rgb;
        vec3 col_bleed_r = RGB_to_YIQ * texture(Source, vTexCoord + vec2(bleed_step, 0.0)).rgb;
        i = mix(i, (col_bleed_l.y + col_bleed_r.y) * 0.5, 0.5);
        q = mix(q, (col_bleed_l.z + col_bleed_r.z) * 0.5, 0.5);
    }

    float fI = (i * hue_trig.x - q * hue_trig.y) * params.SATURATION;
    float fQ = (i * hue_trig.y + q * hue_trig.x) * params.SATURATION;

    FragColor = vec4(clamp(YIQ_to_RGB * vec3(final_y, fI, fQ) * params.BRIGHTNESS, 0.0, 1.0), 1.0);
}
