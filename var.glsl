#pragma language glsl3
// variables for frag shaders

uniform vec3  iResolution;           // viewport resolution (in pixels)
uniform float iTime;                 // shader playback time (in seconds)
uniform float iTimeDelta;            // render time (in seconds)
uniform int iFrame;                // shader playback frame
uniform vec4  iMouse;                // mouse pixel coords. xy: current (if MLB down), zw: click
//uniform vec4      iDate;                 // (year, month, day, time in seconds)
