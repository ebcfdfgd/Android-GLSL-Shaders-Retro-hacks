#version 110

/* GBA-ULTIMATE-HYBRID-PRO (V3.1 - Backported to 110)
    - FIXED: 103 Radial Vignette centering and aspect ratio scaling.
    - UPDATED: Radial gradient logic to prevent "one-side" bias.
    - PERFORMANCE: Optimized for GLES 2.0 / Mali / Adreno.
*/

// --- 1. Mask Controls ---
#pragma parameter MASK_MODE "Mask: 0:Grid, 1:Dots, 2:Hybrid" 2.0 0.0 2.0 1.0
#pragma parameter MASK_STR "Mask Strength" 0.3 0.0 1.0 0.05

// --- 2. Analog & Retro FX ---
#pragma parameter ANALOG_SOFT "Analog Edge Softness" 0.30 0.0 1.0 0.05
#pragma parameter CHROMA_STR "Chroma Bleed Strength" 0.15 0.0 1.0 0.05
#pragma parameter GBA_STRIPING "Interframe Transparency" 0.5 0.0 1.0 0.05

// --- 3. Vignette (Corrected Radial Formula) ---
#pragma parameter v_amount "Vignette Strength" 0.2 0.0 1.0 0.05
#pragma parameter v_softness "Vignette Radius" 0.80 0.1 1.5 0.05

// --- 4. System Selector ---
#pragma parameter COLOR_MODE "Profile: 0:Raw, 1:GBA, 2:GBC, 3:GB, 4:101" 1.0 0.0 4.0 1.0

// --- 5. Color Balance & Light ---
#pragma parameter GREEN_BAL "Green Tint Reduction" 0.30 0.0 1.0 0.05
#pragma parameter GBA_COLOR "Hardware Mix Strength" 0.75 0.0 1.0 0.05
#pragma parameter GBA_SAT "Saturation Boost" 1.35 0.0 2.0 0.05
#pragma parameter BRIGHT "Backlight Boost" 1.25 1.0 2.0 0.05
#pragma parameter GBA_BRIGHT_BST "Final Boost (Mask)" 1.25 1.0 2.0 0.05

// --- 6. Hardware Feel ---
#pragma parameter GBA_GHOST "LCD Ghosting Intensity" 0.35 0.0 1.0 0.05
#pragma parameter GBA_GRAIN "Plastic Grain Strength" 0.10 0.0 0.5 0.02
#pragma parameter GBA_INK "LCD Ink Black" 0.05 0.0 0.20 0.01
#pragma parameter GBA_GAM "Screen Gamma" 1.10 0.5 2.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 TEX0;
varying vec2 vGridCoord;
uniform mat4 MVPMatrix;
uniform vec2 TextureSize;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    TEX0 = TexCoord.xy;
    vGridCoord = TEX0 * TextureSize;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 TEX0;
varying vec2 vGridCoord;
uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize, OutputSize;
uniform int FrameCount;

#ifdef PARAMETER_UNIFORM
uniform float MASK_MODE, MASK_STR, GBA_BRIGHT_BST, CHROMA_STR, GBA_STRIPING;
uniform float ANALOG_SOFT, GBA_GRAIN, COLOR_MODE, GREEN_BAL, GBA_COLOR, GBA_SAT, BRIGHT, GBA_GHOST, GBA_INK, GBA_GAM;
uniform float v_amount, v_softness;
#endif

