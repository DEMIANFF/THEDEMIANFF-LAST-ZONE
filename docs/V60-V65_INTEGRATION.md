# V60–V65 — Integración del Battle Royale

La base es codex/recover-v58-9-ci, descendiente directo por 30 commits de v58-9-0-awm-camera-airdrop-release, que a su vez desciende de v58-integration-audit. Se usa la cadena de recuperación que restaura la declaración del controlador de cámara V58 y ya tuvo una ejecución de Actions correcta (#739). La rama V59 divergente no se incorporó.

## Entregas integradas

| Etapa | Implementación |
|---|---|
| V60 | Arsenal de seis armas, AWM con x8 exclusiva, cerrojo y entrada directa por teclado 6. Número Android 173. |
| V61 | Base Aurora, edificios, interiores, puertas y colisiones ya presentes en la línea V58; las pruebas cubren accesos y aterrizajes seguros. |
| V62 | Bots con roles, detección, cobertura, persecución, reacción al daño, combate entre rivales y selección segura de aparición. |
| V63 | Munición compartida por calibre; mochilas ligera, asalto y táctica amplían topes de munición y botiquines. Los suministros pueden dejar mochilas épicas; la mochila permanece en el mundo si el inventario está al máximo. |
| V64 | Lobby, cuenta, perfil, modos, armas, misiones, pase y progresión local/nube conservados. |
| V65 | Zona progresiva y daño exterior, ruta de avión, mapa, salto, planeador, victoria y resultados. Renderizado móvil con resolución adaptativa, límite de pixel ratio, sombras reducidas y telemetría. |

## Pruebas

La suite cubre el servicio de identidad, aislamiento entre cuentas, armas, cámara, mapa/despliegue, botín, apariciones, zona, progresión, lobby y recursos visuales. Las pruebas estáticas y de lógica local no sustituyen una partida real en Android.

El flujo no afirma multijugador en línea. La configuración de rendimiento sirve como punto de partida para Motorola Edge 60 Fusion; no hay una prueba física del dispositivo registrada en esta entrega.

## Publicación

app/build.gradle usa versionCode 173, superior a V58.2.1 (158) y V58.9.0 (167). El workflow conserva la configuración de keystore existente y publica el artefacto release solo cuando el secreto permanente está presente. No se requiere ni se crea un keystore nuevo.

## V65 quality pass — `codex/v60-v65-quality-fixes`

- **AWM:** cada disparo exige accionar manualmente el cerrojo antes de permitir otro; el perfil x8 continúa exclusivo de AWM.
- **Despliegue:** el mapa táctico puede abrirse durante el descenso; la cámara de vuelo V58 se conserva. El operador despliega un planeador alado dorado de bajo coste geométrico, con costillas y líneas de suspensión.
- **Terreno:** la altura física usa la misma función de elevación de la malla visible, alineando suelo, colisiones y aterrizajes.
- **Inventario:** la mochila expone una matriz de casillas para armas, reservas por calibre, botiquines, blindaje y espacios vacíos. Los pickups respetan capacidad de pila y espacio.
- **APK:** `versionCode 174`, `versionName 65.0.0-aurora-royale-quality-pass`. Se conserva la configuración de firma existente; no se cambian credenciales de Firebase ni el keystore.
- **Aceptación pendiente:** Actions y pruebas Android reales. La validación automatizada no sustituye la comprobación táctil, visual y de rendimiento en Motorola Edge 60 Fusion.
