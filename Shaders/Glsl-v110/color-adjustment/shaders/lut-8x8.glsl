#version 110

#pragma parameter LUT_OPACITY "LUT Opacity" 1.0 0.0 1.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord; attribute vec4 TexCoord; varying vec2 texCoord; uniform mat4 MVPMatrix;
void main() { gl_Position = MVPMatrix * VertexCoord; texCoord = TexCoord.xy; }

#elif defined(FRAGMENT)
precision mediump float;
varying vec2 texCoord;
uniform sampler2D Texture;
uniform sampler2D SamplerLUT1;
uniform float LUT_OPACITY;

// دالة تطبيق الـ LUT (تستقبل تكتشر 64x64 Grid)
vec3 apply_lut(sampler2D tex, vec3 color) {
    float size = 64.0;
    float blue = color.b * (size - 1.0);
    vec2 quad;
    quad.y = floor(blue / 8.0);
    quad.x = floor(blue) - (quad.y * 8.0);
    
    vec2 texPos;
    texPos.x = (quad.x * size + color.r * (size - 1.0)) / (size * 8.0);
    texPos.y = (quad.y * size + color.g * (size - 1.0)) / (size * 8.0);
    
    return texture2D(tex, texPos).rgb;
}

void main() {
    vec3 color = texture2D(Texture, texCoord).rgb;
    
    // تطبيق الـ LUT
    vec3 l_color = apply_lut(SamplerLUT1, clamp(color, 0.0, 1.0));
    
    // خلط الألوان الأصلية مع ألوان الـ LUT
    vec3 final_color = mix(color, l_color, LUT_OPACITY);
    
    gl_FragColor = vec4(final_color, 1.0);
}
#endif