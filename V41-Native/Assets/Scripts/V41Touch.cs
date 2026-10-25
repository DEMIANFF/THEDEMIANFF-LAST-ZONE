using UnityEngine;
#if ENABLE_INPUT_SYSTEM
using UnityEngine.InputSystem;
#endif

namespace TheDemianFF.Native
{
    // Each control owns one finger; sliding over another button never steals that action.
    // Uses Unity Input System on mobile, with legacy Input fallback for older project settings.
    [DefaultExecutionOrder(-100)]
    public sealed class V41Touch : MonoBehaviour
    {
        public static V41Touch Instance { get; private set; }
        public Vector2 Move { get; private set; }
        public Vector2 LookDelta { get; private set; }
        public bool Firing { get; private set; }
        public bool Aiming { get; private set; }
        public bool JumpQueued { get; private set; }
        public bool ReloadQueued { get; private set; }
        public bool HasTouches { get; private set; }

        private int moveFinger = -1, lookFinger = -1, fireFinger = -1, aimFinger = -1;
        private Vector2 moveOrigin, lastLook;
        private readonly Rect[] actions = new Rect[4];
        private bool moveSeen, lookSeen, fireSeen, aimSeen;

        private void Awake()
        {
            Instance = this;
        }

        private void OnDisable()
        {
            ResetControls();
            if (Instance == this) Instance = null;
        }

        private void ResetControls()
        {
            moveFinger = lookFinger = fireFinger = aimFinger = -1;
            Move = LookDelta = Vector2.zero;
            Firing = Aiming = HasTouches = false;
            JumpQueued = ReloadQueued = false;
        }

        private void Update()
        {
            LookDelta = Vector2.zero;
            float w = Screen.width, h = Screen.height, unit = Mathf.Min(w, h);
            // Input touch coordinates are bottom-left; IMGUI rectangles are top-left.
            actions[0] = new Rect(w-unit*.25f,unit*.05f,unit*.22f,unit*.28f); // fire
            actions[1] = new Rect(w-unit*.51f,unit*.06f,unit*.19f,unit*.22f); // aim
            actions[2] = new Rect(w-unit*.25f,unit*.37f,unit*.22f,unit*.19f); // jump
            actions[3] = new Rect(w-unit*.52f,unit*.34f,unit*.19f,unit*.16f); // reload
            moveSeen = lookSeen = fireSeen = aimSeen = false;
            HasTouches = false;
#if ENABLE_INPUT_SYSTEM
            var screen = Touchscreen.current;
            if (screen != null)
            {
                foreach (var touch in screen.touches)
                {
                    var phase = touch.phase.ReadValue();
                    if (phase == UnityEngine.InputSystem.TouchPhase.None) continue;
                    bool ended = phase == UnityEngine.InputSystem.TouchPhase.Ended ||
                                 phase == UnityEngine.InputSystem.TouchPhase.Canceled;
                    ProcessTouch(touch.touchId.ReadValue(), touch.position.ReadValue(),
                        phase == UnityEngine.InputSystem.TouchPhase.Began, ended, w, h, unit);
                }
            }
#elif ENABLE_LEGACY_INPUT_MANAGER
            foreach (UnityEngine.Touch touch in Input.touches)
            {
                bool ended = touch.phase == UnityEngine.TouchPhase.Ended ||
                             touch.phase == UnityEngine.TouchPhase.Canceled;
                ProcessTouch(touch.fingerId, touch.position,
                    touch.phase == UnityEngine.TouchPhase.Began, ended, w, h, unit);
            }
#endif
            // Reset missing fingers, including after OS interruptions and orientation changes.
            if (!moveSeen) { moveFinger = -1; Move = Vector2.zero; }
            if (!lookSeen) lookFinger = -1;
            if (!fireSeen) fireFinger = -1;
            if (!aimSeen) aimFinger = -1;
            Firing = fireSeen;
            Aiming = aimSeen;
        }

        private void ProcessTouch(int id, Vector2 p, bool began, bool ended, float w, float h, float unit)
        {
            if (ended) return;
            HasTouches = true;
            if (began)
            {
                if (actions[0].Contains(p) && fireFinger == -1) fireFinger = id;
                else if (actions[1].Contains(p) && aimFinger == -1) aimFinger = id;
                else if (actions[2].Contains(p)) JumpQueued = true;
                else if (actions[3].Contains(p)) ReloadQueued = true;
                else if (moveFinger == -1 && p.x < w*.40f && p.y < h*.65f)
                {
                    moveFinger = id;
                    moveOrigin = p;
                }
                else if (lookFinger == -1 && p.x >= w*.38f && !InAction(p))
                {
                    lookFinger = id;
                    lastLook = p;
                }
            }
            if (id == moveFinger)
            {
                moveSeen = true;
                Move = Vector2.ClampMagnitude((p-moveOrigin) / Mathf.Max(55f,unit*.13f),1);
            }
            if (id == lookFinger)
            {
                lookSeen = true;
                Vector2 delta = p-lastLook;
                // Ignore tiny sensor movement but retain larger deliberate swipes.
                if (delta.sqrMagnitude > .36f)
                    LookDelta += Vector2.ClampMagnitude(delta,unit*.15f);
                lastLook = p;
            }
            if (id == fireFinger) fireSeen = true;
            if (id == aimFinger) aimSeen = true;
        }

        private bool InAction(Vector2 p)
        {
            foreach (Rect r in actions) if (r.Contains(p)) return true;
            return false;
        }

        public bool ConsumeJump() { bool queued = JumpQueued; JumpQueued = false; return queued; }
        public bool ConsumeReload() { bool queued = ReloadQueued; ReloadQueued = false; return queued; }

        private void OnGUI()
        {
            if (!HasTouches && !Application.isMobilePlatform) return;
            float w = Screen.width, h = Screen.height, u = Mathf.Min(w,h);
            GUI.color = new Color(1,1,1,.6f);
            GUI.Box(new Rect(u*.05f,h-u*.28f,u*.26f,u*.22f),"MOVE");
            GUI.Box(new Rect(w-u*.25f,h-u*.33f,u*.22f,u*.28f),"FIRE");
            GUI.Box(new Rect(w-u*.51f,h-u*.28f,u*.19f,u*.22f),"ADS");
            GUI.Box(new Rect(w-u*.25f,h-u*.56f,u*.22f,u*.19f),"JUMP");
            GUI.Box(new Rect(w-u*.52f,h-u*.50f,u*.19f,u*.16f),"RELOAD");
            GUI.color = Color.white;
        }
    }
}
