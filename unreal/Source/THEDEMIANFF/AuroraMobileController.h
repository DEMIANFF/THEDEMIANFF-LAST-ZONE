#pragma once
#include "CoreMinimal.h"
#include "GameFramework/PlayerController.h"
#include "AuroraMobileController.generated.h"

UCLASS()
class THEDEMIANFF_API AAuroraMobileController : public APlayerController
{
    GENERATED_BODY()
public:
    AAuroraMobileController();
    UFUNCTION(BlueprintCallable, Category="Aurora|Touch")
    void SetMobileMovement(FVector2D Axis);
    UFUNCTION(BlueprintCallable, Category="Aurora|Touch")
    void AddMobileLook(FVector2D Delta);
    UFUNCTION(BlueprintCallable, Category="Aurora|Touch")
    void SetMobileJump(bool bPressed);
    UFUNCTION(BlueprintCallable, Category="Aurora|Touch")
    void SetMobileSensitivity(float NewSensitivity);
protected:
    virtual void PlayerTick(float DeltaTime) override;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Aurora|Touch")
    float TouchLookSensitivity = 0.12f;
private:
    FVector2D MobileMoveAxis = FVector2D::ZeroVector;
};
