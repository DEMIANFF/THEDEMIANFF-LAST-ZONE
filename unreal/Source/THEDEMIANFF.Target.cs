using UnrealBuildTool;
using System.Collections.Generic;
public class THEDEMIANFFTarget : TargetRules
{
    public THEDEMIANFFTarget(TargetInfo Target) : base(Target)
    {
        Type = TargetType.Game;
        DefaultBuildSettings = BuildSettingsVersion.V5;
        ExtraModuleNames.Add("THEDEMIANFF");
    }
}
