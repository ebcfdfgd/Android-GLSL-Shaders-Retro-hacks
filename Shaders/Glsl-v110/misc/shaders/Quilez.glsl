#version 110

#pragma parameter BLURSCALEX "Blur Amount X-Axis" 0.30 0.0 1.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    uv = TexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision mediump float;
#endif

varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform float BLURSCALEX;

void main() {
    // حساب موقع البكسل
    vec2 p = uv * TextureSize;
    vec2 i = floor(p) + 0.5;
    vec2 f = p - i;
    
    // معادلة التكبير (Quilez Scaling)
    p = (i + 4.0 * f * f * f) / TextureSize;
    
    // تطبيق الـ Blur Scale على محور X
    p.x = mix(p.x, uv.x, BLURSCALEX);
    
    // إخراج الصورة النهائية
    gl_FragColor = texture2D(Texture, p);
}
#endif