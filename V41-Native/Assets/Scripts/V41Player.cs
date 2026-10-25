using UnityEngine;

namespace TheDemianFF.Native
{
    [RequireComponent(typeof(CharacterController))]
    public sealed class V41Player : MonoBehaviour
    {
        public Transform CameraPivot;
        public Transform Visual;
        public float WalkSpeed=6.2f, SprintSpeed=8.5f, JumpSpeed=6.5f, Gravity=20f;
        public float Sensitivity=.12f, CameraDistance=4.6f, Health=100;
        private CharacterController motor;
        private Camera viewCamera;
        private float yaw, pitch=12, fallSpeed, fireClock;
        private int ammo=30, reserve=180, kills;
        private readonly RaycastHit[] cameraHits=new RaycastHit[12];
        private readonly RaycastHit[] shotHits=new RaycastHit[16];
        private Transform cameraTransform;
        private void Awake()
        {
            motor=GetComponent<CharacterController>();
            motor.height=2.2f;motor.radius=.43f;motor.center=new Vector3(0,1.1f,0);
            motor.skinWidth=.07f;motor.stepOffset=.34f;motor.slopeLimit=48f;
            viewCamera=Camera.main;
            if(viewCamera!=null)cameraTransform=viewCamera.transform;
            yaw=transform.eulerAngles.y;
        }
        private void Update()
        {
            var touch=V41Touch.Instance;
            Vector2 move=touch!=null ? touch.Move:Vector2.zero;
            #if ENABLE_LEGACY_INPUT_MANAGER
            if((touch==null || !touch.HasTouches))move=new Vector2(Input.GetAxisRaw("Horizontal"),Input.GetAxisRaw("Vertical"));
            #endif
            move=Vector2.ClampMagnitude(move,1);
            Vector2 look=touch!=null?touch.LookDelta:Vector2.zero;
            #if ENABLE_LEGACY_INPUT_MANAGER
            if((touch==null || !touch.HasTouches) && Input.GetMouseButton(1))look=new Vector2(Input.GetAxis("Mouse X")*18, Input.GetAxis("Mouse Y")*18);
            #endif
            yaw+=look.x*Sensitivity;pitch=Mathf.Clamp(pitch-look.y*Sensitivity,-55,65);
            Quaternion heading=Quaternion.Euler(0,yaw,0);
            Vector3 direction=heading*new Vector3(move.x,0,move.y);
            bool keyboardSprint=false, keyboardJump=false, keyboardReload=false, mouseFire=false;
            #if ENABLE_LEGACY_INPUT_MANAGER
            keyboardSprint=Input.GetKey(KeyCode.LeftShift);
            keyboardJump=Input.GetKeyDown(KeyCode.Space);
            keyboardReload=Input.GetKeyDown(KeyCode.R);
            mouseFire=Input.GetMouseButton(0);
            #endif
            float speed=keyboardSprint?SprintSpeed:WalkSpeed;
            if(motor.isGrounded && fallSpeed<0)fallSpeed=-1.2f;
            if((touch!=null&&touch.ConsumeJump()||keyboardJump)&&motor.isGrounded)fallSpeed=JumpSpeed;
            fallSpeed-=Gravity*Time.deltaTime;
            motor.Move((direction*speed+Vector3.up*fallSpeed)*Time.deltaTime);
            if(direction.sqrMagnitude>.025f)Visual.rotation=Quaternion.Slerp(Visual.rotation,Quaternion.LookRotation(direction),Time.deltaTime*12);
            if(touch!=null&&touch.ConsumeReload()||keyboardReload)Reload();
            fireClock=Mathf.Max(0,fireClock-Time.deltaTime);
            if(touch!=null&&touch.Firing||mouseFire)Fire();
            if(Health<=0) { Health=100; transform.position=new Vector3(0,9,0); }
        }
        private void LateUpdate()
        {
            if(cameraTransform==null) { viewCamera=Camera.main; if(viewCamera!=null)cameraTransform=viewCamera.transform; }
            if(cameraTransform==null) return;
            var touch=V41Touch.Instance;
            bool aiming=touch!=null&&touch.Aiming;
            #if ENABLE_LEGACY_INPUT_MANAGER
            aiming=aiming||Input.GetMouseButton(1);
            #endif
            Vector3 eye=transform.position+Vector3.up*1.72f;
            Quaternion rot=Quaternion.Euler(pitch,yaw,0);
            Vector3 back=rot*Vector3.back;
            float distance=aiming?2.5f:CameraDistance;
            Vector3 desired=eye+rot*Vector3.right*.5f+back*distance;
            Vector3 ray=desired-eye;
            float len=ray.magnitude;
            if(len>.01f)
            {
                int count=Physics.SphereCastNonAlloc(eye,.2f,ray.normalized,cameraHits,len,~(1<<2),QueryTriggerInteraction.Ignore);
                float nearest=len;
                for(int i=0;i<count;i++)
                    if(cameraHits[i].collider!=null && !cameraHits[i].collider.transform.IsChildOf(transform))
                        nearest=Mathf.Min(nearest,cameraHits[i].distance);
                desired=eye+ray.normalized*Mathf.Max(.25f,nearest-.14f);
            }
            cameraTransform.position=Vector3.Lerp(cameraTransform.position,desired,1-Mathf.Exp(-22*Time.deltaTime));
            cameraTransform.rotation=rot;
        }
        private void Fire()
        {
            if(fireClock>0||ammo<=0||viewCamera==null)return;
            fireClock=.105f;ammo--;
            Vector3 origin=viewCamera.transform.position, direction=viewCamera.transform.forward;
            int n=Physics.RaycastNonAlloc(origin,direction,shotHits,120f,~(1<<2),QueryTriggerInteraction.Ignore);
            float best=121;V41Dummy target=null;
            for(int i=0;i<n;i++)
            {
                var hit=shotHits[i];
                if(hit.collider==null||hit.collider.transform.IsChildOf(transform)||hit.distance>=best)continue;
                best=hit.distance;target=hit.collider.GetComponentInParent<V41Dummy>();
            }
            if(target!=null&&target.Hit(23))kills++;
        }
        private void Reload() { int count=Mathf.Min(30-ammo,reserve);ammo+=count;reserve-=count; }
        private void OnGUI()
        {
            var style=new GUIStyle(GUI.skin.label){fontSize=Mathf.Clamp(Screen.height/28,14,32),fontStyle=FontStyle.Bold};
            GUI.Label(new Rect(20,18,Screen.width*.75f,60),"LAST ZONE NATIVE  |  HP "+(int)Health+"  |  "+ammo+"/"+reserve+"  |  BAJAS "+kills,style);
            style.alignment=TextAnchor.MiddleCenter;
            GUI.Label(new Rect(Screen.width/2-22,Screen.height/2-22,44,44),"+",style);
        }
    }
    public sealed class V41Dummy : MonoBehaviour
    {
        public float Health=100;
        public bool Hit(float amount)
        {
            Health-=amount;
            if(Health>0)return false;
            Destroy(gameObject);return true;
        }
    }
}
