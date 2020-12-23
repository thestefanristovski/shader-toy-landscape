vec2 hash( vec2 p ) 
{
	p = vec2( dot(p,vec2(127.1,311.7)),
			  dot(p,vec2(269.5,183.3)) );

	return -1.0 + 2.0*fract(sin(p)*43758.5453123);
}

float noise( in vec2 p)
{
    const float K1 = 0.366025404; // (sqrt(3)-1)/2;
    const float K2 = 0.211324865; // (3-sqrt(3))/6;

	vec2 i = floor( p + (p.x+p.y)*K1 );
	
    vec2 a = p - i + (i.x+i.y)*K2;
    vec2 o = step(a.yx,a.xy);    
    vec2 b = a - o + K2;
	vec2 c = a - 1.0 + 2.0*K2;

    vec3 h = max( 0.5-vec3(dot(a,a), dot(b,b), dot(c,c) ), 0.0 );

	vec3 n = h*h*h*h*vec3( dot(a,hash(i+0.0)), dot(b,hash(i+o)), dot(c,hash(i+1.0)));

    return dot( n, vec3(70) );
	
}

float ridged (in vec2 p) 
{
    return 2.0*0.5 - abs(0.5 - noise(p));
}

const int Steps = 2000;
const float Epsilon = 0.01; // Marching epsilon
const float T=0.5;

const float rA=1.0; // Minimum ray marching distance from origin
const float rB=50.0; // Maximum

// Transforms
vec3 rotateY(vec3 p, float a)
{
   //float uv = a/iResolution.x;
   float x = cos(a)*p.x - sin(a)*p.z;
   float y = p.y;
   float z = sin(a)*p.x + cos(a)*p.z;
   p.x = x;
   p.y = y;
   p.z = z;
   
   return p;
}

// Smooth falloff function
// r : small radius
// R : Large radius
float falloff( float r, float R )
{
   float x = clamp(r/R,0.0,1.0);
   float y = (1.0-x*x);
   return y*y*y;
}

// Primitive functions

// Point skeleton
// p : point
// c : center of skeleton
// e : energy associated to skeleton
// R : large radius
float point(vec3 p, vec3 c, float e,float R)
{
   return e*falloff(length(p-c),R);
}


// Blending
// a : field function of left sub-tree
// b : field function of right sub-tree
float Blend(float a,float b)
{
   return a+b;
}

float Terrain(vec2 p, float freq)
{
    float y = noise(freq*p);
    
    return y;
}

float turbulence(vec2 p, float freq, float att, float nboctaves) 
{
    float i;
    float somme=0.0;
    float fatt=1.0;
    for (i=0.0; i<nboctaves; i=i+1.0) {
        somme = somme + fatt*ridged(p*freq);
        fatt= fatt*att;
        freq=freq*2.0;
    }
    return somme;
}

// Potential field of the object
// p : point
float object(vec3 p)
{
   
	//return 2.7*Terrain(p.xz, 0.3)-p.y;
    if(p.y<=0.75) {
    	return p.y;   
    } else if (p.y>2.0 && p.y<2.5){
        return 0.8+turbulence(p.xz + vec2(0.5,0.5)*0.6*iTime,0.11,0.45, 3.0)-p.y;
    } else {
        return turbulence(p.xz, 0.6, 0.4, 6.0)-p.y;
    }
    //return turbulence(p.xz, 0.6, 0.4, 6.0)-p.y;
}

// Calculate object normal
// p : point
vec3 ObjectNormal(in vec3 p )
{
   float eps = 0.0001;
   vec3 n;
   float v = object(p);
   n.x = object( vec3(p.x+eps, p.y, p.z) ) - v;
   n.y = object( vec3(p.x, p.y+eps, p.z) ) - v;
   n.z = object( vec3(p.x, p.y, p.z+eps) ) - v;
   return normalize(n);
}

// Trace ray using ray marching
// o : ray origin
// u : ray direction
// h : hit
// s : Number of steps
float Trace(vec3 o, vec3 u, out bool h,out int s)
{
   h = false;

   // Don't start at the origin
   // instead move a little bit forward
   float t=rA;

   for(int i=0; i<Steps; i++)
   {
      s=i;
      vec3 p = o+t*u;
      float v = object(p);
      // Hit object (1) 
      if (v > 0.0)
      {
         s=i;
         h = true;
         break;
      }
      // Move along ray
      t += Epsilon;  

      // Escape marched far away
      if (t>rB)
      {
         break;
      }
   }
   return t;
}

