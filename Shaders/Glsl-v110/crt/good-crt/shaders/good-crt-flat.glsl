// #version 110

/*
    CRT Shader with Atlas Fix, PAS700 Procedural RGB Mask, and Stronger Scanlines (No Warp / No Vignette)
    RetroArch GLSL Format
*/

#pragma parameter MASK_W            "PAS700 Mask Width"     3.0  1.0  16.0 1.0
#pragma parameter MASK_STRENGTH     "Mask Strength"         0.50 0.00 1.00 0.05
#pragma parameter BRIGHT_BOOST      "Brightness Boost"      1.30 0.50 3.00 0.05
#pragma parameter SCANLINE_DEPTH    "Scanline Depth"        0.85 0.00 1.00 0.05
#pragma parameter WHITE_FADE        "Scanline White Fade"   1.00 0.00 2.00 0.10

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
uniform mat4 MVPMatrix;

void main() {
    uv = TexCoord;
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform vec2 InputSize;

#ifdef PARAMETER_UNIFORM
uniform float MASK_W;
uniform float MASK_STRENGTH;
uniform float BRIGHT_BOOST;
uniform float SCANLINE_DEPTH;
uniform float WHITE_FADE;
#else
#define MASK_W 6.0
#define MASK_STRENGTH 0.5
#define BRIGHT_BOOST 1.3
#define SCANLINE_DEPTH 0.85
#define WHITE_FADE 1.0
#endif

void main() {
    // 1. Texture Atlas Fix & Coordinate Mapping
    vec2 video_scale = InputSize / TextureSize;
    vec2 local_uv = uv / video_scale; 

    // Sample texture directly without warping or black borders
    vec3 color = texture2D(Texture, uv).rgb;

    // 2. Enhanced Scan Beam & Bloom
    float game_y = local_uv.y * InputSize.y; 
    float scan_pos = fract(game_y);
    float scanline = sin(scan_pos * 3.14159265); 

    // Perceptual luminance calculation
    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    
    // Using WHITE_FADE to control how aggressively scanlines vanish on bright/white areas
    float fade_curve = pow(luma, max(WHITE_FADE, 0.001));
    float current_scan_depth = SCANLINE_DEPTH * (1.0 - fade_curve);
    float scan_factor = mix(1.0 - current_scan_depth, 1.0, scanline);
    
    color *= scan_factor;

    // 3. PAS700 Procedural RGB Mask
    float W = floor(MASK_W);
    float pos = mod(gl_FragCoord.x, W) / W;
    vec3 mcol = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), 0.0, 1.0);
    color = mix(color, color * mcol, MASK_STRENGTH);

    // 4. Bright Boost
    color *= BRIGHT_BOOST;

    gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
#endif