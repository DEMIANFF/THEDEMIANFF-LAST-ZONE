#if UNITY_EDITOR
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEditor.Build.Reporting;
using UnityEditor.Build;
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
        [MenuItem("THEDEMIANFF/V41/Build Android APK (requires Android Support)")]
        public static void BuildAndroid()
        {
            ConfigureAndroid();
            if(!File.Exists("Assets/Scenes/V41_Test.unity"))CreateScene();
            if(EditorUserBuildSettings.activeBuildTarget!=BuildTarget.Android)
                throw new System.InvalidOperationException("Switch Unity Build Profile to Android before building.");
            Directory.CreateDirectory("Builds");
            string output="Builds/THEDEMIANFF-V41-native-test.apk";
            var options=new BuildPlayerOptions {
                scenes=new[]{"Assets/Scenes/V41_Test.unity"},
                locationPathName=output,
                target=BuildTarget.Android,
                options=BuildOptions.None
            };
            BuildReport report=BuildPipeline.BuildPlayer(options);
            if(report.summary.result!=BuildResult.Succeeded)
                throw new System.Exception("V41 native APK build failed: "+report.summary.result);
            Debug.Log("[V41] Native APK created: "+Path.GetFullPath(output));
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
