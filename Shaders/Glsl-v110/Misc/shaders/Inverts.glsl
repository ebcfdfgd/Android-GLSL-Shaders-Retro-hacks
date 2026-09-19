#version 110

/* 
   PURE-COLOR-INVERTER
   - PURPOSE: Pure mathematical color inversion to mix with Core Palettes.
   - HOW IT WORKS: Inverts RGB channels instantly (Output = 1.0 - Input).
*/

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

void main() {
    // 1. قراءة اللون القادم من النواة مباشرة بكل تفاصيله وثباته
    vec3 core_col = texture2D(Texture, vTexCoord).rgb;
    
    // 2. معادلة القلب الصافي الحادة بكسل-ببكسل
    vec3 inverted_col = vec3(1.0) - core_col;

    // 3. إخراج الصورة المقلوبة جاهزة للدمج أو لإضافة شيدر التوهج فوقها
    gl_FragColor = vec4(inverted_col, 1.0);
}
#endif