// Background color
vec3 background(vec3 rd)
{
   vec3 b = mix(vec3(0.8, 0.8, 0.9), vec3(0.6, 0.9, 1.0), rd.y*1.0+0.25);
    return mix(b, vec3(0.0,0.0,0.2), abs(cos(iTime*0.1)) );
}

// Shading and lighting
// p : point,
// n : normal at point
vec3 Shade(vec3 p, vec3 n, int s)
{
   // point light
   const vec3 lightPos1 = vec3(10.0, 5.0, 7.0);
   const vec3 lightPos2 = vec3(1.0, 5.0, 3.0);
   vec3 lightPos = mix(lightPos1, lightPos2, cos(iTime*0.1));
   const vec3 lightColorDay = vec3(1.0, 1.0, 1.0);
    const vec3 lightColorNight = vec3(0.0, 0.0, 0.2);
    vec3 lightColor = mix(lightColorDay, lightColorNight, abs(cos(iTime*0.1)));

   vec3 l = normalize(lightPos - p);

   // Not even Phong shading, use weighted cosine instead for smooth transitions
   float diff = 0.5*(1.0+dot(n, l));

    //CREATE ALPHA THAT GOES FROM PMIN TO PMAX
    vec3 colorBrownDay = vec3(0.5,0.4,0.2);
    vec3 colorBrownNight = vec3(0.1,0.0,0.0);
    vec3 brown = mix(colorBrownDay, colorBrownNight, abs(cos(iTime*0.1)));
    vec3 colorWhiteDay = vec3(1.0,1.0,1.0);
    vec3 colorWhiteNight = vec3(0.4,0.4,0.4);
    vec3 white = mix(colorWhiteDay, colorWhiteNight, abs(cos(iTime*0.1)));
    
    vec3 colorCloudDay = vec3(1.0,1.0,1.0);
    vec3 colorCloudNight = vec3(0.2,0.2,0.4);
    vec3 cloud = mix(colorCloudDay, colorCloudNight, abs(cos(iTime*0.1)));
    
    float alpha;    
    float altmin = 1.1;
    float altmax = 1.40;
    alpha = (p.y-altmin)/(altmax-altmin);
	vec3 col =  ((1.0-alpha)*brown + alpha*white) ;
	
    vec3 c =  0.8*col+0.2*diff*lightColor  ;
    float fog = 0.7*float(s)/(float(Steps-1));
    c = (1.0-fog)*c+fog*white;
    
    c+= 0.2*turbulence(p.xz, 4.0, 0.7, 2.0);
    
   if(mod(p.y,0.05)>=0.045 && p.y>0.75 && p.y<2.0)
   {
       return vec3(0);
   }
    if(p.y<=0.77)
   {
       vec3 waterday = mix(vec3(0.0,0.0,0.89), vec3(0.0,0.0,0.48), turbulence(p.xz, 0.6, 0.4, 2.0));
       vec3 waterday2 = mix(vec3(0.0,0.0,0.48),vec3(0.0,0.0,0.89), turbulence(p.xz, 1.4, 0.6, 2.0));
       vec3 water = mix(waterday,waterday2,abs(cos(iTime)));
       vec3 final = mix(water*1.0, water*0.3, abs(cos(iTime*0.1)));
       return final;
   }
    if(p.y>=2.0) {
       return cloud; 
    }

   return c;
    
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
   vec2 pixel = (gl_FragCoord.xy / iResolution.xy)*2.0-1.0;

   // compute ray origin and direction
   float asp = iResolution.x / iResolution.y;
   vec3 rd = vec3(asp*pixel.x, pixel.y-0.2, -4.0);
   vec3 ro = vec3(0.0, 1.3, 15.0);

   vec2 mouse = iMouse.xy / iResolution.xy;
   float a=-mouse.x*3.0;//iTime*0.25;
   rd.z = rd.z+2.0*mouse.y;
   rd = normalize(rd);
   ro = rotateY(ro, a);
   rd = rotateY(rd, a);

   // Trace ray
   bool hit;

   // Number of stepshttps://www.shadertoy.com/img/themes/classic/play.png
   int s;

   float t = Trace(ro, rd, hit,s);
   vec3 pos=ro+t*rd;
   // Shade background
   vec3 rgb = background(rd);

   if (hit)
   {
      // Compute normal
      vec3 n = ObjectNormal(pos);

      // Shade object with light
      rgb = Shade(pos, n, s);
   }

   fragColor=vec4(rgb, 1.0);
}

