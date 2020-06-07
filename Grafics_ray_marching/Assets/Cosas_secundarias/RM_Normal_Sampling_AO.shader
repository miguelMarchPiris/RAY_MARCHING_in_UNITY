Shader "Unlit/Raymarch"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
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

            // Mis defines
            #define MAX_STEPS 100
            #define MAX_DIST 100.
            #define SURF_DIST 1e-4

            

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
                //el tipo, el nombre, el registro donde se guarda
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

            float DistSphere(float3 p){
                float r = 0.2;
                float c = float3(-0.4,0,0);
                return length(p-c) - r;
			}

            float DE(float3 z){
            
            int Iterations = 25;
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
                float dp =100.;// p.y + 0.95;
                
                p.xy = fmod((p.xy),1.0) + 0.5; // instance on xy-plane
                return min(length(p)-0.2,dp);  

                
                float r = 0.2;
                float c = float3(-0.3,0,0);
                float altura = -0.5;
                float d = length(p-c) - r;
                return min(d,p.y+altura);

                float3 pcopy = float3(p.x,p.y,p.z);
                p.xy = fmod((p.xy),1.0) - 0.9; // instance on xy-plane
                return length(p)-0.1;             // sphere DE
			}

            float DistSpheres(float3 p){
                float r1 = 0.2;
                float r2 = 0.2;
                float c1 = float3(0.2,0,0);
                float c2 = float3(0,0,0);
                float d1 = length(p-c1) - r1;
                float d2 = length(p-c2) - r2;

                return min(d1,d2);

                // return min(length(p-c1) - r1, length(p-c2) - r2);
			}

            float DistToro(float3 p){
                float r1 = 0.4;
                float r2 = 0.1;
                return length(float2(length(p.xy) - r1, p.z)) -r2;
			}

            float GetDist(float3 p) {
                return DE(p);
			}

            float3 GetNormal(float3 p){
                float2 e = float2(SURF_DIST*5.,0);
                
                /*float3 n = GetDist(p) - float3(
                    GetDist(p-e.xyy),
                    GetDist(p-e.yxy),
                    GetDist(p-e.yyx)
                    );
                return normalize(n);
                */

                float3 n = normalize(float3(
                    GetDist(p+e.xyy)-GetDist(p-e.xyy),
                    GetDist(p+e.yxy)-GetDist(p-e.yxy),
                    GetDist(p+e.yyx)-GetDist(p-e.yyx)
				));
                return n;
			}



            float Raymarch(float3 ro, float3 rd){
                float DO = 0;
                float DS;

                for ( int i = 0; i < MAX_STEPS; i++){
                    float3 p = ro + DO * rd;
                    DS = GetDist(p);
                    DO += DS; 

                    if(DS < SURF_DIST || DS >= MAX_DIST ){
                        return DO;
					}
				}
                return MAX_DIST;
			}

            fixed4 frag (v2f i) : SV_Target
            {
                float2 uv = i.uv -0.5;
                float3 ro = i.ro ;
                float3 rd = normalize(i.hitPos - ro);//normalize(float3(uv.x,uv.y,1));

                float d = Raymarch(ro,rd);

                fixed4 col = 0;

                if( d <= MAX_DIST ){
                    // p es elpunto de impacto
                    float3 p = ro + rd * d;

                    //calculamos la normal solo para el color.
                    float3 n = GetNormal(p);
                    col.rgb = abs(n);
                    
				}else{
                    discard;
				}
                
                //col.rgb = rd;
                return col;
            }
            ENDCG
        }
    }
}
