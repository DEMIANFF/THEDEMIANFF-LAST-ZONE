#include "AuroraGameMode.h"
#include "AuroraCharacter.h"

AAuroraGameMode::AAuroraGameMode()
{
    DefaultPawnClass = AAuroraCharacter::StaticClass();
}
