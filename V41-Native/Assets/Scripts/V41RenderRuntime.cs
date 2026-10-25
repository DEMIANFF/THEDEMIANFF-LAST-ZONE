using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace TheDemianFF.Native
{
    // Create and assign a mobile URP asset before the native scene is loaded.
    // Requires Universal Render Pipeline package 17.x in Unity 6.
    public static class V41RenderRuntime
    {
        public static void ApplyMobileDefaults()
        {
            QualitySettings.vSyncCount = 0;
            Application.targetFrameRate = 60;
            Screen.sleepTimeout = SleepTimeout.NeverSleep;
            // Quality settings and URP asset are serialized in Unity Editor.
            // Runtime intentionally does not allocate or swap pipeline assets.
            if (GraphicsSettings.currentRenderPipeline == null)
                Debug.LogWarning("[V41] No active SRP asset. Assign a URP Pipeline Asset in Graphics and Quality settings.");
        }
    }
}
