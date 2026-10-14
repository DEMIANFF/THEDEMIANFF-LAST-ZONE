#include "AuroraHeliosOutpost.h"
#include "Components/InstancedStaticMeshComponent.h"
#include "Components/StaticMeshComponent.h"
#include "UObject/ConstructorHelpers.h"

AAuroraHeliosOutpost::AAuroraHeliosOutpost()
{
    PrimaryActorTick.bCanEverTick = false;
    Foundation = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Foundation"));
    RootComponent = Foundation;
    StructuralModules = CreateDefaultSubobject<UInstancedStaticMeshComponent>(TEXT("StructuralModules"));
    StructuralModules->SetupAttachment(RootComponent);
    ArchitecturalDetails = CreateDefaultSubobject<UInstancedStaticMeshComponent>(TEXT("ArchitecturalDetails"));
    ArchitecturalDetails->SetupAttachment(RootComponent);

    static ConstructorHelpers::FObjectFinder<UStaticMesh> Cube(TEXT("/Engine/BasicShapes/Cube.Cube"));
    if (!Cube.Succeeded()) return;
    Foundation->SetStaticMesh(Cube.Object);
    StructuralModules->SetStaticMesh(Cube.Object);
    ArchitecturalDetails->SetStaticMesh(Cube.Object);
    Foundation->SetRelativeScale3D(FVector(20.f, 16.f, .15f));
    Foundation->SetCollisionProfileName(TEXT("BlockAll"));

    // Unreal cube mesh is 100 cm wide. Modules are laid out in centimeters.
    // Two doors (north and south) and a traversable central corridor.
    auto AddModule = [](UInstancedStaticMeshComponent* Target, const FVector& Position, const FVector& Scale)
    {
        Target->AddInstance(FTransform(FRotator::ZeroRotator, Position, Scale));
    };
    for (float Y : {-750.f, 750.f})
    {
        AddModule(StructuralModules, FVector(-650.f,Y,220.f), FVector(6.5f,.4f,4.4f));
        AddModule(StructuralModules, FVector(650.f,Y,220.f), FVector(6.5f,.4f,4.4f));
        AddModule(ArchitecturalDetails, FVector(-650.f,Y,460.f), FVector(6.5f,.55f,.35f));
        AddModule(ArchitecturalDetails, FVector(650.f,Y,460.f), FVector(6.5f,.55f,.35f));
    }
    for (float X : {-950.f, 950.f})
    {
        AddModule(StructuralModules, FVector(X,-530.f,220.f), FVector(.4f,5.3f,4.4f));
        AddModule(StructuralModules, FVector(X,530.f,220.f), FVector(.4f,5.3f,4.4f));
    }
    // Structural framing and raised observation detail.
    for (float X : {-900.f, 900.f})
        for (float Y : {-700.f, 700.f})
            AddModule(ArchitecturalDetails, FVector(X,Y,360.f), FVector(.6f,.6f,7.2f));
    for (float X : {-360.f, 360.f})
        AddModule(ArchitecturalDetails, FVector(X,0.f,70.f), FVector(2.4f,1.4f,1.4f));
    StructuralModules->SetCollisionProfileName(TEXT("BlockAll"));
    ArchitecturalDetails->SetCollisionProfileName(TEXT("BlockAll"));
}
