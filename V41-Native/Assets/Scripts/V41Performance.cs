using UnityEngine;

namespace TheDemianFF.Native
{
    // Native frame-time diagnostics. No FPS guarantee; device profiling remains mandatory.
    public sealed class V41Performance : MonoBehaviour
    {
        public static V41Performance Instance { get; private set; }
        public float Fps { get; private set; }
        public float AverageFrameMs { get; private set; }
        public int LongFrames { get; private set; }
        public int TargetFps { get; private set; } = 60;
        private float elapsed;
        private float frameMsSum;
        private int frameCount;
        private void Awake()
        {
            if (Instance != null && Instance != this) { Destroy(this); return; }
            Instance = this;
            SetTarget(60);
        }
        public void SetTarget(int target)
        {
            TargetFps = target <= 30 ? 30 : target <= 60 ? 60 : target <= 90 ? 90 : 120;
            QualitySettings.vSyncCount = 0;
            Application.targetFrameRate = TargetFps;
        }
        private void Update()
        {
            float dt = Time.unscaledDeltaTime;
            if (dt <= 0f) return;
            elapsed += dt;
            frameMsSum += dt * 1000f;
            frameCount++;
            if (dt > .05f) LongFrames++;
            if (elapsed < 1f) return;
            Fps = frameCount / elapsed;
            AverageFrameMs = frameMsSum / frameCount;
            elapsed = 0f;
            frameMsSum = 0f;
            frameCount = 0;
        }
        private void OnGUI()
        {
            var style = new GUIStyle(GUI.skin.label);
            style.fontSize = Mathf.Clamp(Screen.height / 42, 12, 24);
            style.normal.textColor = Color.yellow;
            GUI.Label(new Rect(20, Screen.height - 55, Screen.width * .85f, 48),
                "V41 Native | FPS " + Fps.ToString("F1") +
                " | frame " + AverageFrameMs.ToString("F1") +
                " ms | >50ms " + LongFrames + " | cap " + TargetFps, style);
        }
    }
}
