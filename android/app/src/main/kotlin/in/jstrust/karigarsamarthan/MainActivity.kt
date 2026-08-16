package `in`.jstrust.karigarsamarthan

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Android draws an automatic translucent scrim behind a "transparent"
        // navigation bar by default (Window.isNavigationBarContrastEnforced),
        // which is what makes it look solid/opaque even after the Dart-side
        // SystemChrome call asks for Colors.transparent - this is the actual
        // switch that turns it off. API 29+ only; older devices ignore this.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced = false
        }
    }
}
