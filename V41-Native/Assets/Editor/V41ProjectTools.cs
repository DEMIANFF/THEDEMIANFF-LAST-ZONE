#if UNITY_EDITOR
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace TheDemianFF.Native.Editor
{
    public static class V41ProjectTools
    {
        [MenuItem("THEDEMIANFF/V41/Create Native Test Scene")]
        public static void CreateScene()
        {
            Directory.CreateDirectory("Assets/Scenes");
            var scene=EditorSceneManager.NewScene(NewSceneSetup.EmptyScene,NewSceneMode.Single);
            new GameObject("V41 World Bootstrap").AddComponent<V41Bootstrap>();
            EditorSceneManager.SaveScene(scene,"Assets/Scenes/V41_Test.unity");
            var scenes=new[]{new EditorBuildSettingsScene("Assets/Scenes/V41_Test.unity",true)};
            EditorBuildSettings.scenes=scenes;
            Debug.Log("[V41] Saved native test scene; press Play. No HTML / WebView.");
        }
        [MenuItem("THEDEMIANFF/V41/Configure Android")]
        public static void ConfigureAndroid()
        {
            PlayerSettings.companyName="THEDEMIANFF";
            PlayerSettings.productName="THEDEMIANFF LAST ZONE";
            PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.Android,"com.thedemianff.lastzone.native");
            PlayerSettings.Android.minSdkVersion=AndroidSdkVersions.AndroidApiLevel26;
            PlayerSettings.Android.targetArchitectures=AndroidArchitecture.ARM64;
            PlayerSettings.defaultInterfaceOrientation=UIOrientation.LandscapeLeft;
            PlayerSettings.runInBackground=false;
            PlayerSettings.SetScriptingBackend(NamedBuildTarget.Android,ScriptingImplementation.IL2CPP);
            // In Project Settings > Player > Other Settings set Active Input Handling to Both.
            Debug.Log("[V41] Android native settings applied. Switch Build Profile to Android before building.");
        }
    }
}
