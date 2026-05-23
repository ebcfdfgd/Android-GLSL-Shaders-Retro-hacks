#version 110

/* GBA-LCD-ULTRA-HYBRID (6070 ZOOM + SHIFT + G_STR)
    - ZOOM: Locked Global Zoom from 6070.
    - SHIFT: Added RGB/BRG/GBR cycle.
    - GREEN: Added G_STR to control Green channel intensity.
    - OPTIMIZED: High-speed sin-wave grid.
*/

#pragma parameter GAME_ZOOM "Global Zoom Scale" 0.964 0.5 2.0 0.001
#pragma parameter MASK_SHFT "Mask Color Shift (0, 1, 2)" 0.0 0.0 2.0 1.0
#pragma parameter G_STR "Green Mask Power" 1.0 0.0 2.0 0.05
#pragma parameter MASK_STR "Mask Strength" 0.3 0.0 1.0 0.05
#pragma parameter GBA_BRIGHT_BST "Final Brightness Boost" 1.25 1.0 2.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord.xy;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 vTexCoord;
uniform sampler2D Texture;
uniform vec2 TextureSize;

#ifdef PARAMETER_UNIFORM
uniform float GAME_ZOOM, MASK_SHFT, G_STR, MASK_STR, GBA_BRIGHT_BST;
#endif

void main() {
    // [1] تطبيق زوم 6070
    vec2 uv = (vTexCoord - 0.5) / GAME_ZOOM + 0.5;

    // Bounds Check
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // [2] سحب اللون وإحداثيات الشبكة المقفولة على الزوم
    vec3 col = texture2D(Texture, uv).rgb;
    vec2 grid_coord = uv * TextureSize;

    // [3] حساب الـ RGB Grid باستخدام Sine Waves
    // 6.28318 = 2 * PI
    // تم إضافة G_STR للتحكم في القناة الخضراء (القناة الثانية في الـ angle)
    vec3 angle = grid_coord.xxx * 6.28318 + vec3(0.0, 2.09439, 4.18879);
    vec3 w = sin(angle) * 0.5 + 0.5;
    
    // تطبيق قوة الأخضر
    w.g *= G_STR;

    // [4] نظام الشفت (SHIFT)
    vec3 shifted_w;
    if (MASK_SHFT < 0.5) {
        shifted_w = w.rgb; // RGB
    } else if (MASK_SHFT < 1.5) {
        shifted_w = w.brg; // BRG
    } else {
        shifted_w = w.gbr; // GBR
    }

    vec3 grid_rgb = mix(vec3(1.0), shifted_w, MASK_STR);
    float grid_y = mix(1.0, sin(grid_coord.y * 6.28318) * 0.5 + 0.5, MASK_STR * 0.6);
    vec3 final_grid = grid_rgb * grid_y;

    // [5] النتيجة النهائية
    gl_FragColor = vec4(clamp(col * final_grid * GBA_BRIGHT_BST, 0.0, 1.0), 1.0);
}
#endif