# PR #30 — Prueba física única del cierre al abrir paracaídas (Motorola Edge 60 Fusion)

## Estado e interpretación
En las versiones de prueba V75.17 y V75.18 el último estado persistido fue `parachute / canopy_deployed` a Y=32.9407. Esa pista **no** identifica señal o backtrace nativos. V75.19 de GitHub aprobó CI, pero aún no ha tenido confirmación física de aterrizaje en Motorola.

La compilación **AUDITORIA PARACAIDAS** del PR #30 integra en un único APK Android ARM64 con identificador separado:
- Despliegue automático del paracaídas diferido tras la detección de altura, sin reconfigurar HUD ni estado del personaje dentro del callback de física.
- Malla del paracaídas precargada en el mundo, sin crearse al abrirse en vuelo.
- Selector desde **bienvenida → VUELO ...** con cuatro estados persistentes. Los estados desactivan *solamente* opciones visuales temporales de diagnóstico: la física del paracaídas, las colisiones del personaje y el control de descenso siguen funcionales.
- Informes `COPIAR DATOS DEL VUELO` contienen el modo de prueba, eventos anteriores al primer tick, velocidad, altura, FPS e historial. No reemplazan `logcat` del dispositivo.

## Plan de pruebas eficientes

1. Con la APK de auditoría (no la V75.19 antigua), abre la pantalla **Bienvenida** y selecciona **VUELO 0 / NORMAL (COMPLETO)**. Entra en el Battle Royale y completa avión → caída → paracaídas → aterrizaje. Si vuelve a cerrarse, copia los datos al reabrir la aplicación.
2. Si falla el modo 0, en Bienvenida pulsa sucesivamente hasta **VUELO 3 / SIN AMBAS (DIAGNOSTICO)**. Esta es una prueba de aislamiento: la lona 3D y la animación específica del paracaídas no se muestran, **pero el personaje conserva la desaceleración y aterrizaje físicos**. Intenta el mismo vuelo y copia el reporte si falla.
3. Si el modo 3 aterriza, probar los modos 1 y 2 por separado (uno sin nueva animación, el otro sin lona 3D). Esto ayuda a discriminar:
   - 1 correcto / 2 falla → animación esquelética o rig más sospechosa.
   - 2 correcto / 1 falla → recurso/render de la lona más sospechoso.
   - 1 y 2 fallan / 3 correcto → interacción de dos subsistemas, no necesariamente uno aislado.
   - 3 también falla → operaciones compartidas aún sospechosas: física, HUD, engine/driver, terminación por Android.
4. Tras las pruebas, restaura **VUELO 0 NORMAL**. Las opciones 1–3 son SOLO diagnóstico y no son acabado gráfico del BR.

Si falla incluso el modo 3, **no seguir modificando a ciegas**: tras el cierre, Android > Opciones de desarrollador > Crear informe de errores. Abrir y revisar antes de compartir porque puede contener datos sensibles. Preferir extractos `FATAL EXCEPTION`, `Fatal signal`, `SIGSEGV`, `SIGABRT`, `libgodot_android.so`, `ActivityManager`, `lowmemorykiller` del paquete `com.thedemianff.lastzone.nativeauditcanopy`. Alternativa con ADB conectado y autorizado: `adb logcat -b crash -d`. Termux no suele poder leer registros de otra app en Android 16 sin privilegios.

**Éxito requiere** al menos 3 vuelos completos con física, render y controles normales en un Motorola; `GitHub Actions PASS` y `apksigner PASS` solo aprueban CI Linux/export Android y no garantizan estabilidad física.

Se mantienen protegidos `v44-3-2-autosave-guest`, Firebase, Unity V76, certificados originales y datos anteriores. Esta vista previa tiene un sector **offline** de 9 participantes (1+8), no red de 50/100 jugadores.
