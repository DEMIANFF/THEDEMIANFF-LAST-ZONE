package com.thedemianff.lastzone;

import android.app.Activity;
import com.google.android.gms.auth.api.signin.GoogleSignIn;
import com.google.android.gms.auth.api.signin.GoogleSignInAccount;
import com.google.android.gms.auth.api.signin.GoogleSignInOptions;
import com.google.android.gms.common.api.ApiException;
import com.google.android.gms.tasks.Task;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.GoogleAuthProvider;
import com.google.firebase.auth.FirebaseUser;
import com.google.firebase.firestore.FirebaseFirestore;
import com.google.firebase.firestore.FieldValue;
import java.util.HashMap;
import java.util.Map;
import org.json.JSONObject;
import android.content.Intent;
import android.webkit.JavascriptInterface;
import android.os.Bundle;
import android.content.SharedPreferences;
import android.webkit.WebChromeClient;
import android.webkit.ValueCallback;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.webkit.WebSettings;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.view.View;
import android.content.pm.ActivityInfo;
import android.net.Uri;
import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.io.IOException;
import java.net.URLConnection;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;

public class MainActivity extends Activity {
  private WebView web;
  private static final int GOOGLE_LOGIN_REQUEST=4420;
  private FirebaseAuth firebaseAuth;
  private void authMessage(String state,String detail) {
    runOnUiThread(() -> {
      if(web==null)return;
      String js="window.thedemianffGoogleResult&&window.thedemianffGoogleResult("+JSONObject.quote(state)+","+JSONObject.quote(detail)+")";
      web.evaluateJavascript(js,null);
    });
  }
  public final class GoogleAuthBridge {
    @JavascriptInterface public void signIn() {
      runOnUiThread(() -> {
        try {
          GoogleSignInOptions options=new GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
            .requestIdToken(getString(R.string.default_web_client_id)).requestEmail().build();
          startActivityForResult(GoogleSignIn.getClient(MainActivity.this,options).getSignInIntent(),GOOGLE_LOGIN_REQUEST);
        } catch(Exception ex) {authMessage("error","No se pudo abrir Google: "+ex.getClass().getSimpleName());}
      });
    }
    @JavascriptInterface public void signOut() {
      runOnUiThread(() -> {
        firebaseAuth.signOut();
        GoogleSignInOptions options=new GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
          .requestIdToken(getString(R.string.default_web_client_id)).requestEmail().build();
        // Firebase is signed out locally even if Google Play Services cannot complete its cleanup.
        authMessage("signed_out","Sesión local de Google cerrada.");
        GoogleSignIn.getClient(MainActivity.this,options).signOut().addOnFailureListener(ex ->
          android.util.Log.w("THEDEMIANFF","No se pudo completar la limpieza de Google Sign-In",ex));
      });
    }
    @JavascriptInterface public void status() {
      runOnUiThread(() -> {
        FirebaseUser user=firebaseAuth.getCurrentUser();
        authMessage(user==null?"signed_out":"signed_in",user==null?"":user.getEmail());
      });
    }
  }

