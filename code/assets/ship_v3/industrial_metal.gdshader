shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 base_color : source_color = vec4(.26,.285,.29,1.);
uniform float base_metallic : hint_range(0.,1.) = .62;
uniform float base_roughness : hint_range(0.,1.) = .77;
uniform sampler2D metal_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform bool has_albedo = false;
uniform float texture_scale = .36;
varying vec3 local_position;
varying vec3 local_normal;
void vertex(){local_position=VERTEX;local_normal=NORMAL;}
void fragment(){
 vec3 w=pow(abs(normalize(local_normal)),vec3(4.));w/=max(w.x+w.y+w.z,.0001);
 vec3 p=local_position*texture_scale;float detail=.4;
 if(has_albedo){vec3 t=texture(metal_albedo,p.yz).rgb*w.x+texture(metal_albedo,p.xz).rgb*w.y+texture(metal_albedo,p.xy).rgb*w.z;detail=clamp(dot(t,vec3(.2126,.7152,.0722))*3.5,.05,.85);}
 // Oxidized/graphite coating has lower reflection than clean polished stock.
 // The triplanar source modulates material response, never baked scene light.
 ALBEDO=base_color.rgb*(.52+.28*detail);METALLIC=base_metallic;ROUGHNESS=clamp(base_roughness+(detail-.4)*.15,.65,.90);SPECULAR=.28;
 vec3 dx=dFdx(VERTEX),dy=dFdy(VERTEX),r1=cross(dy,NORMAL),r2=cross(NORMAL,dx);float determinant=dot(dx,r1);
 if(abs(determinant)>.000001){vec3 gradient=(r1*dFdx(detail)+r2*dFdy(detail))/determinant;NORMAL=normalize(NORMAL-gradient*.0025);}
}
