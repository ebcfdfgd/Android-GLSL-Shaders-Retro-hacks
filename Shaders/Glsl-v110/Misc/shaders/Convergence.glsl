// Convergence only - adapted for #version 110

#pragma parameter x_off_r "Conv. X Offset Red" 0.05 -1.0 1.0 0.01
#pragma parameter y_off_r "Conv. Y Offset Red" 0.0 -1.0 1.0 0.01
#pragma parameter x_off_g "Conv. X Offset Green" -0.0 -1.0 1.0 0.01
#pragma parameter y_off_g "Conv. Y Offset Green" -0.0 -1.0 1.0 0.01
#pragma parameter x_off_b "Conv. X Offset Blue" -0.05 -1.0 1.0 0.01
#pragma parameter y_off_b "Conv. Y Offset Blue" 0.0 -1.0 1.0 0.01

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

// Convergence Uniforms
uniform float x_off_r;
uniform float y_off_r;
uniform float x_off_g;
uniform float y_off_g;
uniform float x_off_b;
uniform float y_off_b;

void main() {
    // Convergence logic
    vec2 red_coord = uv + 0.01 * vec2(x_off_r, y_off_r);
    vec3 red_light = texture2D(Texture, red_coord).rgb;
    
    vec2 green_coord = uv + 0.01 * vec2(x_off_g, y_off_g);
    vec3 green_light = texture2D(Texture, green_coord).rgb;
    
    vec2 blue_coord = uv + 0.01 * vec2(x_off_b, y_off_b);
    vec3 blue_light = texture2D(Texture, blue_coord).rgb;

    // Combine channels
    vec3 res = vec3(red_light.r, green_light.g, blue_light.b);

    gl_FragColor = vec4(res, 1.0);
}
#endif