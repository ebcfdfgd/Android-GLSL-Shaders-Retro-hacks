#version 450

#pragma parameter COL_BLEED "Chroma Bleed Strength" 1.5 0.0 5.0 0.05
#pragma parameter rb_power "Rainbow Strength" 0.15 0.0 2.0 0.01
#pragma parameter rb_size "Rainbow Width" 3.0 0.5 10.0 0.1
#pragma parameter rb_detect "Rainbow Detection" 0.30 0.0 1.0 0.01
#pragma parameter rb_speed "Rainbow Crawl Speed" 0.5 0.0 2.0 0.05
#pragma parameter rb_tilt "Rainbow Diagonal Tilt" 0.5 -2.0 2.0 0.1
#pragma parameter ntsc_blur "Smart Dither 16 Intensity" 0.5 0.0 1.0 0.05

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float COL_BLEED;
    float rb_power;
    float rb_size;
    float rb_detect;
    float rb_speed;
    float rb_tilt;
    float ntsc_blur;
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

// Fast Triangle Wave (sin/cos replacement)
vec2 triangle_wave(float x) {
    vec2 val = abs(fract(vec2(x * 0.159, x * 0.159 + 0.25)) * 2.0 - 1.0) * 2.0 - 1.0;
    return val;
}

void main() {
    vec2 ps = vec2(1.0 / params.SourceSize.x, 0.0);
    float time = mod(float(params.FrameCount), 600.0); 
    
    // 1. SMART DITHER 16
    vec3 cM = texture(Source, vTexCoord).rgb;
    vec3 cL = texture(Source, vTexCoord - ps).rgb;
    vec3 cR = texture(Source, vTexCoord + ps).rgb;
    
    vec3 yiqM = RGB_to_YIQ * cM;
    vec3 yiqL = RGB_to_YIQ * cL;
    vec3 yiqR = RGB_to_YIQ * cR;
    
    float d_mask = clamp(abs(yiqM.x - yiqL.x) * abs(yiqM.x - yiqR.x) * 50.0, 0.0, 1.0);
    d_mask *= clamp(1.0 - abs(yiqL.x - yiqR.x) * 5.0, 0.0, 1.0);
    
    vec3 col = mix(cM, (cL + cM + cR) * 0.3333, params.ntsc_blur * d_mask);
    vec3 yiqCol = RGB_to_YIQ * col;
    float final_y = yiqCol.x;

    // 2. CHROMA ENGINE
    float fI = yiqCol.y;
    float fQ = yiqCol.z;

    vec2 b_off = ps * params.COL_BLEED * 1.5; 
    vec3 bcL = RGB_to_YIQ * texture(Source, vTexCoord - b_off).rgb;
    vec3 bcR = RGB_to_YIQ * texture(Source, vTexCoord + b_off).rgb;
    
    float has_bleed = step(0.001, params.COL_BLEED);
    fI = mix(fI, (bcL.y + bcR.y) * 0.5, 0.7 * has_bleed);
    fQ = mix(fQ, (bcL.z + bcR.z) * 0.5, 0.7 * has_bleed);

    // 3. RAINBOW (NO SIN/COS)
    float edge = abs(yiqM.x - yiqL.x) + abs(yiqM.x - yiqR.x);
    float rb_mask = clamp((edge - params.rb_detect) * 10.0, 0.0, 1.0) * step(0.001, params.rb_power);
    
    float ang = (vTexCoord.x * params.SourceSize.x / params.rb_size) + (vTexCoord.y * params.SourceSize.y * params.rb_tilt) + (time * params.rb_speed);
    
    vec2 wave = triangle_wave(ang);
    fI += wave.x * params.rb_power * rb_mask;
    fQ += wave.y * params.rb_power * rb_mask;

    // 4. FINAL ASSEMBLY
    vec3 res = YIQ_to_RGB * vec3(final_y, fI, fQ);

    FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
