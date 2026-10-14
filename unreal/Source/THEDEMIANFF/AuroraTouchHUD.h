#pragma once
#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "AuroraTouchHUD.generated.h"

class AAuroraMobileController;

UCLASS(Abstract, Blueprintable)
class THEDEMIANFF_API UAuroraTouchHUD : public UUserWidget
{
    GENERATED_BODY()
public:
    UFUNCTION(BlueprintCallable, Category="Aurora|HUD")
    void UpdateMoveJoystick(FVector2D Axis);

    UFUNCTION(BlueprintCallable, Category="Aurora|HUD")
    void UpdateCameraDrag(FVector2D PixelDelta);

    UFUNCTION(BlueprintCallable, Category="Aurora|HUD")
    void SetJumpPressed(bool bPressed);

    UFUNCTION(BlueprintCallable, Category="Aurora|HUD")
    void SetAimPressed(bool bPressed);

    UFUNCTION(BlueprintCallable, Category="Aurora|HUD")
    void SetFirePressed(bool bPressed);

    UFUNCTION(BlueprintCallable, Category="Aurora|HUD")
    void ReleaseTouchControls();

    UFUNCTION(BlueprintPure, Category="Aurora|HUD")
    bool IsAiming() const { return bAiming; }

    UFUNCTION(BlueprintPure, Category="Aurora|HUD")
    bool IsFiring() const { return bFiring; }

protected:
    virtual void NativeDestruct() override;

    UPROPERTY(BlueprintReadOnly, Category="Aurora|HUD")
    bool bAiming = false;

    UPROPERTY(BlueprintReadOnly, Category="Aurora|HUD")
    bool bFiring = false;

    UFUNCTION(BlueprintImplementableEvent, Category="Aurora|HUD")
    void OnCombatInputChanged(bool bNewAiming, bool bNewFiring);

private:
    AAuroraMobileController* GetMobileController() const;
};
