#version 110

/* GBA-LCD-EMULATOR-V16-TURBO
    - OPTIMIZED: Zero-Branching architecture for Color Profiles and Masks.
    - FEATURES: 100% Retained (Ghosting, Motion Blur, Triple Mask, Grain).
    - PERFORMANCE: Pre-calculated Vector Math for maximum FPS.
*/

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

// --- PARAMETERS ---
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

void main() {
    float time = float(FrameCount);
    vec2 ps = 1.0 / TextureSize;
    
    // [1] محاكاة الحركة (Branchless Jitter & Ghosting)
    float toggle = step(0.5, mod(time, 2.0)) - 0.5;
    float striping_off = (GBA_STRIPING * ps.x) * toggle;
    float ghost_osc = sin(time * 0.4) * GBA_GHOST;
    
    vec2 off = vec2(ps.x * (GBA_AA * 0.5 + GBA_MOTION + ghost_osc) + striping_off, ps.y * GBA_AA * 0.5);
    
    // سحب العينات (2-Tap)
    vec3 col = mix(texture2D(Texture, vTexCoord).rgb, texture2D(Texture, vTexCoord - off).rgb, 0.5);

    // [2] نظام البروفايلات الرياضي (Turbo Color Profiles)
    // مصفوفات الألوان مدمجة في مسار واحد
    mat3 mGBA = mat3(0.84, 0.16, 0.00, 0.00, 0.72, 0.28, 0.05, 0.05, 0.90);
    mat3 mAGS = mat3(0.95, 0.05, 0.00, 0.00, 0.95, 0.05, 0.05, 0.00, 0.95);
    mat3 mGBC = mat3(0.90, 0.10, 0.00, 0.10, 0.90, 0.00, 0.00, 0.10, 0.90);

    // اختيار البروفايل بالوزن الرياضي (بدلاً من IF)
    float p1 = step(0.5, COLOR_MODE) * (1.0 - step(1.5, COLOR_MODE));
    float p2 = step(1.5, COLOR_MODE) * (1.0 - step(2.5, COLOR_MODE));
    float p3 = step(2.5, COLOR_MODE) * (1.0 - step(3.5, COLOR_MODE));
    float p4 = step(3.5, COLOR_MODE);

    vec3 col_p = col;
    col_p = mix(col_p, col * mGBA, p1);
    col_p = mix(col_p, col * mAGS, p2);
    col_p = mix(col_p, col * mGBC, p3);
    
    // محاكاة DMG (الشاشة الخضراء)
    float gray = dot(col, vec3(0.3, 0.59, 0.11));
    vec3 dmg = mix(vec3(0.1, 0.18, 0.08), vec3(0.55, 0.65, 0.1), gray);
    col = mix(col_p, dmg, p4);

    // [3] تصحيح الصورة (Linear Path)
    col = (col - GBA_BLACK) * GBA_BRIGHTNESS;
    col = pow(max(col, 0.0), vec3(GBA_GAMMA));
    float luma = dot(col, vec3(0.3, 0.59, 0.11));
    col = mix(vec3(luma), col, GBA_SAT);

    // إضافة الضجيج
    col += (plastic_noise(vGridCoord) - 0.5) * GBA_GRAIN * (1.0 - luma);

    // [4] نظام الماسكات الموحد (Branchless Mask Logic)
    vec3 angle = vGridCoord.xxx * 6.28318 + vec3(0.0, 2.09439, 4.18879);
    vec3 grid_rgb = mix(vec3(1.0), sin(angle) * 0.5 + 0.5, MASK_STR);
    float grid_y = mix(1.0, sin(vGridCoord.y * 6.28318) * 0.5 + 0.5, MASK_STR * 0.6);
    vec3 final_grid = grid_rgb * grid_y;

    float dots_raw = clamp(sin(vGridCoord.x * 6.28318) * sin(vGridCoord.y * 6.28318) * 0.5 + 0.5, 0.0, 1.0);
    vec2 dist = vTexCoord - 0.5;
    float center_fade = clamp(dot(dist, dist) * 4.0, 0.0, 1.0);
    vec3 final_dots = mix(vec3(1.0), vec3(dots_raw), center_fade * MASK_STR);

    // اختيار نمط الماسك رياضياً
    vec3 res_mask = mix(final_grid, final_dots, step(0.5, MASK_MODE));
    res_mask = mix(res_mask, final_grid * final_dots, step(1.5, MASK_MODE));

    // [5] النتيجة النهائية
    gl_FragColor = vec4(clamp(col * res_mask * GBA_BRIGHT_BST, 0.0, 1.0), 1.0);
}
#endif