float plastic_noise(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 ps = 1.0 / TextureSize;
    float time = float(FrameCount);
    
    // محاكاة حركة البكسلات
    float toggle = mod(time, 2.0);
    float striping = (GBA_STRIPING * ps.x) * (toggle - 0.5);
    float ghost_osc = sin(time * 0.4) * GBA_GHOST * 0.1;
    
    float soft = ANALOG_SOFT * 0.5;
    float chroma = CHROMA_STR * 0.4;

    // [1] Core Sampling (Backported to texture2D)
    vec3 col_center = texture2D(Texture, TEX0).rgb;
    float r_sample = texture2D(Texture, TEX0 - ps * (soft + chroma + ghost_osc) + striping).r;
    float b_sample = texture2D(Texture, TEX0 + ps * (soft + chroma) + striping).b;
    float g_sample = (texture2D(Texture, TEX0 - ps * soft).g + texture2D(Texture, TEX0 + ps * soft).g) * 0.5;
    
    vec3 res = mix(col_center, vec3(r_sample, g_sample, b_sample), ANALOG_SOFT);
    vec3 col_ghost = texture2D(Texture, TEX0 - ps * (GBA_GHOST * 0.5 + ghost_osc)).rgb;
    res = mix(res, col_ghost, GBA_GHOST * 0.4);

    // [2] Color Profiles (Regional Calibration)
    vec3 target_mat;
    if (COLOR_MODE < 0.5) {
        target_mat = res;
    } else if (COLOR_MODE < 1.5) {
        // GBA Profile
        target_mat = vec3(res.r * 0.82 + res.g * 0.18, mix(res.g * 0.70 + res.b * 0.30, res.g, GREEN_BAL), res.r * 0.05 + res.b * 0.95);
    } else if (COLOR_MODE < 2.5) {
        // GBC Profile
        target_mat = vec3(res.r * 0.70 + res.g * 0.30, res.r * 0.10 + res.g * 0.80 + res.b * 0.10, res.r * 0.05 + res.g * 0.15 + res.b * 0.80);
    } else if (COLOR_MODE < 3.5) {
        // Game Boy DMG (Classic Green)
        float gb_luma = dot(res, vec3(0.3, 0.59, 0.11));
        target_mat = mix(vec3(0.1, 0.15, 0.05), vec3(0.6, 0.7, 0.1), gb_luma);
    } else {
        // AGS-101 Profile
        target_mat = vec3(res.r * 0.95 + res.g * 0.05, res.r * 0.02 + res.g * 0.95 + res.b * 0.03, res.r * 0.05 + res.b * 0.95);
    }
    
    res = mix(res, target_mat, GBA_COLOR);

    // [3] LCD Effects
    float luma = dot(res, vec3(0.299, 0.587, 0.114));
    res = mix(vec3(luma), res, GBA_SAT);
    res += (plastic_noise(vGridCoord) - 0.5) * GBA_GRAIN * (1.2 - luma);
    res = max(res, vec3(GBA_INK));
    res = pow(max(res, 0.0), vec3(1.0 / GBA_GAM));

    // [4] Mask Engine (Hybrid Logic)
    vec3 mask = vec3(1.0);
    vec3 angle = vGridCoord.xxx * 6.28318 + vec3(0.0, 2.09439, 4.18879);
    vec3 grid = mix(vec3(1.0), sin(angle) * 0.5 + 0.5, MASK_STR);
    float grid_y = mix(1.0, sin(vGridCoord.y * 6.28318) * 0.5 + 0.5, MASK_STR * 0.6);
    vec3 final_grid = grid * grid_y;

    float dots_raw = sin(vGridCoord.x * 6.28318) * sin(vGridCoord.y * 6.28318);
    dots_raw = clamp(dots_raw * 0.5 + 0.5, 0.0, 1.0);
    vec3 final_dots = mix(vec3(1.0), vec3(dots_raw), MASK_STR);

    if (MASK_MODE < 0.5) mask = final_grid;
    else if (MASK_MODE < 1.5) mask = final_dots;
    else mask = final_grid * final_dots;

    // [5] --- [Fixed 103 Radial Vignette] ---
    // تصحيح حسابات المركز لضمان الدوران حول منتصف الشاشة الفعلي
    vec2 v_uv = (TEX0.xy * (TextureSize / InputSize)) - 0.5;
    float dist = length(v_uv); 
    
    // التعتيم الدائري المحسّن
    float vig = smoothstep(v_softness, v_softness - 0.7, dist);
    float vig_final = mix(1.0, vig, v_amount);
    
    vec3 final_rgb = res * mask * BRIGHT * GBA_BRIGHT_BST * vig_final;
    
    gl_FragColor = vec4(clamp(final_rgb, 0.0, 1.0), 1.0);
}
#endif