#include "AuroraPerformanceSettings.h"
#include "Engine/Engine.h"
#include "HAL/IConsoleManager.h"

void UAuroraPerformanceSettings::ApplyGraphicsPreset(EAuroraGraphicsPreset Preset, int32 TargetFPS)
{
    const int32 FPS = (TargetFPS == 30 || TargetFPS == 60 || TargetFPS == 90 || TargetFPS == 120) ? TargetFPS : 60;
    if (GEngine)
    {
        GEngine->SetMaxFPS(static_cast<float>(FPS));
    }

    int32 Quality = 2;
    float ScreenPercentage = 85.f;
    switch (Preset)
    {
        case EAuroraGraphicsPreset::Competitive: Quality = 0; ScreenPercentage = 70.f; break;
        case EAuroraGraphicsPreset::Balanced: Quality = 1; ScreenPercentage = 80.f; break;
        case EAuroraGraphicsPreset::Quality: Quality = 2; ScreenPercentage = 90.f; break;
        case EAuroraGraphicsPreset::Ultra: Quality = 3; ScreenPercentage = 100.f; break;
    }
    IConsoleManager& Console = IConsoleManager::Get();
    const auto SetInt = [&Console](const TCHAR* Name, int32 Value)
    {
        if (IConsoleVariable* Var = Console.FindConsoleVariable(Name))
        {
            Var->Set(Value, ECVF_SetByGameSetting);
        }
    };
    const auto SetFloat = [&Console](const TCHAR* Name, float Value)
    {
        if (IConsoleVariable* Var = Console.FindConsoleVariable(Name))
        {
            Var->Set(Value, ECVF_SetByGameSetting);
        }
    };
    SetInt(TEXT("sg.ViewDistanceQuality"), Quality);
    SetInt(TEXT("sg.ShadowQuality"), Quality);
    SetInt(TEXT("sg.EffectsQuality"), Quality);
    SetInt(TEXT("sg.PostProcessQuality"), Quality);
    SetInt(TEXT("sg.TextureQuality"), Quality);
    SetFloat(TEXT("r.ScreenPercentage"), ScreenPercentage);
}
