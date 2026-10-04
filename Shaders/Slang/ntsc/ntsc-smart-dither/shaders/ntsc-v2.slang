#version 450

#pragma parameter SATURATION "NTSC Saturation" 1.0 0.0 2.0 0.05
#pragma parameter BRIGHTNESS "Signal Brightness" 1.0 0.0 2.0 0.05
#pragma parameter ntsc_hue "NTSC Tint (Hue Adjustment)" 0.0 -3.14 3.14 0.05
#pragma parameter rb_power "Rainbow Strength" 0.1 0.0 2.0 0.01
#pragma parameter rb_size "Rainbow Width/Scale" 4.5 0.5 10.0 0.1
#pragma parameter rb_slant "Rainbow Tilt (Manual)" 0.0 -2.0 2.0 0.05
#pragma parameter rb_detect "Rainbow Edge Detect" 0.31 0.0 1.0 0.01
#pragma parameter rb_speed "Rainbow Cycle Speed" 0.1 0.0 1.0 0.01
#pragma parameter rb_sat "Rainbow Saturation" 1.0 0.0 2.0 0.05
#pragma parameter COL_BLEED "Chroma Spread (Bleed)" 5.0 0.0 20.0 0.1
#pragma parameter red_persistence "Red Persistence (Right Smear)" 1.0 0.0 2.5 0.05
#pragma parameter fringe_str "Edge Color Fringing" 0.4 0.0 5.0 0.1
#pragma parameter ntsc_blur "NTSC Dither Blur" 0.5 0.0 1.0 0.05
#pragma parameter jail_str "MD Vertical Jailbars" 0.15 0.0 1.0 0.01
#pragma parameter jail_width "MD Jailbar Spacing" 1.5 0.5 10.0 0.1
#pragma parameter sig_noise "Signal RF Grain" 0.04 0.0 0.5 0.01
#pragma parameter JITTER "Signal Jitter (Shake)" 0.04 0.0 3.0 0.05
#pragma parameter MD_WARM "Analog Warmth" 0.05 -0.2 0.2 0.01
#pragma parameter MD_SHARP "Luma Sharpness" 0.1 0.0 2.0 0.05

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float SATURATION;
    float BRIGHTNESS;
    float ntsc_hue;
    float rb_power;
    float rb_size;
    float rb_slant;
    float rb_detect;
    float rb_speed;
    float rb_sat;
    float COL_BLEED;
    float red_persistence;
    float fringe_str;
    float ntsc_blur;
    float jail_str;
    float jail_width;
    float sig_noise;
    float JITTER;
    float MD_WARM;
    float MD_SHARP;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 hTrig;

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord.xy;
    // تقريب لدالة الدوران بدون sin/cos
    hTrig = vec2(params.ntsc_hue * 0.9, 1.0 - (params.ntsc_hue * params.ntsc_hue * 0.5));
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 hTrig;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

const vec3 kY = vec3(0.2989, 0.5870, 0.1140);
const vec3 kI = vec3(0.5959, -0.2744, -0.3216);
const vec3 kQ = vec3(0.2115, -0.5229, 0.3114);

// دالة المثلث السريعة (بديلة sin/cos)
vec2 triangle_wave(float x) {
    vec2 val = abs(fract(vec2(x * 0.159, x * 0.159 + 0.25)) * 2.0 - 1.0) * 2.0 - 1.0;
    return val;
}

// دالة ضجيج خطي سريع
float hash(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 ps = 1.0 / params.SourceSize.xy;
    float time = float(params.FrameCount);
    vec2 uv = vTexCoord;

    if (params.JITTER > 0.0) uv.x += (hash(vec2(time, uv.y)) - 0.5) * params.JITTER * ps.x;

    vec3 cM = texture(Source, uv).rgb;
    vec3 cL = texture(Source, uv - vec2(ps.x, 0.0)).rgb;
    vec3 cR = texture(Source, uv + vec2(ps.x, 0.0)).rgb;

    float yM = dot(cM, kY);
    float yL = dot(cL, kY);
    float yR = dot(cR, kY);
    
    float is_dither = abs(yM - yL) * abs(yM - yR);
    float d_mask = clamp(is_dither * 50.0, 0.0, 1.0) * clamp(1.0 - abs(yL - yR) * 5.0, 0.0, 1.0);

    vec3 col = (params.ntsc_blur > 0.0) ? mix(cM, (cL + cM + cR) * 0.3333, params.ntsc_blur * d_mask) : cM;
    float y = dot(col, kY);

    float fI = dot(col, kI) * params.SATURATION;
    float fQ = dot(col, kQ) * params.SATURATION;

    if (params.COL_BLEED > 0.1) {
        vec2 b_off = vec2(ps.x * params.COL_BLEED, 0.0);
        vec3 bcL = texture(Source, uv - b_off).rgb;
        vec3 bcR = texture(Source, uv + b_off).rgb;
        fI = mix(fI, (dot(bcL, kI) + dot(bcR, kI)) * 0.5 * params.SATURATION, 0.7);
        fQ = mix(fQ, (dot(bcL, kQ) + dot(bcR, kQ)) * 0.5 * params.SATURATION, 0.7);
        if (params.red_persistence > 0.0) fI = mix(fI, dot(bcL, kI) * params.SATURATION, 0.45 * params.red_persistence);
    }

    if (params.rb_power > 0.0) {
        float ang = (uv.x * params.SourceSize.x / params.rb_size) + (uv.y * params.SourceSize.y * params.rb_slant) + (time * params.rb_speed);
        vec2 wave = triangle_wave(ang);
        fI += wave.x * params.rb_power * d_mask * params.rb_sat;
        fQ += wave.y * params.rb_power * d_mask * params.rb_sat;
    }

    if (params.MD_SHARP > 0.0) y += (yM - yL) * params.MD_SHARP;
    if (params.jail_str > 0.0) y += triangle_wave(uv.x * params.jail_width * 100.0).x * params.jail_str * 0.02;
    if (params.sig_noise > 0.0) y += (fract(uv.x * uv.y * time * 1000.0) - 0.5) * params.sig_noise;
    
    if (params.fringe_str > 0.0) {
        fI += (yM - yR) * params.fringe_str * 0.5;
        fQ -= (yM - yL) * params.fringe_str * 0.3;
    }

    float resI = fI * hTrig.y - fQ * hTrig.x;
    float resQ = fI * hTrig.x + fQ * hTrig.y;

    vec3 res = vec3(
        y + 0.956 * resI + 0.621 * resQ,
        y - 0.272 * resI - 0.647 * resQ,
        y - 1.106 * resI + 1.703 * resQ
    );

    if (params.MD_WARM != 0.0) res.r += params.MD_WARM;
    res *= params.BRIGHTNESS;

    FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