  // V49.4: explicit, per-Google-account cloud backups. No guest data is auto-uploaded.
  private void cloudMessage(String state,String detail) {
    runOnUiThread(() -> {
      if(web==null)return;
      web.evaluateJavascript("window.thedemianffCloudResult&&window.thedemianffCloudResult("+
        JSONObject.quote(state)+","+JSONObject.quote(detail)+")",null);
    });
  }
  // A cloud response must never be attributed to a Google account that signed out
  // or changed while Firestore was completing an asynchronous request.
  private boolean cloudAccountUnchanged(String uid) {
    FirebaseUser current=firebaseAuth==null?null:firebaseAuth.getCurrentUser();
    return current!=null && current.getUid().equals(uid);
  }
  public final class CloudBridge {
    @JavascriptInterface public void save(String json) {
      runOnUiThread(() -> {
        FirebaseUser user=firebaseAuth.getCurrentUser();
        if(user==null){cloudMessage("error","Inicia sesión con Google para guardar en la nube.");return;}
        if(json==null||json.length()<10||json.length()>100000){cloudMessage("error","El progreso supera el tamaño permitido.");return;}
        final String requestUid=user.getUid();
        try {
          JSONObject p=new JSONObject(json);
          for(String key:new String[]{"credits","xp","matches","wins","kills","best","skin","weapon"}){
            Object value=p.opt(key);
            if(!(value instanceof Number)||((Number)value).doubleValue()!=((Number)value).longValue()||
                ((Number)value).longValue()<0||((Number)value).longValue()>100000000L)
              throw new IllegalArgumentException("Dato de progreso inválido.");
          }
          if(p.optLong("wins")>p.optLong("matches")||
             !(p.opt("unlocked") instanceof org.json.JSONArray)||
             !(p.opt("claimed") instanceof org.json.JSONArray))
            throw new IllegalArgumentException("El perfil no es válido.");
          if(p.optLong("best")>p.optLong("kills") ||
             p.optJSONArray("unlocked").length()>30 || p.optJSONArray("claimed").length()>100)
            throw new IllegalArgumentException("El perfil contiene estadísticas inconsistentes.");
          org.json.JSONArray unlocked=p.optJSONArray("unlocked"),claimed=p.optJSONArray("claimed");
          boolean baseUnlocked=false;
          for(int i=0;i<unlocked.length();i++) {
            Object v=unlocked.opt(i);
            if(!(v instanceof Number)||((Number)v).doubleValue()!=((Number)v).longValue()||
               ((Number)v).longValue()<0||((Number)v).longValue()>20)
              throw new IllegalArgumentException("Operador desbloqueado inválido.");
            if(((Number)v).longValue()==0)baseUnlocked=true;
          }
          if(!baseUnlocked)throw new IllegalArgumentException("Falta el operador inicial.");
          for(int i=0;i<claimed.length();i++) {
            Object v=claimed.opt(i);
            if(!(v instanceof String)||((String)v).length()>100)
              throw new IllegalArgumentException("Recompensa inválida.");
          }
          Map<String,Object> data=new HashMap<>();
          data.put("format",1);
          data.put("progress",json);
          data.put("updatedAt",FieldValue.serverTimestamp());
          FirebaseFirestore.getInstance().collection("player_backups").document(requestUid)
            .set(data).addOnSuccessListener(ignored->{
              if(cloudAccountUnchanged(requestUid))
                cloudMessage("saved","Respaldo guardado en Firebase para tu cuenta Google.");
              else cloudMessage("error","Cambió la cuenta Google durante el guardado. Verifica la cuenta y el respaldo.");
            }).addOnFailureListener(e->{
              if(cloudAccountUnchanged(requestUid))
                cloudMessage("error","No se pudo guardar en Firebase. Comprueba conexión y reglas de Firestore.");
            });
        }catch(Exception e){cloudMessage("error","Progreso inválido: "+e.getMessage());}
      });
    }
    @JavascriptInterface public void load() {
      runOnUiThread(() -> {
        FirebaseUser user=firebaseAuth.getCurrentUser();
        if(user==null){cloudMessage("error","Primero inicia sesión con tu cuenta Google.");return;}
        final String requestUid=user.getUid();
        FirebaseFirestore.getInstance().collection("player_backups").document(requestUid)
          .get(com.google.firebase.firestore.Source.SERVER).addOnSuccessListener(doc->{
            if(!cloudAccountUnchanged(requestUid)){
              cloudMessage("error","Cambió la cuenta Google durante la recuperación. No se restauró nada.");return;
            }
            String saved=doc.exists()?doc.getString("progress"):null;
            Long format=doc.exists()?doc.getLong("format"):null;
            // A missing document is a new account; an invalid existing document is
            // an ERROR and must NEVER trigger creation that overwrites saved data.
            if(!doc.exists()){
              cloudMessage("missing","Esta cuenta Google todavía no tiene progreso guardado.");return;
            }
            if(saved==null||saved.length()<10||saved.length()>100000||format==null||format!=1L){
              cloudMessage("error","El respaldo remoto existe pero no es válido. No se sobrescribirá.");return;
            }
            cloudMessage("loaded",saved);
          }).addOnFailureListener(e->{
            if(cloudAccountUnchanged(requestUid))
              cloudMessage("error","No se pudo recuperar el respaldo de Firebase. Revisa conexión y permisos.");
          });
      });
    }
  }

