#include "AuroraGameMode.h"
#include "AuroraCharacter.h"
#include "AuroraMobileController.h"

AAuroraGameMode::AAuroraGameMode()
{
    DefaultPawnClass = AAuroraCharacter::StaticClass();
    PlayerControllerClass = AAuroraMobileController::StaticClass();
}
