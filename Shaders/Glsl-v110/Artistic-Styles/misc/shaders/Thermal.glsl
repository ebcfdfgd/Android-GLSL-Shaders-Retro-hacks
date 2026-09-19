#version 110

#pragma parameter thermal_strength "Thermal Strength" 1.0 0.0 1.0 0.05
#pragma parameter thermal_contrast "Thermal Contrast" 1.15 0.5 2.0 0.05
#pragma parameter thermal_brightness "Thermal Brightness" 0.0 -0.3 0.3 0.02
#pragma parameter thermal_midpoint "Thermal Midpoint" 0.50 0.0 1.0 0.01
#pragma parameter thermal_range "Thermal Range" 1.00 0.1 2.0 0.05
#pragma parameter thermal_noise "Thermal Noise" 0.08 0.0 0.5 0.01
#pragma parameter thermal_random "Thermal Randomness" 0.20 0.0 1.0 0.01
#pragma parameter thermal_edge "Thermal Edge Detail" 0.10 0.0 1.0 0.01

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
uniform mat4 MVPMatrix;
void main(){uv=TexCoord;gl_Position=MVPMatrix*VertexCoord;}
#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif
varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform int FrameCount;
uniform float thermal_strength,thermal_contrast,thermal_brightness,thermal_midpoint,thermal_range;
uniform float thermal_noise,thermal_random,thermal_edge;

float hash(vec2 p,float f){return fract(sin(dot(p+f,vec2(12.9898,78.233)))*43758.5453);}

vec3 thermalPalette(float t){
 t=clamp(t,0.0,1.0);
 vec3 c0=vec3(.02,0.0,.08),c1=vec3(0.0,.20,1.0),c2=vec3(0.0,1.0,1.0),c3=vec3(.10,1.0,.05),c4=vec3(1.0,.90,0.0),c5=vec3(1.0,.18,0.0),c6=vec3(1.0);
 if(t<.16)return mix(c0,c1,t/.16);if(t<.34)return mix(c1,c2,(t-.16)/.18);if(t<.52)return mix(c2,c3,(t-.34)/.18);if(t<.70)return mix(c3,c4,(t-.52)/.18);if(t<.86)return mix(c4,c5,(t-.70)/.16);return mix(c5,c6,(t-.86)/.14);
}

void main(){
 vec3 base=texture2D(Texture,uv).rgb;float lum=dot(base,vec3(.299,.587,.114));
 float t=clamp((lum-thermal_midpoint)*thermal_range+thermal_midpoint,0.0,1.0);
 t=clamp((t-.5)*thermal_contrast+.5+thermal_brightness,0.0,1.0);
 vec2 px=1.0/TextureSize;
 float l=dot(texture2D(Texture,uv-vec2(px.x,0.0)).rgb,vec3(.299,.587,.114));
 float r=dot(texture2D(Texture,uv+vec2(px.x,0.0)).rgb,vec3(.299,.587,.114));
 float u=dot(texture2D(Texture,uv+vec2(0.0,px.y)).rgb,vec3(.299,.587,.114));
 float d=dot(texture2D(Texture,uv-vec2(0.0,px.y)).rgb,vec3(.299,.587,.114));
 float edge=clamp(abs(l-r)+abs(u-d),0.0,1.0)*thermal_edge;t=clamp(t+edge*(.5-t),0.0,1.0);
 float n=hash(floor(uv*TextureSize/2.0),float(FrameCount))-.5;
 float rn=hash(vec2(float(FrameCount)*.013,7.31),float(FrameCount))-.5;
 t=clamp(t+n*thermal_noise+rn*thermal_random*.035,0.0,1.0);
 vec3 thermal=thermalPalette(t);
 vec3 color=mix(base,thermal,thermal_strength);
 gl_FragColor=vec4(clamp(color,0.0,1.0),1.0);
}
#endif