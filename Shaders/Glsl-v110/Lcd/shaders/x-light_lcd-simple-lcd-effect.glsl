#version 110

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord;
varying vec2 vGridCoord;
uniform mat4 MVPMatrix;
uniform vec2 TextureSize;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord.xy;
    vGridCoord = vTexCoord * TextureSize;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 vTexCoord;
varying vec2 vGridCoord;

uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform int FrameCount;

// --- Parameters from both shaders ---

// 0. Profiles and Noise
#pragma parameter PROFILE "Color Profile: 0:Off, 1:mGBA, 2:GBC, 3:SP, 4:GG, 5:GBG, 6:101" 0.0 0.0 6.0 1.0
#pragma parameter LCD_GRAIN "LCD Plastic Grain" 0.15 0.0 2.0 0.05

// 1. Motion and Ghosting
#pragma parameter GHOST_STR "LCD Ghosting" 0.55 0.0 3.0 0.05
#pragma parameter MOTION_OFS "Motion Spread" 0.7 0.0 3.0 0.05
#pragma parameter RESPONSE_LAG "LCD Lag Jitter" 0.4 0.0 3.0 0.05

// 2. Image Processing
#pragma parameter SATURATION "Saturation" 1.0 0.0 2.0 0.05
#pragma parameter BLACK_LEVEL "Black Level" 0.05 0.0 0.5 0.01

// 3. Smoothing and Masks
#pragma parameter EDGE_SOFT "Edge Softening (AA)" 0.3 0.0 1.0 0.05
#pragma parameter MASK_STR "Mask Strength" 0.3 0.0 1.0 0.05
#pragma parameter GBA_BRIGHT_BST "Final Brightness Boost" 1.25 1.0 2.0 0.05

uniform float PROFILE, LCD_GRAIN, GHOST_STR, MOTION_OFS, RESPONSE_LAG;
uniform float SATURATION, EDGE_SOFT, BLACK_LEVEL, MASK_STR, GBA_BRIGHT_BST;

float pseudo_noise(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 ps = 1.0 / TextureSize;
    vec2 uv = vTexCoord;
    float time = float(FrameCount);
    vec3 col = texture2D(Texture, uv).rgb;

    // [1] Ghosting
    if (GHOST_STR > 0.0) {
        float toggle = (mod(time, 2.0) > 0.5) ? 1.0 : -1.0;
        float off = (MOTION_OFS + (RESPONSE_LAG * toggle)) * 0.7;
        vec3 s1 = texture2D(Texture, uv + (ps * off)).rgb;
        vec3 s2 = texture2D(Texture, uv - (ps * off)).rgb;
        col = mix(col, (s1 + s2) * 0.5, GHOST_STR * 0.65);
    }

    // [2] Color Profiles
    if (PROFILE > 0.5) {
        if (PROFILE < 1.5)      col *= mat3(0.84, 0.16, 0.0, 0.08, 0.76, 0.16, 0.08, 0.08, 0.84);
        else if (PROFILE < 2.5) col *= mat3(0.70, 0.20, 0.10, 0.15, 0.70, 0.15, 0.15, 0.10, 0.75);
        else if (PROFILE < 3.5) { col *= mat3(0.75, 0.15, 0.10, 0.10, 0.75, 0.15, 0.15, 0.20, 0.65); col.b += 0.05; }
        else if (PROFILE < 4.5) { col *= mat3(0.85, 0.10, 0.05, 0.10, 0.85, 0.10, 0.05, 0.10, 0.85); col += 0.03; }
        else if (PROFILE < 5.5) { col = mix(vec3(0.05, 0.1, 0.05), vec3(0.6, 0.75, 0.1), dot(col, vec3(0.299, 0.587, 0.114))); }
        else { col *= mat3(0.90, 0.05, 0.05, 0.05, 0.90, 0.05, 0.05, 0.05, 0.95); }
    }

    // [3] LCD Grid Mask
    vec3 angle = vGridCoord.xxx * 6.28318 + vec3(0.0, 2.09439, 4.18879);
    vec3 grid_rgb = mix(vec3(1.0), sin(angle) * 0.5 + 0.5, MASK_STR);
    float grid_y = mix(1.0, sin(vGridCoord.y * 6.28318) * 0.5 + 0.5, MASK_STR * 0.6);
    col *= (grid_rgb * grid_y);

    // [4] Noise, Saturation, Black Level, Softening
    float noise = pseudo_noise(uv * TextureSize);
    col = mix(col, col * (0.9 + 0.2 * noise), LCD_GRAIN);
    col = mix(vec3(dot(col, vec3(0.21, 0.72, 0.07))), col, SATURATION);
    col = clamp(col - BLACK_LEVEL, 0.0, 1.0);
    
    vec3 sN = (texture2D(Texture, uv - ps * vec2(1.0, 0.0)).rgb + texture2D(Texture, uv + ps * vec2(1.0, 0.0)).rgb) * 0.5;
    col = mix(col, sN, EDGE_SOFT * 0.5);

    // [5] Final Output
    gl_FragColor = vec4(clamp(col * GBA_BRIGHT_BST, 0.0, 1.0), 1.0);
}
#endif