Shader "Custom/Raymarch_blinn_phong"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _id_figura("Id.S:0 |Ss:1 |InfSph:2 |To:3 |T:4 | TFold:5 |TS: 6 | Mandle: 7", Int) = 0
        _id_AO("ID Ambient Occlusion: NO: 0 | RayStep: 1 | NormalSampling: 2 ", Int) = 0
        _num_normal_samples("Num normal samples", Int) = 5
        _ambient_global("Ambiente Global", Color) = (0,0,0,0)

        _scale_tetra("SCALE TETRA: ",Float) = 1.66

        //Sphere 
        _sphere ("Esfera (centro y radio)", Vector) = (0,0,0,0)
        _id_formula_solidos("U: 1 | I: 2 | RS: 3 | RT: 4 | SmU: 5 | ", Int) = 1

        //Light
        _light_pos ("Posición luz", Vector) = (0,0,0,0) 
        _light_amb ("Ambiental", Color) = (1,1,1,1)
        _light_dif ("Difusa", Color) = (1,1,1,1)
        _light_spe ("Especular", Color) = (1,1,1,1)
        _light_dir ("Dirección", Vector) = (1,1,1,1)
        _light_angle("Angulo" , Float) = 40

        //Material
        _mat_amb ("Material Ambiental", Color) = (1,1,1,1)
        _mat_dif ("Material Difusa", Color) = (1,1,1,1)
        _mat_spe ("Material Especular", Color) = (1,1,1,1)
        _mat_shine("Material Shine", Float) = 1

        //Ray Marching
        SURF_DIST("Surface distance",Float) = 0.0001
        MAX_DIST("Max distance", Float) = 100
        MAX_STEPS("Max steps", Int) = 100
        
    }
    SubShader
    {
        
        Tags { "RenderType"="Opaque" }
        LOD 100
        
        Pass
        {
            CGPROGRAM

            

            #pragma vertex vert
            #pragma fragment frag


            #include "UnityCG.cginc"

            // Hay que declarar todas las variables de properties (aquí¿?) para poder utilizarlas luego 
            // Del ray marching
            int MAX_STEPS  ;
            float MAX_DIST ;
            float SURF_DIST;
            //ID de la figura para cambiarlo desde el properties
            int _id_figura;
            int _id_AO;
            int _num_normal_samples;

            //Sphere con TetraFold
            int _id_formula_solidos;
            float4 _sphere;
            float _scale_tetra;


            //Ambiente global
            fixed4 _ambient_global;
            // Info luz
            fixed4 _light_pos;
            fixed4 _light_amb;
            fixed4 _light_dif;
            fixed4 _light_spe;
            float4 _light_dir;
            float  _light_angle;

            // Info mat
            fixed4 _mat_amb;
            fixed4 _mat_dif;
            fixed4 _mat_spe;
            float  _mat_shine;
            

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };
                     
            // vertex to fragment, la estructura que se envia desde el vertexshader hasta el fragment shader
            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                //el tipo, el nombre, el registro donde se guarda ( el registro tiene que ser distinto a los anteriores)
                float3 ro : TEXCOORD1;
                float3 hitPos : TEXCOORD2;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
             
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.ro = mul(unity_WorldToObject,float4(_WorldSpaceCameraPos,1));
                o.hitPos = v.vertex;
                return o;
            }

            struct Light
            {
                float3 pos;
                float3 Id;
                float3 Ia;
                float3 Is;
                float4 dir;
                float angle;
			};
            struct Mat{
                float3 Id;
                float3 Ia;
                float3 Is;  
                float shine;
			};
            static Light light;
            static Mat mat;

            //Operaciones de Intersección, union, unión suave y diferencia
            float solids_intersection(float distA, float distB) {
                return max(distA, distB);
            }

            float solids_union(float distA, float distB) {
                return min(distA, distB);
            }

            float solids_smooth_union(float distA, float distB) {
                float k = 0.75;
                float h = max(k-abs(distA-distB),0.)/k;
                return min(distA, distB) - pow(h,3.)*k*(1./6.);
            }

            float solids_difference(float distA, float distB) {
                return max(distA, -distB);
            }
            //Para escoger cual de las operaciones de solidos queremos aplicar desde el editor.
            float solids_formula(float distA, float distB){
                switch(_id_formula_solidos){
                    case 1:
                        return solids_union(distA,distB); 
                    case 2:
                        return solids_intersection(distA,distB);
                    case 3:
                        return solids_difference(distA,distB);
                    case 4:
                        return solids_difference(distB,distA);
                    case 5:
                        return solids_smooth_union(distA,distB);
                    default:
                        return solids_difference(distB,distA); 
                }
			}


            float DistSphere(float3 p){
                float r = 0.2;
                float c = float3(-0.4,0,0);
                return length(p-c) - r;
			}

            float DE_tetraedro(float3 z){
            
                int Iterations = 24;
                float Scale = 2.0;
            
                float size= 0.5;
                float3 a1 = float3(1,1,1)  * size;
                float3 a2 = float3(-1,-1,1)* size;
                float3 a3 = float3(1,-1,-1)* size;
                float3 a4 = float3(-1,1,-1)* size;
                float3 c;
                int n = 0;
                float dist, d;
                while (n < Iterations) {
            		    c = a1; dist = length(z-a1);
            	        d = length(z-a2); if (d < dist) { c = a2; dist=d; }
            		    d = length(z-a3); if (d < dist) { c = a3; dist=d; }
		                d = length(z-a4); if (d < dist) { c = a4; dist=d; }
            	    z = Scale*z-c*(Scale-1.0);
            	    n++;
           	    }

	             return length(z) * pow(Scale, float(-n)); 
            }

            float DE_tetraedro_fold(float3 p){
                int Iterations = 23;
                float t = _SinTime.z;//fmod(_Time.z*0.2,1.);
                float Scale = _scale_tetra + t * 0.165;
                float3 offset = float3(1.,1.,1.) * 0.5;
                float r;
                int n = 0;
                while (n < Iterations) {
                   if(p.x+p.y<0) p.xy = -p.yx; // Pliegue 1
                   if(p.x+p.z<0) p.xz = -p.zx; // Pliegue 2
                   if(p.y+p.z<0) p.zy = -p.yz; // Pliegue 3	
                   p = p*Scale - offset*(Scale-1.0);
                   n++;
                }
                return (length(p) ) * pow(Scale, -float(n));
            }

            float GetDistMandlebulb(float3 p) {
                p*=2.;
                int power = 8;
                float3 z = p ;
                float dr = 1.0;
                float r = 0.0;
                for (int i = 0; i < 20; i++) {
                    r = length(z);
                    if (r > 100) break;

                    // convert to polar coordinates
                    float theta = acos(z.z / r);
                    float phi = atan2(z.y, z.x);
                    dr = pow(r, power - 1.0) * power * dr + 1.0;

                    // scale and rotate the point
                    float zr = pow(r, power);
                    theta = theta * power;
                    phi = phi * power;

                    // convert back to cartesian coordinates
                    z = zr * float3(sin(theta) * cos(phi), sin(phi) * sin(theta), cos(theta));
                    z += p;
                }
                return 0.5 * log(r) * r / dr;
            }

            float DistScene1(float3 p){
                // esfera
                float sin_time=_Time.z;
                float3 c = float3(0,0.2*sin_time,0);
                float r = 0.2;
                // plano y = 0
                float planeh = 0.0;

                float ds = length(p-c)-r;
                float dp =100.;// p.y - planeh;
                return min(ds,dp);
			}

            float DistInfSpheres(float3 p){
                

                float t = _Time.y * 1.;
                p-= float3(1.,-0.5,-0.5);
                p-= float3(1.,1.,1.)*t;
                p.xyz = fmod((p.xyz),1.0) + 0.5; // instance on xy-plane
                return length(p)-0.2; 
                /*
                
                float m = 1.0;
                p.xyz = fmod((p.xyz),m) + 0.5; // instance on xy-plane
                float3 c = float3(1.0,1.0,1.0)*2.;
                return length(p-c)-m/5;
                */


                /*
                float dp = p.y + 0.95;
                // no lo mires
                return min(length(p)-0.2,dp);  

                
                float r = 0.2;
                //float t = fmod(_Time.y,70.);
                //float c = float3(-0.3 + t*0.8,0,0);
                float altura = -0.5;
                float d = length(p-c) - r;
                return min(d,p.y+altura);

                float3 pcopy = float3(p.x,p.y,p.z);
                p.xy = fmod((p.xy),1.0) - 0.9; // instance on xy-plane
                return length(p)-0.1;             // sphere DE
                */

			}

            float DistSpheres(float3 p){

                float r1 = _sphere.w * 0.1;
                float c1 = _sphere.xyz;

                float r2 = 0.2;
                float c2 = float3(0,0,0);
                // no se que pasa que aunque cambie c1.y o z  no se mueve, pero con la x si
                float d1 = length(p-c1) - r1;
                float d2 = length(p-c2) - r2;
                
                return solids_formula(d2,d1);

			}

            float DistTetraSphere(float3 p){
                float r1 = _sphere.w * 0.1 + 0.05 + _SinTime.w * 0.075  ;
                float c1 = _sphere.xyz/10.;
                float d1 = length(p-c1) - r1;
                float d2 = DE_tetraedro_fold(p);
                
                return solids_formula(d2,d1);
			}

            float DistToro(float3 p){
                float r1 = 0.4;
                float r2 = 0.1;
                return length(float2(length(p.xy) - r1, p.z)) -r2;
			}

            float GetDist(float3 p) {
                switch(_id_figura){
                    case 0:
                        return DistSphere(p); 
                    case 1:
                        return DistSpheres(p); 
                    case 2:
                        return DistInfSpheres(p);
                    case 3:
                        return DistToro(p);
                    case 4:
                        return DE_tetraedro(p);
                    case 5:
                        return DE_tetraedro_fold(p);
                    case 6:
                        return DistTetraSphere(p);
                    case 7:
                        return GetDistMandlebulb(p);
                    default:
                        return DistSphere(p); 
                }

                return DistToro(p);
			}

            float3 GetNormal(float3 p){
                float2 e = float2(SURF_DIST*5.,0);

                float3 n = normalize(float3(
                    GetDist(p+e.xyy)-GetDist(p-e.xyy),
                    GetDist(p+e.yxy)-GetDist(p-e.yxy),
                    GetDist(p+e.yyx)-GetDist(p-e.yyx)
				));
                return n;
			}

            float2 Compute_AO_raystep(float steps){
                float f = 1. - steps/MAX_STEPS;
                return float2(f,f);
			}

            float2 Compute_AO_normal_sampling(float3 p){

                int num_samples = _num_normal_samples;
                float k = 0.5;
                // n ya viene normalizada ( length(n)=1.)
                float3 n = GetNormal(p);

                float3 sampling_p;  //El punto en el que miraremos las distancias
                float dist_from_p;  //Distancia desde p.
                float dist_DE;      //Distancia del Distance Estimator
                float suma = 0.;
                for (int i = 0; i<num_samples;i++){
                    /* vamos a probar que cada distancia sea el doble de la anterior
                    empezando por 2*SURF_DIST. */
                    dist_from_p = pow(2, i+1 ) * SURF_DIST;
                    //El punto que estamos analizando 
                    sampling_p = p + ( n * dist_from_p);
                    dist_DE = GetDist(sampling_p);
                    suma += dist_DE/dist_from_p;
				}
               
                float f = 1 - 0.1*pow(suma/num_samples,2);
                return float2(f,f);
			}

            float2 Raymarch(float3 ro, float3 rd){
                float DO = 0;
                float DS;

                for ( int i = 0; i < MAX_STEPS; i++){
                    float3 p = ro + DO * rd;
                    DS = GetDist(p);
                    DO += DS; 

                    if(DS < SURF_DIST || DS >= MAX_DIST ){
                        return float2(DO,float(i));
					}
				}
                return float2(MAX_DIST,MAX_STEPS);
			}

            fixed4 frag (v2f i) : SV_Target
            {
                Light llum[1];
                // light segun las Properties 
                light.pos = _light_pos;

                light.Ia = _light_amb;
                light.Id = _light_dif;
                light.Is = _light_spe;
                
                light.dir   = _light_dir;
                light.angle = _light_angle;

                // material segun las Properties
                mat.Ia = _mat_amb;
                mat.Id = _mat_dif;// float4(_SinTime.x*0.5,_SinTime.y*0.5,_SinTime.z*0.5,0.5)+0.5;//
                mat.Is = _mat_spe;
                mat.shine = _mat_shine;

                
                float2 uv = i.uv -0.5;  //Para centrar las coordenadas
                float3 ro = i.ro ;                      //rayo origen
                float3 rd = normalize(i.hitPos - ro);   //rayo dirección

                float2 rm = Raymarch(ro,rd);
                float d = rm.x;         // distancia recorrida
                float steps = rm.y;     // pasos ejecutados en el Raymarch

                fixed4 col = 0;

                if( d <= MAX_DIST ){
                    
                    float3 p = ro + rd * d; // p es elpunto de impacto

                    //calculamos la normal solo para el color.
                    float3 norm = GetNormal(p);
                    // col.rgb =1.- steps/MAX_STEPS;//abs(n);

                    

                    //blinn phong

                    float4 L, H;
                    float4 N = float4(normalize(norm.xyz), 0.0f);

                    float3 compDif, compAmb, compSpe;

                    //for (int i = 0; i < 1; i++) {
                    /* Todo esto no sabia para que era y he decidido dejarlo apartado. Si teneis dudas mirad el 
                    if (llum[i].pos == float4(0.0f)) {
                        L = normalize(-llum[i].dir);

                    } else if (llum[i].angle==0.0f) {
                        L = float4(normalize(llum[i].pos.xyz - pos.xyz),0.0f);

                    } else {


                    */
                        

                        float3 colorG=float3(0.,0.,0.);
                        float4 dirRaig = float4(normalize(ro - light.pos),1.);

                        //REVISAR, No sabia que era y lo he puesto por Properties

                        float4 dirSpot = float4(normalize(light.dir));

                        float angleLlumSuperficie = acos(dot(dirRaig,dirSpot));
                        // otra cosa que no sabia como ponerla y lo he puesto por Properties
                        if (angleLlumSuperficie > light.angle) {
                            L = float4(0.,0.,0.,0.);
                        } else {
                            L = -dirRaig;
                        }
                        
                        H = float4(normalize(L.xyz + normalize(ro-p.xyz)),0.0f);

                        compAmb = light.Ia * float3(mat.Ia.xyz);
                        compDif = float3(mat.Id.xyz) * light.Id * max(dot(L,N),0.0f);
                        compSpe = float3(mat.Is.xyz) * light.Is * pow(max(dot(N,H),0.0f), mat.shine);
                        // aqui me he cargado el calcul atenuació.
                        //colorG+= calculAtenuacio(i) * (compDif + compSpe) + compAmb;

                        //Calculamos el Ambient Occlusion
                        float2 AO_factors;
                        switch (_id_AO){
                            case 1: //Ray Step AO
                                AO_factors = Compute_AO_raystep(steps);
                                break;
                            case 2: //Normal Sampling AO
                                AO_factors = Compute_AO_normal_sampling(p);
                                break;
                            default: // NO AO
                                AO_factors = float2(1.,1.);
                                break;
						}
                        float AOF_mat    = AO_factors.x;
                        float AOF_global = AO_factors.y;

                        
                        compDif += GetNormal(p)*0.5;        
                        colorG+=(compDif + compSpe) + compAmb*AOF_mat;
                    //}

                    colorG = (_ambient_global*AOF_global)*float3(mat.Ia.xyz) + colorG;
                    col = float4(colorG,1.0f);
                }else{
                    // No se calcula el pixel ( como si fuera transparente)
                    discard;
				}
                return col;
            }

            ENDCG
            Cull Off
        }
        
    }
    
}
