using UnityEngine;
using UnityEngine.EventSystems;

namespace TheDemianFF.Native
{
    // Finger ownership is explicit: the look finger cannot steal joystick or fire.
    public sealed class V41Touch : MonoBehaviour
    {
        public static V41Touch Instance { get; private set; }
        public Vector2 Move { get; private set; }
        public Vector2 LookDelta { get; private set; }
        public bool Firing { get; private set; }
        public bool Aiming { get; private set; }
        public bool JumpQueued { get; private set; }
        public bool ReloadQueued { get; private set; }
        private int moveFinger = -1, lookFinger = -1;
        private Vector2 moveOrigin, lastLook;
        private readonly Rect[] actions = new Rect[4];
        private void Awake() { Instance = this; }
        private void OnDisable() { moveFinger = lookFinger = -1; Move = LookDelta = Vector2.zero; Firing = Aiming = false; }
        private void Update()
        {
            LookDelta = Vector2.zero;
            float w = Screen.width, h = Screen.height, unit = Mathf.Min(w, h);
            // Screen coordinates start at bottom-left.
            actions[0] = new Rect(w-unit*.25f,unit*.05f,unit*.22f,unit*.28f); // fire
            actions[1] = new Rect(w-unit*.51f,unit*.06f,unit*.19f,unit*.22f); // aim
            actions[2] = new Rect(w-unit*.25f,unit*.37f,unit*.22f,unit*.19f); // jump
            actions[3] = new Rect(w-unit*.52f,unit*.34f,unit*.19f,unit*.16f); // reload
            bool fire = false, aim = false;
            foreach (Touch t in Input.touches)
            {
                Vector2 p = t.position;
                if (t.phase == TouchPhase.Began)
                {
                    if (t.fingerId != moveFinger && moveFinger == -1 && p.x < w*.40f && p.y < h*.65f)
                    { moveFinger = t.fingerId; moveOrigin = p; }
                    else if (t.fingerId != lookFinger && lookFinger == -1 && p.x >= w*.38f && !InAction(p))
                    { lookFinger = t.fingerId; lastLook = p; }
                    else if (actions[2].Contains(p)) JumpQueued = true;
                    else if (actions[3].Contains(p)) ReloadQueued = true;
                }
                if (t.fingerId == moveFinger)
                {
                    if (Ended(t)) { moveFinger = -1; Move = Vector2.zero; }
                    else Move = Vector2.ClampMagnitude((p - moveOrigin) / Mathf.Max(55f,unit*.13f), 1);
                }
                if (t.fingerId == lookFinger)
                {
                    if (Ended(t)) lookFinger = -1;
                    else { LookDelta += Vector2.ClampMagnitude(p - lastLook,unit*.15f); lastLook = p; }
                }
                if (!Ended(t)) { if (actions[0].Contains(p)) fire = true; if (actions[1].Contains(p)) aim = true; }
            }
            Firing = fire; Aiming = aim;
            if (Input.touchCount == 0) { moveFinger = lookFinger = -1; Move = Vector2.zero; }
        }
        private bool InAction(Vector2 p) { foreach (Rect r in actions) if (r.Contains(p)) return true; return false; }
        private static bool Ended(Touch t) => t.phase == TouchPhase.Ended || t.phase == TouchPhase.Canceled;
        public bool ConsumeJump() { bool v=JumpQueued; JumpQueued=false; return v; }
        public bool ConsumeReload() { bool v=ReloadQueued; ReloadQueued=false; return v; }
        private void OnGUI()
        {
            if (Input.touchCount == 0 && !Application.isMobilePlatform) return;
            float w=Screen.width,h=Screen.height,u=Mathf.Min(w,h);
            GUI.skin.label.alignment=TextAnchor.MiddleCenter;
            GUI.color=new Color(1,1,1,.6f);
            GUI.Box(new Rect(u*.05f,h-u*.28f,u*.26f,u*.22f),"MOVE");
            GUI.Box(new Rect(w-u*.25f,h-u*.33f,u*.22f,u*.28f),"FIRE");
            GUI.Box(new Rect(w-u*.51f,h-u*.28f,u*.19f,u*.22f),"ADS");
            GUI.Box(new Rect(w-u*.25f,h-u*.56f,u*.22f,u*.19f),"JUMP");
            GUI.Box(new Rect(w-u*.52f,h-u*.50f,u*.19f,u*.16f),"RELOAD");
            GUI.color=Color.white;
        }
    }
}
