#pragma once
#include "CoreMinimal.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "AuroraPerformanceSettings.generated.h"

UENUM(BlueprintType)
enum class EAuroraGraphicsPreset : uint8
{
    Competitive UMETA(DisplayName="Competitive"),
    Balanced UMETA(DisplayName="Balanced"),
    Quality UMETA(DisplayName="Quality"),
    Ultra UMETA(DisplayName="Ultra")
};

UCLASS()
class THEDEMIANFF_API UAuroraPerformanceSettings : public UBlueprintFunctionLibrary
{
    GENERATED_BODY()
public:
    UFUNCTION(BlueprintCallable, Category="Aurora|Graphics")
    static void ApplyGraphicsPreset(EAuroraGraphicsPreset Preset, int32 TargetFPS);
};
