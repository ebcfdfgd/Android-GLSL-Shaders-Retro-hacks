#version 130

/*
    GBA-LCD-EMULATOR-ULTRA (V16) - GLSL 130
    - Added: Triple Mask Mode (Grid, Dots, Hybrid).
    - Features: Center-faded dots for clarity.
    - Optimized: Performance-friendly logic for G90T.
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

// --- البارامترات المحدثة ---
#pragma parameter MASK_MODE "Mask: 0:Grid, 1:Dots, 2:Hybrid" 2.0 0.0 2.0 1.0
#pragma parameter COLOR_MODE "Profile: 0:Raw, 1:GBA, 2:AGS-101, 3:GBC, 4:DMG" 1.0 0.0 4.0 1.0
#pragma parameter GBA_STRIPING "Interframe Transparency Strength" 0.5 0.0 1.0 0.05
#pragma parameter GBA_AA "Anti-Aliasing Strength" 0.5 0.0 1.0 0.05
#pragma parameter GBA_MOTION "mGBA Motion Blur" 0.3 0.0 1.0 0.05
#pragma parameter GBA_GHOST "LCD Ghosting Intensity" 0.05 0.0 1.0 0.05
#pragma parameter GBA_SAT "Saturation" 1.0 0.0 2.0 0.05
#pragma parameter GBA_BRIGHTNESS "Brightness" 1.0 0.0 2.0 0.05
#pragma parameter GBA_BLACK "Black Level" 0.0 -0.2 0.2 0.01
#pragma parameter GBA_GAMMA "Gamma Correction" 1.1 0.5 2.0 0.05
#pragma parameter MASK_STR "Mask Strength" 0.3 0.0 1.0 0.05
#pragma parameter GBA_GRAIN "Plastic Grain Strength" 0.12 0.0 0.5 0.02
#pragma parameter GBA_BRIGHT_BST "Final Boost" 1.25 1.0 2.0 0.05

#ifdef PARAMETER_UNIFORM
uniform float MASK_MODE, COLOR_MODE, GBA_STRIPING, GBA_AA, GBA_MOTION, GBA_GHOST, GBA_SAT, GBA_BRIGHTNESS, GBA_BLACK, GBA_GAMMA, MASK_STR, GBA_GRAIN, GBA_BRIGHT_BST;
#endif

float plastic_noise(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 apply_color_profile(vec3 col, float mode) {
    if (mode < 0.5) return col; 
    if (mode < 1.5) return vec3(col.r * 0.84 + col.g * 0.16, col.g * 0.72 + col.b * 0.28, col.r * 0.05 + col.g * 0.05 + col.b * 0.90);
    if (mode < 2.5) return vec3(col.r * 0.95 + col.g * 0.05, col.g * 0.95 + col.b * 0.05, col.b * 0.95 + col.r * 0.05);
    if (mode < 3.5) return vec3(col.r * 0.90 + col.g * 0.10, col.r * 0.10 + col.g * 0.90, col.b * 0.90 + col.g * 0.10);
    float gray = dot(col, vec3(0.3, 0.59, 0.11));
    return mix(vec3(0.1, 0.18, 0.08), vec3(0.55, 0.65, 0.1), gray);
}

void main() {
    float time = float(FrameCount);
    vec2 ps = 1.0 / TextureSize;
    
    // [1] محاكاة الحركة (سحبتين لضمان الـ Ghosting والـ Motion)
    float toggle = mod(time, 2.0);
    float striping_off = (GBA_STRIPING * ps.x) * (toggle - 0.5);
    float ghost_osc = sin(time * 0.4) * GBA_GHOST;
    vec2 off = vec2(ps.x * (GBA_AA * 0.5 + GBA_MOTION + ghost_osc) + striping_off, ps.y * GBA_AA * 0.5);
    
    vec3 col = mix(texture(Texture, vTexCoord).rgb, texture(Texture, vTexCoord - off).rgb, 0.5);

    // [2] معالجة الألوان
    col = apply_color_profile(col, COLOR_MODE);
    col = (col - vec3(GBA_BLACK)) * GBA_BRIGHTNESS;
    col = pow(max(col, 0.0), vec3(GBA_GAMMA));
    
    float luma = dot(col, vec3(0.3, 0.59, 0.11));
    col = mix(vec3(luma), col, GBA_SAT);

    // [3] نسيج البلاستيك
    col += (plastic_noise(vGridCoord) - 0.5) * GBA_GRAIN * (1.0 - luma);

    // [4] منطق الماسكات (Grid / Dots / Hybrid)
    vec3 res_mask = vec3(1.0);
    
    // حساب الـ Grid
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

    // اختيار الماسك المفعّل
    if (MASK_MODE < 0.5) {
        res_mask = final_grid;
    } else if (MASK_MODE < 1.5) {
        res_mask = final_dots;
    } else {
        res_mask = final_grid * final_dots;
    }

    // [5] النتيجة النهائية
    vec3 final = col * res_mask * GBA_BRIGHT_BST;

    FragColor = vec4(clamp(final, 0.0, 1.0), 1.0);
}
#endif