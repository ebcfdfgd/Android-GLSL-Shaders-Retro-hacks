#version 110

/* STANDALONE-RGB-CONVERGENCE */

#pragma parameter R_OFF_X "Red Offset X" 1.0 -3.0 3.0 0.05
#pragma parameter R_OFF_Y "Red Offset Y" 0.5 -3.0 3.0 0.05
#pragma parameter G_OFF_X "Green Offset X" -1.0 -3.0 3.0 0.05
#pragma parameter G_OFF_Y "Green Offset Y" -0.5 -3.0 3.0 0.05
#pragma parameter B_OFF_X "Blue Offset X" 0.0 -3.0 3.0 0.05
#pragma parameter B_OFF_Y "Blue Offset Y" 1.0 -3.0 3.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord; 
attribute vec2 TexCoord; 
varying vec2 uv; 
uniform mat4 MVPMatrix;
void main() { 
    uv = TexCoord; 
    gl_Position = MVPMatrix * VertexCoord; 
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif
varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize;
#ifdef PARAMETER_UNIFORM
uniform float R_OFF_X, R_OFF_Y, G_OFF_X, G_OFF_Y, B_OFF_X, B_OFF_Y;
#endif

void main() {
    vec2 px = 1.0 / TextureSize;
    
    float r = texture2D(Texture, uv + vec2(R_OFF_X, R_OFF_Y) * px).r;
    float g = texture2D(Texture, uv + vec2(G_OFF_X, G_OFF_Y) * px).g;
    float b = texture2D(Texture, uv + vec2(B_OFF_X, B_OFF_Y) * px).b;
    
    gl_FragColor = vec4(r, g, b, 1.0);
}
#endif