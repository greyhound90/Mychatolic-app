import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionPrompt {
  static Future<bool> requestCamera(BuildContext context) async {
    return _request(
      context,
      permission: Permission.camera,
      title: "Izin Kamera Dibutuhkan",
      message:
          "Aktifkan izin kamera agar Anda dapat mengambil foto langsung dari aplikasi.",
    );
  }

  static Future<bool> requestGallery(BuildContext context) async {
    if (Platform.isIOS) {
      return _request(
        context,
        permission: Permission.photos,
        title: "Izin Foto Dibutuhkan",
        message:
            "Aktifkan izin foto agar Anda dapat memilih gambar dari galeri.",
      );
    }

    if (Platform.isAndroid) {
      final photoStatus = await Permission.photos.request();
      if (photoStatus.isGranted) return true;

      final storageStatus = await Permission.storage.request();
      if (storageStatus.isGranted) return true;

      return _showDeniedDialog(
        context,
        title: "Izin Galeri Dibutuhkan",
        message:
            "Aktifkan izin galeri agar Anda dapat memilih foto dari perangkat.",
      );
    }

    return true;
  }

  static Future<bool> requestLocation(BuildContext context) async {
    return _request(
      context,
      permission: Permission.location,
      title: "Izin Lokasi Dibutuhkan",
      message:
          "Aktifkan izin lokasi agar Anda dapat membagikan lokasi saat ini.",
    );
  }

  static Future<bool> requestMicrophone(BuildContext context) async {
    return _request(
      context,
      permission: Permission.microphone,
      title: "Izin Mikrofon Dibutuhkan",
      message:
          "Aktifkan izin mikrofon agar Anda dapat mengirim pesan suara.",
    );
  }

  static Future<bool> _request(
    BuildContext context, {
    required Permission permission,
    required String title,
    required String message,
  }) async {
    final status = await permission.request();
    if (status.isGranted) return true;
    return _showDeniedDialog(context, title: title, message: message);
  }

  static Future<bool> _showDeniedDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    if (!context.mounted) return false;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Nanti"),
          ),
          TextButton(
            onPressed: () async {
              await openAppSettings();
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text("Buka Pengaturan"),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
