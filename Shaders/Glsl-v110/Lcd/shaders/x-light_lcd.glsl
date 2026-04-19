#version 110

/* GBA-LCD-ULTRA-LIGHT
    - STRIPPED: Removed Gamma, Black Level, Saturation, and Brightness.
    - SPEED: Zero-Branching (No IF statements).
    - OPTIMIZED: Single texture fetch with pure hardware-accelerated math.
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

// --- البارامترات المتبقية للتحكم الأساسي ---
#pragma parameter MASK_MODE "Mask: 0:Grid, 1:Dots, 2:Hybrid" 2.0 0.0 2.0 1.0
#pragma parameter MASK_STR "Mask Strength" 0.3 0.0 1.0 0.05
#pragma parameter GBA_GRAIN "Plastic Grain Strength" 0.12 0.0 0.5 0.02
#pragma parameter GBA_BRIGHT_BST "Final Brightness Boost" 1.25 1.0 2.0 0.05

#ifdef PARAMETER_UNIFORM
uniform float MASK_MODE, MASK_STR, GBA_GRAIN, GBA_BRIGHT_BST;
#endif

float plastic_noise(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    // [1] سحب اللون الخام (Raw Color)
    vec3 col = texture2D(Texture, vTexCoord).rgb;

    // [2] إضافة الضجيج (Grain) - تبسيط الحسابات للسرعة
    col += (plastic_noise(vGridCoord) - 0.5) * GBA_GRAIN;

    // [3] حساب الشبكة (Grid) - 6.28318 = 2 * PI
    vec3 angle = vGridCoord.xxx * 6.28318 + vec3(0.0, 2.09439, 4.18879);
    vec3 grid_rgb = mix(vec3(1.0), sin(angle) * 0.5 + 0.5, MASK_STR);
    float grid_y = mix(1.0, sin(vGridCoord.y * 6.28318) * 0.5 + 0.5, MASK_STR * 0.6);
    vec3 final_grid = grid_rgb * grid_y;

    // [4] حساب النقاط (Dots)
    float dots_raw = sin(vGridCoord.x * 6.28318) * sin(vGridCoord.y * 6.28318);
    dots_raw = clamp(dots_raw * 0.5 + 0.5, 0.0, 1.0);
    vec3 final_dots = mix(vec3(1.0), vec3(dots_raw), MASK_STR);

    // [5] اختيار النمط رياضياً (Branchless Mode Selection)
    // بدلاً من IF، نستخدم mix و step لاختيار المسار البرمجي الأسرع
    vec3 mask = mix(final_grid, final_dots, step(0.5, MASK_MODE));
    mask = mix(mask, final_grid * final_dots, step(1.5, MASK_MODE));

    // [6] الدمج النهائي
    gl_FragColor = vec4(clamp(col * mask * GBA_BRIGHT_BST, 0.0, 1.0), 1.0);
}
#endif