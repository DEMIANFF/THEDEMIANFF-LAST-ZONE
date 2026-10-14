#pragma once
#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "AuroraHeliosGenerator.generated.h"

class UInstancedStaticMeshComponent;

UCLASS()
class THEDEMIANFF_API AAuroraHeliosGenerator : public AActor
{
    GENERATED_BODY()
public:
    AAuroraHeliosGenerator();

    UFUNCTION(CallInEditor, BlueprintCallable, Category="Aurora|Helios")
    void GenerateHelios();

protected:
    UPROPERTY(VisibleAnywhere, Category="Aurora|Helios")
    TObjectPtr<UInstancedStaticMeshComponent> GroundTiles;
    UPROPERTY(VisibleAnywhere, Category="Aurora|Helios")
    TObjectPtr<UInstancedStaticMeshComponent> LabModules;
    UPROPERTY(VisibleAnywhere, Category="Aurora|Helios")
    TObjectPtr<UInstancedStaticMeshComponent> DetailModules;

    UPROPERTY(EditAnywhere, Category="Aurora|Helios", meta=(ClampMin="1", ClampMax="20"))
    int32 TileRadius = 5;
};
