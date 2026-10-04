#version 450

#pragma parameter BRIGHTNESS "Signal Brightness" 1.0 0.0 2.0 0.05
#pragma parameter SATURATION "Saturation" 1.0 0.0 2.0 0.05
#pragma parameter COL_BLEED "Chroma Bleed Strength" 1.5 0.0 5.0 0.1
#pragma parameter rb_global_strength "Rainbow Master Power" 1.0 0.0 5.0 0.1
#pragma parameter rb_power "Rainbow Transparency (Mix)" 0.35 0.0 2.0 0.01
#pragma parameter dot_crawl "Dot Crawl Intensity" 0.25 0.0 1.0 0.01
#pragma parameter de_dither "Dither Blending Strength" 0.50 0.0 1.0 0.01
#pragma parameter pi_mod "Subcarrier Phase Angle" 131.5 0.0 360.0 0.1
#pragma parameter vert_scal "Vertical Phase Scale" 0.5 0.0 2.0 0.01
#pragma parameter sig_noise "Signal RF Grain" 0.04 0.0 10.2 0.01

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float BRIGHTNESS;
    float SATURATION;
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

// دالة المثلث البديلة للـ sin/cos
vec2 triangle_wave(float x) {
    vec2 val = abs(fract(vec2(x * 0.159, x * 0.159 + 0.25)) * 2.0 - 1.0) * 2.0 - 1.0;
    return val;
}

// دالة ضجيج خطية سريعة جداً
float hash(vec2 co) { return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453); }

void main() {
    vec3 col_m = texture(Source, vTexCoord).rgb;
    float time = float(params.FrameCount);

    vec2 ps = 1.0 / params.SourceSize.xy;
    vec2 d_off = ps * max(params.de_dither, 1.0);
    vec3 col_l = texture(Source, vTexCoord - d_off).rgb;
    vec3 col_r = texture(Source, vTexCoord + d_off).rgb;

    vec3 yiq_m = RGB_to_YIQ * col_m;
    vec3 yiq_l = RGB_to_YIQ * col_l;
    vec3 yiq_r = RGB_to_YIQ * col_r;

    float edge = abs(yiq_l.x - yiq_m.x) + abs(yiq_r.x - yiq_m.x) - abs(yiq_l.x - yiq_r.x);
    float rb_mask = smoothstep(0.02, 0.22, edge);

    float final_y = mix(yiq_m.x, (yiq_l.x + yiq_m.x + yiq_r.x) * 0.3333, params.de_dither * rb_mask) * params.BRIGHTNESS;

    float x_c = floor(vTexCoord.x * params.SourceSize.x);
    float y_c = floor(vTexCoord.y * params.SourceSize.y);
    float phase = (x_c * params.pi_mod * 0.01745) + (y_c * params.vert_scal * 3.1416) + (mod(time, 2.0) * 3.1416);
    
    // استخدام الموجة المثلثية
    vec2 wave = triangle_wave(phase);
    final_y += wave.x * params.dot_crawl * rb_mask;
    
    if (params.sig_noise > 0.0)
        final_y += (hash(vTexCoord + time * 0.01) - 0.5) * params.sig_noise;

    float i = yiq_m.y;
    float q = yiq_m.z;

    if (params.rb_power > 0.0) {
        i = mix(i, i + wave.x * rb_mask * params.rb_global_strength, params.rb_power);
        q = mix(q, q + wave.y * rb_mask * params.rb_global_strength, params.rb_power);
    }

    if (params.COL_BLEED > 0.0) {
        float bleed_step = ps.x * params.COL_BLEED;
        vec3 col_bleed_l = RGB_to_YIQ * texture(Source, vTexCoord - vec2(bleed_step, 0.0)).rgb;
        vec3 col_bleed_r = RGB_to_YIQ * texture(Source, vTexCoord + vec2(bleed_step, 0.0)).rgb;
        i = mix(i, (col_bleed_l.y + col_bleed_r.y) * 0.5, 0.5);
        q = mix(q, (col_bleed_l.z + col_bleed_r.z) * 0.5, 0.5);
    }

    vec3 final_rgb = YIQ_to_RGB * vec3(final_y, i * params.SATURATION, q * params.SATURATION);
    
    FragColor = vec4(clamp(final_rgb, 0.0, 1.0), 1.0);
}
