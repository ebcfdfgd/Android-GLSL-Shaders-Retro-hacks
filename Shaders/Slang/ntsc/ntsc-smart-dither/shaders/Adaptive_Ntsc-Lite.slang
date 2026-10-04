#version 450

#pragma parameter ntsc_scale "Adaptive Scale" 1.0 0.2 3.0 0.05
#pragma parameter ntsc_bright "NTSC Brightness" 1.0 0.0 2.0 0.05
#pragma parameter ntsc_blur "NTSC Dither Blur" 0.7 0.0 1.0 0.05
#pragma parameter ntsc_tilt "NTSC Tilt Value" 0.0 0.0 5.0 0.1
#pragma parameter ntsc_crawl "NTSC Crawl Speed" 0.0 0.0 5.0 0.1
#pragma parameter merge_fields "Waterfall Field Fix" 1.0 0.0 1.0 1.0
#pragma parameter custom_art "Custom Artifacting" 0.5 0.0 2.0 0.05
#pragma parameter fring_val "Custom Fringing Value" 3.35 0.0 5.0 0.05
#pragma parameter rb_power "Rainbow Power" 0.0 0.0 2.0 0.05
#pragma parameter fr_str "Fringing Intensity" 0.5 0.0 2.0 0.05
#pragma parameter sat_boost "Color Saturation" 1.1 0.0 2.0 0.05
#pragma parameter bleed_str "Chroma Bleed" 3.5 0.0 5.0 0.1
#pragma parameter sig_noise "Signal RF Grain" 0.05 0.0 0.5 0.01

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float ntsc_scale;
    float ntsc_bright;
    float ntsc_blur;
    float ntsc_tilt;
    float ntsc_crawl;
    float merge_fields;
    float custom_art;
    float fring_val;
    float rb_power;
    float fr_str;
    float sat_boost;
    float bleed_str;
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

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

const mat3 RGBtoYIQ = mat3(
    0.299,  0.596,  0.211,
    0.587, -0.274, -0.523,
    0.114, -0.322,  0.312
);

const mat3 YIQtoRGB = mat3(
    1.0,    1.0,    1.0,
    0.956, -0.272, -1.106,
    0.621, -0.647,  1.703
);

// دالة الموجة المثلثية السريعة (بديلة sin/cos)
vec2 triangle_wave(float x) {
    vec2 val = abs(fract(vec2(x * 0.159, x * 0.159 + 0.25)) * 2.0 - 1.0) * 2.0 - 1.0;
    return val;
}

// دالة ضجيج خطي سريع (بديلة لـ hash المعتمدة على sin)
float hash(vec2 co) { return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453); }

void main() {
    vec3 col_m = texture(Source, vTexCoord).rgb;
    
    // Smart Bypass
    if (params.ntsc_blur <= 0.0 && params.rb_power <= 0.0 && params.fr_str <= 0.0 && params.bleed_str <= 0.0 && params.sig_noise <= 0.0) {
        vec3 yiq = RGBtoYIQ * col_m;
        FragColor = vec4(clamp((YIQtoRGB * vec3(yiq.x * params.ntsc_bright, yiq.yz * params.sat_boost)), 0.0, 1.0), 1.0);
        return; 
    }

    float res_scale = 1.0 / params.ntsc_scale;
    vec2 ps = vec2(res_scale / params.SourceSize.x, 1.0 / params.SourceSize.y);
    float time = float(params.FrameCount);
    
    vec3 col_l = texture(Source, vTexCoord - vec2(ps.x, 0.0)).rgb;
    vec3 col_r = texture(Source, vTexCoord + vec2(ps.x, 0.0)).rgb;

    vec3 yiq_m = RGBtoYIQ * col_m;
    vec3 yiq_l = RGBtoYIQ * col_l;
    vec3 yiq_r = RGBtoYIQ * col_r;

    float is_dither = abs(yiq_m.x - yiq_l.x) * abs(yiq_m.x - yiq_r.x);
    float dither_mask = clamp(is_dither * 50.0, 0.0, 1.0) * clamp(1.0 - abs(yiq_l.x - yiq_r.x) * 5.0, 0.0, 1.0);

    vec3 col = mix(col_m, (col_l + col_m + col_r) * 0.3333, params.ntsc_blur * dither_mask);
    vec3 yiq_final = RGBtoYIQ * col;
    float final_y = yiq_final.x * params.ntsc_bright;

    if (params.sig_noise > 0.0)
        final_y += (hash(vTexCoord + time * 0.01) - 0.5) * params.sig_noise;

    float phase = (vTexCoord.x * params.SourceSize.x) + (vTexCoord.y * params.SourceSize.y * params.ntsc_tilt) + (time * params.ntsc_crawl * 0.5) + (mod(time, 2.0) * params.merge_fields * 3.14);
    float diff = (yiq_m.x - yiq_l.x) * params.custom_art;
    
    vec2 wave = triangle_wave(phase * 2.09);
    vec2 wave_f = triangle_wave(phase * params.fring_val);
    
    vec2 rainbow = wave * diff * params.rb_power * dither_mask;
    vec2 fringing = wave_f * diff * params.fr_str;
    
    vec2 b_off = vec2(ps.x * params.bleed_str, 0.0);
    vec2 chrL = (RGBtoYIQ * texture(Source, vTexCoord - b_off).rgb).yz;
    vec2 chrR = (RGBtoYIQ * texture(Source, vTexCoord + b_off).rgb).yz;
    
    vec2 final_chroma = (mix(yiq_m.yz, (chrL + chrR) * 0.5, 0.5) + rainbow + fringing) * params.sat_boost;
    FragColor = vec4(clamp(YIQtoRGB * vec3(final_y, final_chroma), 0.0, 1.0), 1.0);
}
