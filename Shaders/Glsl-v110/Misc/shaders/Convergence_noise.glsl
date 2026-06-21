// film noise - converted to #version 110
// license: public domain

#pragma parameter BOGUS_FILM_NOISE "-------------------CONVERG./FILM NOISE-------------------" 0.0 0.0 0.0 0.0
#pragma parameter x_off_r "Conv. X Offset Red" 0.05 -1.0 1.0 0.01
#pragma parameter y_off_r "Conv. Y Offset Red" 0.0 -1.0 1.0 0.01
#pragma parameter x_off_g "Conv. X Offset Green" -0.0 -1.0 1.0 0.01
#pragma parameter y_off_g "Conv. Y Offset Green" -0.0 -1.0 1.0 0.01
#pragma parameter x_off_b "Conv. X Offset Blue" -0.05 -1.0 1.0 0.01
#pragma parameter y_off_b "Conv. Y Offset Blue" 0.0 -1.0 1.0 0.01
#pragma parameter grain_str "Grain Strength" 2.0 0.0 16.0 0.5

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec4 TexCoord;
varying vec2 uv;

uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    uv = TexCoord.xy;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 uv;
uniform sampler2D Texture;

uniform int FrameCount;

uniform float x_off_r;
uniform float y_off_r;
uniform float x_off_g;
uniform float y_off_g;
uniform float x_off_b;
uniform float y_off_b;
uniform float grain_str;

float filmGrain(vec2 uv, float strength, float timer) {
    float x = (uv.x + 4.0) * (uv.y + 4.0) * ((mod(timer, 800.0) + 10.0) * 10.0);
    return (mod((mod(x, 13.0) + 1.0) * (mod(x, 123.0) + 1.0), 0.01) - 0.005) * strength;
}

void main() {
    vec2 red_coord = uv + 0.01 * vec2(x_off_r, y_off_r);
    vec3 red_light = texture2D(Texture, red_coord).rgb;
    
    vec2 green_coord = uv + 0.01 * vec2(x_off_g, y_off_g);
    vec3 green_light = texture2D(Texture, green_coord).rgb;
    
    vec2 blue_coord = uv + 0.01 * vec2(x_off_b, y_off_b);
    vec3 blue_light = texture2D(Texture, blue_coord).rgb;

    vec3 film = vec3(red_light.r, green_light.g, blue_light.b);
    film += filmGrain(uv, grain_str, float(FrameCount));

    gl_FragColor = vec4(film, 1.0);
}
#endif