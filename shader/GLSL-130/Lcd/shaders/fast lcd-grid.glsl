#version 130
/* ULTIMATE-LCD-ACCURACY (PRINCE - DUAL GRID CONTROL)
   - NEW: Independent Vertical and Horizontal Grid Control.
   - Precise Subpixel Geometry.
   - Optimized for Mali/Adreno.
*/

#pragma parameter GRID_WIDTH "LCD Grid Width (Vertical)" 0.4 0.0 1.0 0.05
#pragma parameter GRID_HEIGHT "LCD Grid Height (Horizontal)" 0.4 0.0 1.0 0.05
#pragma parameter SUBPIX_STR "Subpixel Strength" 0.6 0.0 1.0 0.05
#pragma parameter BRIGHTNESS_LCD "LCD Brightness" 1.1 1.0 2.0 0.05

#if defined(VERTEX)
#define COMPAT_ATTRIBUTE in
#define COMPAT_VARYING out

COMPAT_ATTRIBUTE vec4 VertexCoord;
COMPAT_ATTRIBUTE vec4 TexCoord;
COMPAT_VARYING vec2 vTexCoord;
COMPAT_VARYING vec2 pix_coord;

uniform mat4 MVPMatrix;
uniform vec2 TextureSize;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord.xy;
    pix_coord = vTexCoord * TextureSize;
}

#elif defined(FRAGMENT)
precision highp float;

#define COMPAT_VARYING in
#define COMPAT_TEXTURE texture
out vec4 FragColor;

COMPAT_VARYING vec2 vTexCoord;
COMPAT_VARYING vec2 pix_coord;
uniform sampler2D Texture;

#ifdef PARAMETER_UNIFORM
uniform float GRID_WIDTH, GRID_HEIGHT, SUBPIX_STR, BRIGHTNESS_LCD;
#endif

void main() {
    // 1. سحب اللون
    vec3 color = COMPAT_TEXTURE(Texture, vTexCoord).rgb;

    // 2. حساب المسافة داخل البكسل
    vec2 subpix_pos = fract(pix_coord);
    
    // --- [ التحكم المنفصل في الشبكة ] ---
    // حساب الخطوط الرأسية والأفقية بشكل مستقل
    float grid_x = smoothstep(0.5 - GRID_WIDTH * 0.5, 0.5 + GRID_WIDTH * 0.5, abs(subpix_pos.x - 0.5));
    float grid_y = smoothstep(0.5 - GRID_HEIGHT * 0.5, 0.5 + GRID_HEIGHT * 0.5, abs(subpix_pos.y - 0.5));
    
    // دمج الخطوط في ماسك واحد
    float mask = 1.0 - max(grid_x, grid_y);

    // 3. محاكاة الـ Subpixel
    float x_offset = subpix_pos.x * 3.0;
    vec3 weights;
    
    weights.r = clamp(1.0 - abs(x_offset - 0.5), 0.0, 1.0);
    weights.g = clamp(1.0 - abs(x_offset - 1.5), 0.0, 1.0) * 0.88;
    weights.b = clamp(1.0 - abs(x_offset - 2.5), 0.0, 1.0) * 1.05;
    
    vec3 subpixel = mix(vec3(1.0), weights * 1.5, SUBPIX_STR);

    // 4. النتيجة النهائية
    color *= mask;
    color *= subpixel;
    color *= BRIGHTNESS_LCD;

    FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
#endif