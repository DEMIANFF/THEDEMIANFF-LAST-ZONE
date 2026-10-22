package com.thedemianff.lastzone;

import android.app.Activity;
import android.content.Intent;
import android.webkit.JavascriptInterface;
import android.os.Bundle;
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

public class MainActivity extends Activity {
  private WebView web;
  private ValueCallback<Uri[]> backupFileCallback;
  private static final int BACKUP_FILE_REQUEST=3021;
  public final class BackupBridge {
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
    web.addJavascriptInterface(new BackupBridge(),"THEDEMIANFFBackup");
    web.setWebViewClient(new WebViewClient() {
      @Override public boolean shouldOverrideUrlLoading(WebView view,WebResourceRequest request) {
        Uri uri=request.getUrl();
        return !"file".equals(uri.getScheme());
      }
      @Override public WebResourceResponse shouldInterceptRequest(WebView view,WebResourceRequest request) {
        Uri uri=request.getUrl();
        if(!"file".equals(uri.getScheme())) {
          return new WebResourceResponse("text/plain","UTF-8",
             new ByteArrayInputStream(new byte[0]));
        }
        return super.shouldInterceptRequest(view,request);
      }
    });
    setContentView(web);
    web.loadUrl("file:///android_asset/index.html");
  }
  @Override protected void onActivityResult(int requestCode,int resultCode,Intent data) {
    super.onActivityResult(requestCode,resultCode,data);
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
