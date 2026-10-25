using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace TheDemianFF.Native
{
    // Generates a deterministic collision-enabled test range from native Unity primitives.
    // Temporary meshes intentionally avoid the legacy WebView assets.
    public sealed class V41Bootstrap : MonoBehaviour
    {
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        private static void AutoBoot()
        {
            if(FindFirstObjectByType<V41Bootstrap>()!=null)return;
            new GameObject("V41 Native Test World").AddComponent<V41Bootstrap>();
        }
        private readonly System.Random random=new System.Random(4101);
        private static Material Make(Color c,float metallic=0,float smooth=.18f)
        {
            Shader shader=GraphicsSettings.currentRenderPipeline!=null
                ? Shader.Find("Universal Render Pipeline/Lit") : Shader.Find("Standard");
            if(shader==null)shader=Shader.Find("Standard");
            var m=new Material(shader);
            if(m.HasProperty("_BaseColor"))m.SetColor("_BaseColor",c);
            else m.color=c;
            if(m.HasProperty("_Metallic"))m.SetFloat("_Metallic",metallic);
            if(m.HasProperty("_Smoothness"))m.SetFloat("_Smoothness",smooth);
            return m;
        }
        private static GameObject Cube(string name,Vector3 at,Vector3 size,Material material,Transform parent=null)
        {
            var g=GameObject.CreatePrimitive(PrimitiveType.Cube);
            g.name=name;g.transform.position=at;g.transform.localScale=size;
            if(parent!=null)g.transform.SetParent(parent,true);
            g.GetComponent<Renderer>().sharedMaterial=material;
            return g;
        }
        private void Awake()
        {
            Application.targetFrameRate=60; // stable baseline; unlock 90/120 only after profiling
            QualitySettings.vSyncCount=0;
            Screen.sleepTimeout=SleepTimeout.NeverSleep;
            Physics.defaultContactOffset=.015f;
            var ice=Make(new Color(.45f,.68f,.75f)),snow=Make(new Color(.77f,.84f,.87f));
            var wall=Make(new Color(.34f,.49f,.58f),.12f),metal=Make(new Color(.14f,.28f,.36f),.65f);
            var glass=Make(new Color(.13f,.54f,.66f),.35f,.82f),orange=Make(new Color(.92f,.52f,.18f));
            Cube("Collision terrain",new Vector3(0,-.55f,0),new Vector3(170,1,170),snow);
            for(int i=0;i<24;i++)
            {
                float x=(float)(random.NextDouble()*145-72),z=(float)(random.NextDouble()*145-72);
                if(x*x+z*z<120)continue;
                var stone=GameObject.CreatePrimitive(PrimitiveType.Sphere);
                stone.name="Solid ice boulder";
                stone.transform.position=new Vector3(x,.75f,z);
                stone.transform.localScale=new Vector3(2.6f,1.9f,2.5f);
                stone.GetComponent<Renderer>().sharedMaterial=ice;
                // Primitive sphere collider is enabled, character cannot walk through.
            }
            for(int i=0;i<8;i++)
            {
                float x=-52+(i%4)*31,z=-36+(i/4)*39;
                BuildHouse(x,z,wall,metal,glass,orange);
            }
            for(int i=0;i<8;i++)
            {
                float x=-54+(i%4)*30,z=14+(i/4)*17;
                var target=Cube("Shooting target "+i,new Vector3(x,1.15f,z),new Vector3(.8f,2.3f,.6f),orange);
                target.AddComponent<V41Dummy>();
            }
            var player=new GameObject("Lila Controller V41");
            player.transform.position=new Vector3(0,5,0);
            player.layer=2; // Ignore Raycast (camera collision / fire rays)
            player.AddComponent<CharacterController>();
            var visual=new GameObject("Temporary Lila silhouette").transform;
            visual.SetParent(player.transform,false);
            var torso=Cube("Torso",player.transform.position,new Vector3(.65f,1,.4f),metal,visual);
            torso.transform.localPosition=new Vector3(0,1.2f,0);
            var head=GameObject.CreatePrimitive(PrimitiveType.Sphere);
            head.name="Head";head.transform.SetParent(visual,false);
            head.transform.localPosition=new Vector3(0,1.95f,0);
            head.transform.localScale=Vector3.one*.38f;head.GetComponent<Renderer>().sharedMaterial=orange;
            foreach(var r in visual.GetComponentsInChildren<Collider>())Destroy(r);
            var cameraObj=new GameObject("Main Camera",typeof(Camera),typeof(AudioListener));
            cameraObj.tag="MainCamera";cameraObj.transform.position=new Vector3(0,4,-5);
            var cam=cameraObj.GetComponent<Camera>();
            cam.fieldOfView=67;cam.nearClipPlane=.09f;cam.farClipPlane=240;
            var script=player.AddComponent<V41Player>();
            script.Visual=visual;script.CameraPivot=visual;
            new GameObject("V41 Multitouch").AddComponent<V41Touch>();
            new GameObject("V41 Frame Diagnostics").AddComponent<V41Performance>();
            var sun=new GameObject("Sun",typeof(Light)).GetComponent<Light>();
            sun.type=LightType.Directional;sun.intensity=1.18f;sun.color=new Color(1,.95f,.87f);
            sun.transform.rotation=Quaternion.Euler(48,-32,0);
            RenderSettings.ambientMode=AmbientMode.Flat;
            RenderSettings.ambientLight=new Color(.47f,.59f,.66f);
            RenderSettings.fog=true;RenderSettings.fogMode=FogMode.Linear;
            RenderSettings.fogColor=new Color(.48f,.65f,.73f);
            RenderSettings.fogStartDistance=95;RenderSettings.fogEndDistance=225;
        }
        private static void BuildHouse(float x,float z,Material concrete,Material steel,Material glass,Material accent)
        {
            var root=new GameObject("HELIOS Collidable Building").transform;
            var center=new Vector3(x,0,z);
            // Floor and roof are real BoxColliders. Three walls leave an accessible front doorway.
            Cube("Foundation",center+new Vector3(0,.18f,0),new Vector3(11,.36f,9),concrete,root);
            Cube("Roof landing slab",center+new Vector3(0,6.2f,0),new Vector3(11,.42f,9),steel,root);
            Cube("Back wall",center+new Vector3(0,3.1f,-4.25f),new Vector3(11,6,.5f),concrete,root);
            Cube("Left wall",center+new Vector3(-5.25f,3.1f,0),new Vector3(.5f,6,9),concrete,root);
            Cube("Right wall",center+new Vector3(5.25f,3.1f,0),new Vector3(.5f,6,9),concrete,root);
            Cube("Front left",center+new Vector3(-3.2f,3.1f,4.25f),new Vector3(4.6f,6,.5f),concrete,root);
            Cube("Front right",center+new Vector3(3.2f,3.1f,4.25f),new Vector3(4.6f,6,.5f),concrete,root);
            Cube("Door lintel",center+new Vector3(0,5.15f,4.25f),new Vector3(1.8f,1.9f,.5f),steel,root);
            for(int side=-1;side<=1;side+=2)
            {
                Cube("Frosted window",center+new Vector3(side*2.7f,3.4f,4.56f),new Vector3(1.65f,1.4f,.08f),glass,root);
                Cube("Roof safety rail",center+new Vector3(side*5.25f,6.82f,0),new Vector3(.1f,.9f,9),accent,root);
            }
            Cube("Roof back rail",center+new Vector3(0,6.82f,-4.3f),new Vector3(10.5f,.9f,.1f),accent,root);
            // Exterior stair / stepping platforms allow reaching the roof without teleporting.
            for(int k=0;k<13;k++)
            {
                Cube("Solid roof access step",center+new Vector3(7.0f, .28f+k*.47f,3.4f-k*.54f),new Vector3(2.5f,.42f,.9f),steel,root);
            }
        }
    }
}
