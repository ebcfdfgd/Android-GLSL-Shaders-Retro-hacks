#version 450

/*
    CRT Shader with Atlas Fix, Sharp PNG Mask, and Stronger Scanlines (No Warp / No Vignette)
    RetroArch GLSL Format
*/

#pragma parameter MASK_STR          "Mask Intensity"        0.45 0.0 1.0 0.05
#pragma parameter MASK_W            "Mask Width"            6.0  1.0 64.0 1.0
#pragma parameter MASK_H            "Mask Height"           2.0  1.0 64.0 1.0
#pragma parameter BRIGHT_BOOST      "Brightness Boost"      1.30 0.50 3.00 0.05
#pragma parameter SCANLINE_DEPTH    "Scanline Depth"        0.85 0.00 1.00 0.05
#pragma parameter WHITE_FADE        "Scanline White Fade"   1.00 0.00 2.00 0.10

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float MASK_STR;
	float MASK_W;
	float MASK_H;
	float BRIGHT_BOOST;
	float SCANLINE_DEPTH;
	float WHITE_FADE;
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
layout(set = 0, binding = 3) uniform sampler2D SamplerMask1;

void main() {
    // 1. Texture Atlas Fix & Coordinate Mapping
    vec2 video_scale = params.SourceSize.xy / params.SourceSize.xy;
    vec2 local_uv = uv / video_scale; 

    // Sample texture directly without warping or black borders
    vec3 color = texture(Source, uv).rgb;

    // 2. Enhanced Scan Beam & Bloom
    float game_y = local_uv.y * params.SourceSize.y; 
    float scan_pos = fract(game_y);
    float scanline = sin(scan_pos * 3.14159265); 

    // Perceptual luminance calculation
    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    
    // Using WHITE_FADE to control how aggressively scanlines vanish on bright/white areas
    float fade_curve = pow(luma, max(params.WHITE_FADE, 0.001));
    float current_scan_depth = params.SCANLINE_DEPTH * (1.0 - fade_curve);
    float scan_factor = mix(1.0 - current_scan_depth, 1.0, scanline);
    
    color *= scan_factor;

    // 3. Sharp PNG Mask
    vec2 mask_size = vec2(floor(params.MASK_W), floor(params.MASK_H));
    vec2 m_uv = (mod(floor(gl_FragCoord.xy), mask_size) + 0.5) / mask_size;
    vec3 mcol = texture(SamplerMask1, m_uv).rgb * 1.5;
    color = mix(color, color * mcol, params.MASK_STR);

    // 4. Bright Boost
    color *= params.BRIGHT_BOOST;

    FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