  // Load bundled models via a secure HTTPS origin, matching browser HTTP semantics.
  private static final String GAME_ORIGIN="https://appassets.androidplatform.net";
  private static final String GAME_PREFIX="/assets/";
  private ValueCallback<Uri[]> backupFileCallback;
  private static final int BACKUP_FILE_REQUEST=3021;
  private static final int BACKUP_SAVE_REQUEST=3022;
  private String pendingBackupContent;
  // Private on-device recovery slot survives ordinary in-place APK updates.
  // It does NOT survive every uninstall, factory reset or data deletion.
  private static final String GUEST_PREFS="thedemianff_guest_auto_v1";
  public final class GuestStorageBridge {
    @JavascriptInterface public String readProgress() {
      return getSharedPreferences(GUEST_PREFS,MODE_PRIVATE).getString("progress","");
    }
    @JavascriptInterface public String readGuestId() {
      return getSharedPreferences(GUEST_PREFS,MODE_PRIVATE).getString("guestId","");
    }
    // Rollback helpers remove only the named native field; never clear all app data.
    @JavascriptInterface public boolean clearProgress() {
      return getSharedPreferences(GUEST_PREFS,MODE_PRIVATE).edit().remove("progress").commit();
    }
    @JavascriptInterface public boolean clearGuestId() {
      return getSharedPreferences(GUEST_PREFS,MODE_PRIVATE).edit().remove("guestId").commit();
    }
    @JavascriptInterface public boolean saveProgress(String json) {
      if(json==null||json.length()<10||json.length()>100000)return false;
      try{
        org.json.JSONObject parsed=new org.json.JSONObject(json);
        for(String key:new String[]{"credits","xp","matches","wins","kills","best","skin","weapon"}) {
          Object value=parsed.opt(key);
          if(!(value instanceof Number))return false;
          long num=((Number)value).longValue();
          if(num<0||num>100000000L||((Number)value).doubleValue()!=num)return false;
        }
        if(parsed.optLong("wins")>parsed.optLong("matches"))return false;
        if(!(parsed.opt("unlocked") instanceof org.json.JSONArray)||
           !(parsed.opt("claimed") instanceof org.json.JSONArray))return false;
        org.json.JSONArray unlocked=parsed.optJSONArray("unlocked"),claimed=parsed.optJSONArray("claimed");
        if(unlocked.length()>30||claimed.length()>100)return false;
        for(int i=0;i<unlocked.length();i++) {
          Object value=unlocked.opt(i);
          if(!(value instanceof Number)||((Number)value).doubleValue()!=((Number)value).longValue())return false;
          if(((Number)value).longValue()<0||((Number)value).longValue()>20)return false;
        }
        for(int i=0;i<claimed.length();i++) {
          String item=claimed.optString(i,null);
          if(!(claimed.opt(i) instanceof String)||item==null||item.length()>100)return false;
        }
        return getSharedPreferences(GUEST_PREFS,MODE_PRIVATE).edit().putString("progress",json).commit();
      }catch(Exception e){return false;}
    }
    @JavascriptInterface public boolean saveGuestId(String id) {
      if(id==null||!id.matches("GUEST-[a-z0-9-]{4,80}"))return false;
      return getSharedPreferences(GUEST_PREFS,MODE_PRIVATE).edit().putString("guestId",id).commit();
    }
  }
  public final class BackupBridge {
    @JavascriptInterface public void saveBackup(String content) {
      if(content==null || content.length()<10 || content.length()>1000000)return;
      runOnUiThread(() -> {
        try {
          pendingBackupContent=content;
          Intent intent=new Intent(Intent.ACTION_CREATE_DOCUMENT);
          intent.addCategory(Intent.CATEGORY_OPENABLE);
          intent.setType("application/json");
          intent.putExtra(Intent.EXTRA_TITLE,"THEDEMIANFF_INVITADO_RESPALDO.json");
          startActivityForResult(intent,BACKUP_SAVE_REQUEST);
        }catch(Exception ex){pendingBackupContent=null;}
      });
    }

