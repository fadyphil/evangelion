// LUMEN aurora — the WebGL shader from `eva/redesign.html:776-855`, ported.
//
// Exactly THREE lines differ from the prototype. Each is marked PORT below with
// the original quoted beside it. Everything else is byte-identical, re-indented
// only. Behaviour is preserved: no value, no curve and no control changed.
//
// PORT 1 — precision guard. The original guards with GL_FRAGMENT_PRECISION_HIGH
//   and takes the mediump branch. SkSL never defines that macro, so the guard is
//   replaced rather than kept as dead code.
//   original: #ifdef GL_FRAGMENT_PRECISION_HIGH / highp / #else / mediump / #endif
//
// PORT 2 — fragment coordinates (2 sites). Under Impeller, gl_FragCoord is NOT
//   the GLSL builtin: the compiler aliases it to flutter_FragCoord, fed from
//   iFragCoord, which runtime_effect.vert sets to `position` — the LOCAL,
//   LOGICAL, top-left-origin vertex position (+Y down). The WebGL original reads
//   device pixels with the origin at bottom-left (+Y up). Flip Y to compensate.
//   Measured: identical convention under `flutter test`'s Skia software path, so
//   the flip is correct on both backends and goldens match device orientation.
//
// PORT 3 — fragment output. gl_FragColor is undeclared in SkSL.
//   original: gl_FragColor = vec4(col,1.0);
//
// Verified with the SDK's own compiler, exit 0 and no output:
//   impellerc --sksl --runtime-stage-gles --runtime-stage-gles3
//     --runtime-stage-vulkan --iplr --input=shaders/lumen.frag --input-type=frag
//
// Uniform DECLARATION order below is the prototype's and must stay that way for
// the source to stay a faithful port. The Dart-side `setFloat` slot indices are
// NOT this order — Impeller re-sorts uniforms by SPIR-V location. See
// docs/superpowers/plans/2026-10-13-lumen-redesign.md Task 1.2.
#include <flutter/runtime_effect.glsl>

precision highp float; // PORT 1
uniform vec2  u_res;
uniform float u_time;
uniform vec3  u_hue;
uniform vec3  u_hue2;
uniform vec3  u_hue3;
uniform float u_int;
uniform float u_str;
uniform float u_spike;
uniform float u_spread;
uniform float u_shape;
uniform float u_melt;
uniform float u_dots;
uniform float u_white;
uniform float u_light;
uniform vec2  u_ptr;
uniform float u_ptrI;
float hash(float n){ return fract(sin(n)*43758.5453125); }
float noise1(float x){ float i=floor(x), f=fract(x); f=f*f*(3.0-2.0*f); return mix(hash(i),hash(i+1.0),f); }
float fbm1(float x){ return 0.55*noise1(x)+0.30*noise1(x*2.17+13.7)+0.15*noise1(x*4.31+37.3); }
float fall(float x,float a,float b){ return 1.0-smoothstep(a,b,x); }
out vec4 fragColor; // PORT 3
void main(){
  // PORT 2. WebGL  gl_FragCoord      : device px, origin bottom-left, +Y up
  // Flutter FlutterFragCoord(): local logical px, origin top-left, +Y down
  vec2 _fc=vec2(FlutterFragCoord().x, u_res.y-FlutterFragCoord().y);
  vec2 uv=(_fc-0.5*u_res)/min(u_res.x,u_res.y);
  float t=u_time*0.30;
  float halfH=(u_res.y/min(u_res.x,u_res.y))*0.5;
  float halfW=(u_res.x/min(u_res.x,u_res.y))*0.5;
  float d=0.0, rc=uv.x, body=0.0, core=0.0;
  float shim=0.85+0.15*sin(t*2.2+uv.x*9.0);
  if(u_shape<2.5){
    if(u_shape<0.5){ d=(halfH-0.05)-uv.y; rc=uv.x+d*0.22; }
    else if(u_shape<1.5){ d=uv.y-(-halfH+0.05); rc=uv.x-d*0.22; }
    else { d=halfW-abs(uv.x); rc=uv.y+d*0.22; }
    float spread=u_spread*(1.0+0.08*sin(t*0.8));
    float env=exp(-(d*d)/(spread*spread));
    core=exp(-(d*d)/0.0045);
    float r1=fbm1(rc*5.0+t*0.9);
    float r2=fbm1(rc*11.0-t*0.5+7.3);
    float rays=mix(1.0,0.22+0.78*r1,u_str)*mix(1.0,0.45+0.55*r2,u_str*0.6);
    float edge=(u_shape>1.5)?fall(abs(uv.y),0.95,1.7):fall(abs(uv.x),0.95,1.7);
    body=env*rays*(0.85+0.15*sin(t*2.2+rc*9.0+d*3.0))*edge;
  } else {
    float depth=halfH-uv.y;
    float acc=0.0;
    for(int k=0;k<5;k++){
      float fk=float(k);
      float cx=-0.9+fk*0.45+0.12*sin(t*0.35+fk*2.3)+0.10*(fbm1(fk*9.1+t*0.18)-0.5);
      float tilt=0.22*sin(t*0.21+fk*1.9);
      float x=uv.x-tilt*depth*0.5;
      float w=0.05+0.04*fbm1(fk*3.3+1.0);
      float g=exp(-((x-cx)*(x-cx))/(w*w));
      g*=mix(1.0,0.55+0.45*fbm1(x*16.0+fk*31.0+t*0.4),u_str);
      float len=(0.8+0.6*fbm1(fk*17.7+t*0.12))*halfH*1.5;
      acc+=g*fall(depth,0.0,len);
    }
    body=acc*shim*0.85*fall(abs(uv.x),1.1,1.9);
    d=depth; rc=uv.x;
  }
  float pd=distance(uv,u_ptr);
  body+=exp(-(pd*pd)/0.07)*u_ptrI;
  float I=u_int+u_spike;
  vec3 hue=u_hue;
  if(u_melt>0.5){
    float m1=pow(0.5+0.5*sin(t*0.35+rc*1.3+d*0.7),1.4);
    float m2=pow(0.5+0.5*sin(t*0.28+rc*1.7-d*0.5+2.1),1.4);
    float m3=pow(0.5+0.5*sin(t*0.22-rc*1.1+d*0.9+4.2),1.4);
    float ws=m1+m2+m3+1e-4;
    hue=(u_hue*m1+u_hue2*m2+u_hue3*m3)/ws;
  }
  vec3 emit=hue*body*I + hue*core*0.7*I + vec3(1.0)*pow(body,4.0)*u_white*I*(1.0-u_light);
  if(u_dots>0.5){ vec2 g=fract(_fc/6.0)-0.5; emit*=mix(1.0,0.70+0.30*fall(length(g),0.15,0.45),0.35); } // PORT 2 (site 2)
  vec3 em=emit/(1.0+emit);
  vec3 col=mix(emit, vec3(1.0)-0.55*em, u_light);
  fragColor=vec4(col,1.0); // PORT 3
}