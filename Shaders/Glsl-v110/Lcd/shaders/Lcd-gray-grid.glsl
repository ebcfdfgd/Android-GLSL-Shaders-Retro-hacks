#version 110

/* PURE-GAMEBOY-PIXEL-GRID (Scalable Monochrome Grid Edition)
    - FUNCTION: Retains original game colors perfectly while embedding a scalable monochrome pixel grid.
    - VISUALS: Sharp, non-colored scalable grid lines mimicking classic hand-held dot-matrix screens.
    - PERFORMANCE: 100% Branchless, ultra-lightweight, and zero mobile battery drain.
*/

// --- PARAMETERS ---

#pragma parameter GB_GRID "GameBoy Pixel Grid Intensity" 0.30 0.0 1.0 0.05
#pragma parameter GB_ZOOM "GameBoy Mask Zoom / Scale" 2.0 1.0 8.0 1.0

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 TEX0;
uniform mat4 MVPMatrix;

void main() {
    TEX0 = TexCoord;
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 TEX0;
uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;

#ifdef PARAMETER_UNIFORM
uniform float GB_GRID, GB_ZOOM;
#endif

void main() {
    // 1. سحب لون اللعبة أو الصورة الأصلي كما هو بدون أي تلاعب في الألوان
    vec3 color = texture2D(Texture, TEX0).rgb;

    // 2. إحداثيات بكسل الشاشة الصافية مقسومة على عامل الزوم لتكبير الشبكة فقط
    // نستخدم التمرير المباشر لـ GB_ZOOM لمنع تمدد البكسلات بشكل عشوائي
    vec2 pixel_pos = floor(gl_FragCoord.xy / max(1.0, floor(GB_ZOOM)));

    // 3. محاكاة شبكة شاشة الجيم بوي الأصلية الصافية (الآن بحجم قابل للتكبير)
    vec2 grid_calc = step(vec2(1.0), mod(pixel_pos, vec2(2.0)));
    float screen_grid = mix(1.0, grid_calc.x * grid_calc.y, GB_GRID);


    // 4. دمج اللون الأصلي الثابت مع الشبكة المكبرة مباشرة
    gl_FragColor = vec4(color * screen_grid, 1.0);
}
#endif