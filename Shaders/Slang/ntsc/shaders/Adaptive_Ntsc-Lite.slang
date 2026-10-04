#version 450

#pragma parameter ntsc_scale "Adaptive Scale" 1.0 0.2 3.0 0.05
#pragma parameter ntsc_bright "NTSC Brightness" 1.0 0.0 2.0 0.05
#pragma parameter dither_blur "Luma Dither Blur" 0.5 0.0 1.0 0.05
#pragma parameter ntsc_tilt "NTSC Tilt Value" 0.0 0.0 5.0 0.1
#pragma parameter ntsc_crawl "NTSC Crawl Speed" 0.1 0.0 5.0 0.1
#pragma parameter merge_fields "Waterfall Field Fix" 1.0 0.0 1.0 1.0
#pragma parameter custom_art "Custom Artifacting" 0.5 0.0 2.0 0.05
#pragma parameter fring_val "Custom Fringing Value" 3.35 0.0 5.0 0.05
#pragma parameter rb_power "Rainbow Power" 0.0 0.0 2.0 0.05
#pragma parameter fr_str "Fringing Intensity" 0.5 0.0 2.0 0.05
#pragma parameter sat_boost "Color Saturation" 1.1 0.0 2.0 0.05
#pragma parameter bleed_str "Chroma Bleed" 3.5 0.0 5.0 0.1
#pragma parameter sig_noise "Signal RF Grain" 0.04 0.0 10.2 0.01

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float ntsc_scale;
    float ntsc_bright;
    float dither_blur;
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

// دالة عشوائية خطية (بديلة hash المعتمدة على sin)
float hash(vec2 co) { return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453); }

void main() {
    vec3 col_m = texture(Source, vTexCoord).rgb;
    
    // تحسين الأداء: خروج مبكر إذا لم تكن هناك تأثيرات
    if (params.dither_blur <= 0.0 && params.rb_power <= 0.0 && params.fr_str <= 0.0 && params.bleed_str <= 0.0 && params.sig_noise <= 0.0) {
        FragColor = vec4(clamp(col_m * params.ntsc_bright, 0.0, 1.0), 1.0);
        return;
    }

    float res_scale = 1.0 / params.ntsc_scale;
    vec2 ps = vec2(res_scale / params.SourceSize.x, 1.0 / params.SourceSize.y);
    float time = float(params.FrameCount);
    
    vec3 col_l = texture(Source, vTexCoord - vec2(ps.x, 0.0)).rgb;
    vec3 col_r = texture(Source, vTexCoord + vec2(ps.x, 0.0)).rgb;

    vec3 yiq_m = RGB_to_YIQ * col_m;
    vec3 yiq_l = RGB_to_YIQ * col_l;
    vec3 yiq_r = RGB_to_YIQ * col_r;
    
    float final_y = mix(yiq_m.x, (yiq_l.x + yiq_r.x) * 0.5, params.dither_blur) * params.ntsc_bright;

    if (params.sig_noise > 0.0)
        final_y += (hash(vTexCoord + time * 0.01) - 0.5) * params.sig_noise;

    // phase بدون استخدام pi (تم دمج الثوابت)
    float phase = (vTexCoord.x * params.SourceSize.x + vTexCoord.y * params.SourceSize.y * params.ntsc_tilt + time * params.ntsc_crawl * 0.5 + (mod(time, 2.0) * params.merge_fields * 3.14));
    
    float diff = (yiq_m.x - yiq_l.x) * params.custom_art;
    
    // استخدام الدالة المثلثية الجديدة
    vec2 art_chroma = triangle_wave(phase * 2.09) * diff * params.rb_power;
    vec2 fringing = triangle_wave(phase * params.fring_val) * diff * params.fr_str;
    
    vec2 bleedDx = vec2(ps.x * params.bleed_str, 0.0);
    vec2 chrL = (RGB_to_YIQ * texture(Source, vTexCoord - bleedDx).rgb).yz;
    vec2 chrR = (RGB_to_YIQ * texture(Source, vTexCoord + bleedDx).rgb).yz;
    vec2 base_chroma = mix(yiq_m.yz, (chrL + chrR) * 0.5, 0.5);

    vec2 final_chroma = (base_chroma + art_chroma + fringing) * params.sat_boost;

    vec3 final_rgb = YIQ_to_RGB * vec3(final_y, final_chroma);
    
    FragColor = vec4(clamp(final_rgb, 0.0, 1.0), 1.0);
}
