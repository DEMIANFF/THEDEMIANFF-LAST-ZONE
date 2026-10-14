#include "AuroraMobileController.h"
#include "GameFramework/Character.h"
#include "GameFramework/Pawn.h"

AAuroraMobileController::AAuroraMobileController()
{
    bShowMouseCursor = false;
}

void AAuroraMobileController::SetMobileMovement(FVector2D Axis)
{
    MobileMoveAxis = Axis.GetClampedToMaxSize(1.f);
}

void AAuroraMobileController::AddMobileLook(FVector2D Delta)
{
    if (!Delta.IsNearlyZero())
    {
        AddYawInput(Delta.X * TouchLookSensitivity);
        AddPitchInput(-Delta.Y * TouchLookSensitivity);
    }
}

void AAuroraMobileController::SetMobileJump(bool bPressed)
{
    if (ACharacter* Character = Cast<ACharacter>(GetPawn()))
    {
        if (bPressed) Character->Jump();
        else Character->StopJumping();
    }
}

void AAuroraMobileController::SetMobileSensitivity(float NewSensitivity)
{
    TouchLookSensitivity = FMath::Clamp(NewSensitivity, 0.01f, 2.f);
}

void AAuroraMobileController::PlayerTick(float DeltaTime)
{
    Super::PlayerTick(DeltaTime);
    APawn* Pawn = GetPawn();
    if (!Pawn || MobileMoveAxis.IsNearlyZero()) return;
    const FRotator YawOnly(0.f, GetControlRotation().Yaw, 0.f);
    Pawn->AddMovementInput(FRotationMatrix(YawOnly).GetUnitAxis(EAxis::X), MobileMoveAxis.Y);
    Pawn->AddMovementInput(FRotationMatrix(YawOnly).GetUnitAxis(EAxis::Y), MobileMoveAxis.X);
}
