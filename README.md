# THEDEMIANFF V20 — Android offline (proyecto fuente)

## Alcance real
Este proyecto empaqueta la versión V18 **probada en el Motorola Edge 60 Fusion**
dentro de un WebView Android con aceleración GPU, pantalla completa y orientación horizontal.
Incluye enemigos IA, mapa, armas, cámaras, menús y progresión local de V18.

**No es todavía un APK compilado**, ni un cliente Unity, ni multijugador.
La aplicación no solicita permiso INTERNET: una vez compilada con `three.min.js`
incluido, puede iniciarse y jugarse en modo avión.

## Cómo generar APK
1. Abrir esta carpeta como proyecto en Android Studio con JDK 17.
2. Esperar sincronización Gradle (Android Gradle Plugin 8.7.3 y SDK 35).
3. La primera compilación requiere Internet para Gradle y para descargar
   `three.min.js` versión 0.160.1 dentro de los assets. Si no hay Internet
   en la compilación, colocar manualmente el archivo en
   `app/src/main/assets/three.min.js`.
4. Compilar con Build > Build APK(s) o `gradle assembleDebug`.
5. Instalar `app/build/outputs/apk/debug/app-debug.apk` en el Motorola.
6. Activar modo avión y comprobar que menú, mapa, bots, sonidos, controles y
   reinicios funcionan sin conexión.

## Límites
- No hay servicios de cuenta remotos, sincronización ni pagos.
- Los datos de progreso se guardan localmente con localStorage del WebView.
- El rendimiento del WebView puede variar frente a Chrome; medir FPS y temperatura.
- El código fuente HTML usa Three.js 0.160.1: conservar esa versión al empaquetar.
- No cambiar el identificador de paquete después de publicar sin plan de migración.
- No hay garantía de funcionamiento hasta compilar y probar en dispositivo.

## Próxima fase
Perfil de rendimiento, ajustes táctiles específicos de WebView, guardado local
robusto, pruebas de regresión y luego migración progresiva a motor nativo si
las limitaciones de gráficos y red lo justifican.

## Compilación en la nube desde el teléfono
El proyecto incluye `.github/workflows/build-apk.yml`. Al subir los archivos
**del interior de esta carpeta** a la raíz de un repositorio GitHub, la acción
de GitHub compila una APK debug y la publica como artefacto descargable.
Se puede iniciar desde GitHub > Actions > Compilar APK offline THEDEMIANFF >
Run workflow. GitHub Actions necesita Internet durante la compilación,
pero la APK resultante no lo necesita para jugar.

El flujo no está ejecutado ni verificado en GitHub: si la compilación falla,
compartir el registro del error para corregirlo.
