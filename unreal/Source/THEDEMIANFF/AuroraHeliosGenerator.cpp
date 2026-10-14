#include "AuroraHeliosGenerator.h"
#include "Components/InstancedStaticMeshComponent.h"
#include "Components/SceneComponent.h"
#include "UObject/ConstructorHelpers.h"

AAuroraHeliosGenerator::AAuroraHeliosGenerator()
{
    PrimaryActorTick.bCanEverTick = false;
    RootComponent = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));

    GroundTiles = CreateDefaultSubobject<UInstancedStaticMeshComponent>(TEXT("GroundTiles"));
    GroundTiles->SetupAttachment(RootComponent);
    LabModules = CreateDefaultSubobject<UInstancedStaticMeshComponent>(TEXT("LabModules"));
    LabModules->SetupAttachment(RootComponent);
    DetailModules = CreateDefaultSubobject<UInstancedStaticMeshComponent>(TEXT("DetailModules"));
    DetailModules->SetupAttachment(RootComponent);

    static ConstructorHelpers::FObjectFinder<UStaticMesh> Cube(TEXT("/Engine/BasicShapes/Cube.Cube"));
    if (Cube.Succeeded())
    {
        GroundTiles->SetStaticMesh(Cube.Object);
        LabModules->SetStaticMesh(Cube.Object);
        DetailModules->SetStaticMesh(Cube.Object);
    }
    GroundTiles->SetCollisionProfileName(TEXT("BlockAll"));
    LabModules->SetCollisionProfileName(TEXT("BlockAll"));
    DetailModules->SetCollisionProfileName(TEXT("NoCollision"));
}

void AAuroraHeliosGenerator::GenerateHelios()
{
    GroundTiles->ClearInstances();
    LabModules->ClearInstances();
    DetailModules->ClearInstances();

    const int32 Radius = FMath::Clamp(TileRadius, 1, 20);
    const auto AddBox = [](UInstancedStaticMeshComponent* Component, FVector Position, FVector Scale)
    {
        Component->AddInstance(FTransform(FRotator::ZeroRotator, Position, Scale));
    };

    // 10 m tiles: a 110 m x 110 m blockout at default radius 5.
    for (int32 X = -Radius; X <= Radius; ++X)
    {
        for (int32 Y = -Radius; Y <= Radius; ++Y)
        {
            const float PX = X * 1000.f;
            const float PY = Y * 1000.f;
            AddBox(GroundTiles, FVector(PX, PY, -45.f), FVector(10.f, 10.f, .9f));
        }
    }

    // Central lab: 32 m x 24 m, doorway openings on both ends.
    for (float Y : {-1200.f, 1200.f})
    {
        for (float X : {-1100.f, 1100.f})
        {
            AddBox(LabModules, FVector(X, Y, 250.f), FVector(10.f, .5f, 5.f));
        }
        AddBox(DetailModules, FVector(0.f, Y, 540.f), FVector(32.f, .75f, .8f));
    }
    for (float X : {-1600.f, 1600.f})
    {
        AddBox(LabModules, FVector(X, 0.f, 250.f), FVector(.5f, 24.f, 5.f));
    }

    // Exterior structural pylons and rooftop antenna.
    for (float X : {-1450.f, 1450.f})
    {
        for (float Y : {-1050.f, 1050.f})
        {
            AddBox(DetailModules, FVector(X, Y, 390.f), FVector(.8f, .8f, 7.8f));
        }
    }
    AddBox(DetailModules, FVector(0.f, 0.f, 800.f), FVector(.5f, .5f, 16.f));

    // Two side outbuildings, separated from the main laboratory.
    for (float X : {-3500.f, 3500.f})
    {
        AddBox(LabModules, FVector(X, 0.f, 175.f), FVector(12.f, 9.f, 3.5f));
        AddBox(DetailModules, FVector(X, 0.f, 390.f), FVector(13.f, 10.f, .4f));
    }
}
