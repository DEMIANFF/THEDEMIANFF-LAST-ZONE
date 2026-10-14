#pragma once
#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "AuroraHeliosOutpost.generated.h"

class UInstancedStaticMeshComponent;
class UStaticMeshComponent;

UCLASS()
class THEDEMIANFF_API AAuroraHeliosOutpost : public AActor
{
    GENERATED_BODY()
public:
    AAuroraHeliosOutpost();
protected:
    UPROPERTY(VisibleAnywhere, Category="Helios")
    TObjectPtr<UInstancedStaticMeshComponent> StructuralModules;
    UPROPERTY(VisibleAnywhere, Category="Helios")
    TObjectPtr<UInstancedStaticMeshComponent> ArchitecturalDetails;
    UPROPERTY(VisibleAnywhere, Category="Helios")
    TObjectPtr<UStaticMeshComponent> Foundation;
};