    @JavascriptInterface public void shareBackup(String content) {
      if(content==null || content.length()<10 || content.length()>1000000) return;
      runOnUiThread(() -> {
        Intent send=new Intent(Intent.ACTION_SEND);
        send.setType("text/plain");
        send.putExtra(Intent.EXTRA_SUBJECT,"THEDEMIANFF - Respaldo de progreso");
        send.putExtra(Intent.EXTRA_TEXT,content);
        startActivity(Intent.createChooser(send,"Guardar respaldo fuera del juego"));
      });
    }
  }
  public final class GameBridge {
    @JavascriptInterface public void exitGame() {
      runOnUiThread(() -> { if(web!=null)web.stopLoading(); finish(); });
    }
  }
  private void immersive() {
    getWindow().getDecorView().setSystemUiVisibility(
      View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY |
      View.SYSTEM_UI_FLAG_FULLSCREEN |
      View.SYSTEM_UI_FLAG_HIDE_NAVIGATION |
      View.SYSTEM_UI_FLAG_LAYOUT_STABLE |
      View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN |
      View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION);
  }
  @Override public void onCreate(Bundle state) {
    super.onCreate(state);
    firebaseAuth=FirebaseAuth.getInstance();
    setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE);
    immersive();
    web=new WebView(this);
    web.setBackgroundColor(0xff10151b);
    WebSettings settings=web.getSettings();
    settings.setJavaScriptEnabled(true);
    settings.setDomStorageEnabled(true);
    settings.setAllowFileAccess(true);
    settings.setAllowContentAccess(false);
    settings.setJavaScriptCanOpenWindowsAutomatically(false);
    settings.setMediaPlaybackRequiresUserGesture(true);
    web.setWebChromeClient(new WebChromeClient() {
      @Override public boolean onShowFileChooser(WebView view, ValueCallback<Uri[]> callback, FileChooserParams params) {
        if(backupFileCallback!=null) backupFileCallback.onReceiveValue(null);
        backupFileCallback=callback;
        try {
          Intent intent=new Intent(Intent.ACTION_GET_CONTENT);
          intent.addCategory(Intent.CATEGORY_OPENABLE);
          intent.setType("application/json");
          intent.putExtra(Intent.EXTRA_MIME_TYPES,new String[]{"application/json","text/plain","application/octet-stream"});
          startActivityForResult(Intent.createChooser(intent,"Seleccionar respaldo THEDEMIANFF"),BACKUP_FILE_REQUEST);
          return true;
        } catch(Exception ex) {
          backupFileCallback=null;
          callback.onReceiveValue(null);
          return false;
        }
      }
    });
    web.addJavascriptInterface(new GoogleAuthBridge(),"THEDEMIANFFGoogle");
    web.addJavascriptInterface(new CloudBridge(),"THEDEMIANFFCloud");
    web.addJavascriptInterface(new BackupBridge(),"THEDEMIANFFBackup");
    web.addJavascriptInterface(new GuestStorageBridge(),"THEDEMIANFFGuestStore");
    web.addJavascriptInterface(new GameBridge(),"THEDEMIANFFGame");
    web.setWebViewClient(new WebViewClient() {
      @Override public boolean shouldOverrideUrlLoading(WebView view,WebResourceRequest request) {
        Uri uri=request.getUrl();
        return !"file".equals(uri.getScheme());
      }
      @Override public WebResourceResponse shouldInterceptRequest(WebView view,WebResourceRequest request) {
        Uri uri=request.getUrl();
        if ("https".equals(uri.getScheme()) &&
            "appassets.androidplatform.net".equals(uri.getHost()) &&
            uri.getPort()==-1 && uri.getPath()!=null &&
            uri.getPath().startsWith(GAME_PREFIX)) {
          String relative=uri.getPath().substring(GAME_PREFIX.length());
          // Prevent dot-segment traversal; only serve bundled Android assets.
          if(relative.isEmpty() || relative.startsWith("/") ||
             relative.contains("..") || relative.contains("\\")) {
            return new WebResourceResponse("text/plain","UTF-8",
                new ByteArrayInputStream(new byte[0]));
          }
          try {
            InputStream body=getAssets().open(relative);
            String mime=URLConnection.guessContentTypeFromName(relative);
            if(relative.endsWith(".js"))mime="application/javascript";
            if(relative.endsWith(".glb"))mime="model/gltf-binary";
            if(relative.endsWith(".html"))mime="text/html";
            if(mime==null)mime="application/octet-stream";
            WebResourceResponse response=new WebResourceResponse(mime,"UTF-8",body);
            response.setStatusCodeAndReasonPhrase(200,"OK");
            return response;
          }catch(IOException e){
            android.util.Log.e("THEDEMIANFF","Missing bundled asset: "+relative,e);
            WebResourceResponse missing=new WebResourceResponse("text/plain","UTF-8",
                new ByteArrayInputStream(new byte[0]));
            missing.setStatusCodeAndReasonPhrase(404,"Not Found");
            return missing;
          }
        }
        return new WebResourceResponse("text/plain","UTF-8",
            new ByteArrayInputStream(new byte[0]));
      }
    });
    setContentView(web);
    web.loadUrl(GAME_ORIGIN+GAME_PREFIX+"index.html");
  }
  @Override protected void onActivityResult(int requestCode,int resultCode,Intent data) {
    super.onActivityResult(requestCode,resultCode,data);
    if(requestCode==GOOGLE_LOGIN_REQUEST) {
      if(resultCode!=RESULT_OK) {authMessage("cancelled","Inicio de sesión cancelado.");return;}
      Task<GoogleSignInAccount> task=GoogleSignIn.getSignedInAccountFromIntent(data);
      try {
        GoogleSignInAccount account=task.getResult(ApiException.class);
        if(account==null||account.getIdToken()==null) {authMessage("error","Google no devolvió un token válido.");return;}
        firebaseAuth.signInWithCredential(GoogleAuthProvider.getCredential(account.getIdToken(),null))
          .addOnCompleteListener(this,result -> {
            if(result.isSuccessful()&&firebaseAuth.getCurrentUser()!=null)
              authMessage("signed_in",firebaseAuth.getCurrentUser().getEmail());
            else authMessage("error","Firebase rechazó el acceso. Comprueba conexión y SHA-1.");
          });
      }catch(ApiException ex){authMessage("error","Google Sign-In falló (código "+ex.getStatusCode()+").");}
      return;
    }
    if(requestCode==BACKUP_SAVE_REQUEST) {
      String content=pendingBackupContent;
      pendingBackupContent=null;
      if(resultCode==RESULT_OK && data!=null && data.getData()!=null && content!=null) {
        try(OutputStream out=getContentResolver().openOutputStream(data.getData())) {
          if(out!=null)out.write(content.getBytes(StandardCharsets.UTF_8));
        }catch(Exception ex){android.util.Log.e("THEDEMIANFF","No se pudo guardar el respaldo",ex);}
      }
    }
    if(requestCode==BACKUP_FILE_REQUEST) {
      ValueCallback<Uri[]> callback=backupFileCallback;
      backupFileCallback=null;
      if(callback!=null) {
        Uri uri=resultCode==RESULT_OK && data!=null?data.getData():null;
        callback.onReceiveValue(uri!=null?new Uri[]{uri}:null);
      }
    }
  }
  @Override public void onWindowFocusChanged(boolean focused){super.onWindowFocusChanged(focused);if(focused)immersive();}
  @Override public void onBackPressed(){
    // Let the game handle pause via its on-screen menu; avoid accidental exits.
    if(web!=null)web.evaluateJavascript("typeof pause==='function'&&typeof running!=='undefined'&&running?pause():void 0",null);
  }
  @Override protected void onDestroy(){if(web!=null){web.destroy();web=null;}super.onDestroy();}
}
