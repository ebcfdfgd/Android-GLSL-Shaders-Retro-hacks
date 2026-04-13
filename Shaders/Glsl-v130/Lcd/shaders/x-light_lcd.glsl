#version 130

/*
    GBA-LCD-ULTIMATE (3-in-1 Hybrid) - GLSL 130
    - Mode 0: Classic Grid (TV Style).
    - Mode 1: Dot Mask (Handheld Style - Clear Center).
    - Mode 2: Hybrid (Grid + Dots - The Real GBA Look).
    - Performance: Still 1-Tap (Single Texture Fetch).
*/

#if defined(VERTEX)
in vec4 VertexCoord;
in vec2 TexCoord;
out vec2 vTexCoord;
out vec2 vGridCoord;
uniform mat4 MVPMatrix;
uniform vec2 TextureSize;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord.xy;
    vGridCoord = vTexCoord * TextureSize;
}

#elif defined(FRAGMENT)
precision highp float;

in vec2 vTexCoord;
in vec2 vGridCoord;
out vec4 FragColor;

uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform int FrameCount;

// --- البارامترات ---
#pragma parameter MASK_MODE "Mask: 0:Grid, 1:Dots, 2:Hybrid" 2.0 0.0 2.0 1.0
#pragma parameter GBA_SAT "Saturation" 1.1 0.0 2.0 0.05
#pragma parameter GBA_BRIGHTNESS "Brightness" 1.0 0.0 2.0 0.05
#pragma parameter GBA_BLACK "Black Level" 0.0 -0.2 0.2 0.01
#pragma parameter GBA_GAMMA "Gamma Correction" 1.0 0.5 2.0 0.05
#pragma parameter MASK_STR "Mask Strength" 0.3 0.0 1.0 0.05
#pragma parameter GBA_GRAIN "Plastic Grain Strength" 0.12 0.0 0.5 0.02
#pragma parameter GBA_BRIGHT_BST "Final Boost" 1.25 1.0 2.0 0.05

#ifdef PARAMETER_UNIFORM
uniform float MASK_MODE, GBA_SAT, GBA_BRIGHTNESS, GBA_BLACK, GBA_GAMMA, MASK_STR, GBA_GRAIN, GBA_BRIGHT_BST;
#endif

float plastic_noise(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    // [1] سحب الصورة (1-Tap)
    vec3 col = texture(Texture, vTexCoord).rgb;

    // [2] معالجة الألوان
    col = (col - vec3(GBA_BLACK)) * GBA_BRIGHTNESS;
    col = pow(max(col, 0.0), vec3(GBA_GAMMA));
    float luma = dot(col, vec3(0.3, 0.59, 0.11));
    col = mix(vec3(luma), col, GBA_SAT);

    // [3] نسيج البلاستيك
    col += (plastic_noise(vGridCoord) - 0.5) * GBA_GRAIN * (1.0 - luma);

    // [4] منطق الماسكات المتعددة
    vec3 mask = vec3(1.0);
    
    // حساب الـ Grid الأساسي
    vec3 angle = vGridCoord.xxx * 6.28318 + vec3(0.0, 2.09439, 4.18879);
    vec3 grid = mix(vec3(1.0), sin(angle) * 0.5 + 0.5, MASK_STR);
    float grid_y = mix(1.0, sin(vGridCoord.y * 6.28318) * 0.5 + 0.5, MASK_STR * 0.6);
    vec3 final_grid = grid * grid_y;

    // حساب الـ Dots المفرغة من النص
    float dots_raw = sin(vGridCoord.x * 6.28318) * sin(vGridCoord.y * 6.28318);
    dots_raw = clamp(dots_raw * 0.5 + 0.5, 0.0, 1.0);
    vec2 dist = vTexCoord - 0.5;
    float center_fade = clamp(dot(dist, dist) * 4.0, 0.0, 1.0);
    vec3 final_dots = mix(vec3(1.0), vec3(dots_raw), center_fade * MASK_STR);

    // اختيار النمط بناءً على MASK_MODE
    if (MASK_MODE < 0.5) {
        mask = final_grid; // Mode 0
    } else if (MASK_MODE < 1.5) {
        mask = final_dots; // Mode 1
    } else {
        mask = final_grid * final_dots; // Mode 2 (Hybrid)
    }

    // [5] النتيجة النهائية
    vec3 final_rgb = col * mask * GBA_BRIGHT_BST;
    FragColor = vec4(clamp(final_rgb, 0.0, 1.0), 1.0);
}
#endif