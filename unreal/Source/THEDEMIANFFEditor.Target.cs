using UnrealBuildTool;
using System.Collections.Generic;
public class THEDEMIANFFEditorTarget : TargetRules
{
    public THEDEMIANFFEditorTarget(TargetInfo Target) : base(Target)
    {
        Type = TargetType.Editor;
        DefaultBuildSettings = BuildSettingsVersion.V5;
        ExtraModuleNames.Add("THEDEMIANFF");
    }
}
