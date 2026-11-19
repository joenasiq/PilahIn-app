import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilahin_app/features/profile/data/avatar_cropper.dart';
import 'package:pilahin_app/features/profile/data/avatar_service.dart';

void main() {
  group('mapAvatarUploadError', () {
    test('izin ditolak tidak ditawari coba lagi', () {
      final error = mapAvatarUploadError('permission-denied');

      expect(error.code, 'permission-denied');
      expect(error.retryable, isFalse);
      expect(error.message, contains('izin'));
    });

    test('sesi habis tidak ditawari coba lagi', () {
      final error = mapAvatarUploadError('unauthenticated');

      expect(error.retryable, isFalse);
      expect(error.message, contains('masuk kembali'));
    });

    test('error koneksi boleh diulang dengan pesan koneksi', () {
      for (final code in [
        'unavailable',
        'deadline-exceeded',
        'aborted',
        'internal',
        'unknown',
      ]) {
        final error = mapAvatarUploadError(code);

        expect(error.code, code);
        expect(error.retryable, isTrue, reason: 'kode $code');
        expect(error.message.toLowerCase(), contains('koneksi'));
      }
    });

    test('kuota penuh punya pesan sendiri dan tidak diulang', () {
      for (final code in ['resource-exhausted', 'quota-exceeded']) {
        final error = mapAvatarUploadError(code);

        expect(error.retryable, isFalse, reason: 'kode $code');
        expect(error.message, contains('Kuota'));
      }
    });

    test('foto tidak didukung meminta pilih foto lain', () {
      for (final code in ['invalid-argument', 'out-of-range']) {
        final error = mapAvatarUploadError(code);

        expect(error.retryable, isFalse, reason: 'kode $code');
        expect(error.message, contains('foto lain'));
      }
    });

    test('kode tak dikenal tetap bisa diulang dan mempertahankan kodenya', () {
      final error = mapAvatarUploadError('some-new-code');

      expect(error.code, 'some-new-code');
      expect(error.retryable, isTrue);
    });
  });

  group('AvatarService konfigurasi', () {
    test('batas payload base64 masih di bawah 1 MiB Firestore', () {
      // base64 membengkak 4/3; pastikan hasilnya tetap < 1 MiB per dokumen.
      const firestoreLimit = 1024 * 1024;
      final encodedSize = (AvatarService.maxPayloadBytes * 4 / 3).ceil();

      expect(encodedSize, lessThan(firestoreLimit));
    });

    test('langkah kualitas menurun agar foto besar tetap muat', () {
      expect(AvatarService.qualitySteps.first, 85);
      expect(AvatarService.qualitySteps.last, lessThan(85));
      // Urutan harus menurun supaya kualitas terbaik dipakai lebih dulu.
      for (var i = 1; i < AvatarService.qualitySteps.length; i++) {
        expect(
          AvatarService.qualitySteps[i],
          lessThan(AvatarService.qualitySteps[i - 1]),
        );
      }
    });

    test('penanda versi foto memakai awalan fs:', () {
      expect(AvatarService.markerPrefix, 'fs:');
    });

    test('dimensi PNG menurun agar tetap muat tanpa JPEG', () {
      expect(avatarPngSizeSteps.first, avatarOutputDimension);
      for (var i = 1; i < avatarPngSizeSteps.length; i++) {
        expect(avatarPngSizeSteps[i], lessThan(avatarPngSizeSteps[i - 1]));
      }
      expect(avatarCircleMaxBytes, AvatarService.maxPayloadBytes);
    });
  });

  group('isPngBytes', () {
    test('mendeteksi signature PNG', () {
      final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0]);
      expect(isPngBytes(png), isTrue);
    });

    test('JPEG bukan PNG', () {
      final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0]);
      expect(isPngBytes(jpeg), isFalse);
    });

    test('byte pendek bukan PNG', () {
      expect(isPngBytes(Uint8List.fromList([0x89, 0x50])), isFalse);
      expect(isPngBytes(Uint8List(0)), isFalse);
    });
  });
}
