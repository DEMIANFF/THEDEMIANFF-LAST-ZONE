#include "AuroraTouchHUD.h"
#include "AuroraMobileController.h"

AAuroraMobileController* UAuroraTouchHUD::GetMobileController() const
{
    return Cast<AAuroraMobileController>(GetOwningPlayer());
}

void UAuroraTouchHUD::UpdateMoveJoystick(FVector2D Axis)
{
    if (AAuroraMobileController* PC = GetMobileController())
    {
        PC->SetMobileMovement(Axis.GetClampedToMaxSize(1.f));
    }
}

void UAuroraTouchHUD::UpdateCameraDrag(FVector2D PixelDelta)
{
    if (AAuroraMobileController* PC = GetMobileController())
    {
        PC->AddMobileLook(PixelDelta);
    }
}

void UAuroraTouchHUD::SetJumpPressed(bool bPressed)
{
    if (AAuroraMobileController* PC = GetMobileController())
    {
        PC->SetMobileJump(bPressed);
    }
}

void UAuroraTouchHUD::SetAimPressed(bool bPressed)
{
    bAiming = bPressed;
    OnCombatInputChanged(bAiming, bFiring);
}

void UAuroraTouchHUD::SetFirePressed(bool bPressed)
{
    bFiring = bPressed;
    OnCombatInputChanged(bAiming, bFiring);
}

void UAuroraTouchHUD::ReleaseTouchControls()
{
    UpdateMoveJoystick(FVector2D::ZeroVector);
    SetJumpPressed(false);
    bAiming = false;
    bFiring = false;
    OnCombatInputChanged(false, false);
}

void UAuroraTouchHUD::NativeDestruct()
{
    ReleaseTouchControls();
    Super::NativeDestruct();
}
