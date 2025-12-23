import 'package:flutter/material.dart';
import 'package:logarte/logarte.dart';

/// Shared Logarte instance for logging and network overlay.
final logarte = Logarte();

/// Navigator key to obtain a context that has an Overlay (root navigator).
final GlobalKey<NavigatorState> logarteNavigatorKey = GlobalKey<NavigatorState>();

/// Safely attach the Logarte overlay once an Overlay is available.
void attachLogarteOverlayIfNeeded({BuildContext? context, int retries = 5}) {
  if (logarte.isOverlayAttached) return;
  final overlayCtx = context ?? logarteNavigatorKey.currentContext;
  if (overlayCtx == null) {
    if (retries > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        attachLogarteOverlayIfNeeded(retries: retries - 1);
      });
    }
    return;
  }
  // Use root overlay context to avoid "No Overlay widget found".
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!logarte.isOverlayAttached) {
      try {
        logarte.attach(context: overlayCtx, visible: true);
      } catch (e) {
        if (retries > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            attachLogarteOverlayIfNeeded(context: overlayCtx, retries: retries - 1);
          });
        }
        // Swallow to avoid crash; will retry on next frame.
      }
    }
  });
}
