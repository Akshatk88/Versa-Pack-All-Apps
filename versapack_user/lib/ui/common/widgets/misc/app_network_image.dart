import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../../../core/network/media_url.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/logger.dart';
import '../loaders/shimmer_box.dart';

/// Cached network image with a shimmer placeholder and a non-broken fallback.
///
/// Decoding is capped to the actual rendered size in device pixels, so a large
/// catalog photo never becomes an unnecessarily large thumbnail decode.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.shopping_basket_outlined,
    this.desaturated = false,
    this.debugLabel,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final IconData fallbackIcon;

  /// Out-of-stock products render greyed out.
  final bool desaturated;
  final String? debugLabel;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = MediaUrl.resolve(url);
    if (!MediaUrl.isHttpUrl(resolvedUrl)) {
      _logInvalidUrl(resolvedUrl);
      return _fallback(context);
    }

    final requestUrl = ImagePipelineDiagnostics.requestUrl(resolvedUrl);
    ImagePipelineDiagnostics.probeOnce(requestUrl, label: debugLabel);

    // Product cards intentionally pass infinity so their image fills the space
    // left by metadata. LayoutBuilder sees that resolved space, unlike the
    // widget arguments, and gives every caller a bounded decoder.
    final image = LayoutBuilder(
      builder: (context, constraints) {
        final ratio = MediaQuery.devicePixelRatioOf(context);
        final cacheWidth = _cachePixels(
          _renderedDimension(constraints.maxWidth, width),
          ratio,
        );
        final cacheHeight = _cachePixels(
          _renderedDimension(constraints.maxHeight, height),
          ratio,
        );

        if (ImagePipelineDiagnostics.useImageNetwork) {
          return Image.network(
            requestUrl,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, error, stackTrace) {
              _logImageError(requestUrl, error);
              return _fallback(context);
            },
          );
        }

        return CachedNetworkImage(
          imageUrl: requestUrl,
          width: width,
          height: height,
          fit: fit,
          memCacheWidth: cacheWidth,
          memCacheHeight: cacheHeight,
          fadeInDuration: const Duration(milliseconds: 200),
          placeholder: (_, _) =>
              ShimmerBox(width: width, height: height ?? 100),
          errorWidget: (_, requestedUrl, error) {
            _logImageError(requestedUrl, error);
            return _fallback(context);
          },
        );
      },
    );

    if (!desaturated) return image;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ]),
      child: image,
    );
  }

  /// The final layout constraint wins. The explicit size is only a fallback
  /// for callers that are not constrained by a parent.
  static double? _renderedDimension(double constrained, double? requested) {
    if (constrained.isFinite && constrained > 0) {
      return constrained;
    }
    if (requested != null && requested.isFinite && requested > 0) {
      return requested;
    }
    return null;
  }

  /// Decode budget in device pixels, or null when the dimension is unbounded.
  static int? _cachePixels(double? logical, double ratio) {
    if (logical == null || !logical.isFinite || logical <= 0) {
      return null;
    }
    // Avoid accidental full-resolution decodes in a loose or oversized parent.
    return (logical * ratio).round().clamp(1, 4096).toInt();
  }

  static final Set<String> _reportedFailures = <String>{};

  static void _logInvalidUrl(String resolvedUrl) {
    _logOnce(
      'invalid:$resolvedUrl',
      'Image URL is not an HTTP(S) URL: "$resolvedUrl"',
    );
  }

  static void _logImageError(String requestedUrl, Object error) {
    final statusCode = _httpStatusCode(error);
    final status = statusCode == null ? '' : ' HTTP $statusCode';
    final kind = statusCode == null ? 'network/decode failure' : 'HTTP failure';
    _logOnce(
      '$requestedUrl:${error.runtimeType}:$status',
      'Image $kind$status for "$requestedUrl"',
      error: error,
    );
  }

  // CachedNetworkImage exposes HTTP failures from flutter_cache_manager. Keep
  // that implementation detail out of this widget's public dependencies while
  // still including its status code when it is available.
  static int? _httpStatusCode(Object error) {
    try {
      final status = (error as dynamic).statusCode;
      return status is int ? status : null;
    } on NoSuchMethodError {
      return null;
    }
  }

  /// Image streams can report the same failed key on every rebuild. Keep debug
  /// diagnostics useful without turning a missing image into log spam.
  static void _logOnce(String key, String message, {Object? error}) {
    if (!kDebugMode || !_reportedFailures.add(key)) {
      return;
    }
    AppLogger.error(message, error: error);
  }

  Widget _fallback(BuildContext context) => Container(
    width: width,
    height: height,
    color: context.semantic.surfaceAlt,
    alignment: Alignment.center,
    child: Icon(
      fallbackIcon,
      size: ((height ?? 48) * 0.34).clamp(16, 40),
      color: context.semantic.textSecondary,
    ),
  );
}

/// Temporary Android image-pipeline harness. It is entirely disabled unless a
/// build supplies IMAGE_PIPELINE_DIAGNOSTICS=true. Remove after the four-way
/// device matrix has been recorded.
abstract final class ImagePipelineDiagnostics {
  static const enabled = bool.fromEnvironment('IMAGE_PIPELINE_DIAGNOSTICS');
  static const useImageNetwork = bool.fromEnvironment('IMAGE_PIPELINE_NETWORK');
  static const clearCaches = bool.fromEnvironment(
    'IMAGE_PIPELINE_CLEAR_CACHES',
  );
  static const cacheBuster = String.fromEnvironment(
    'IMAGE_PIPELINE_CACHE_BUSTER',
  );
  static final Set<String> _probed = <String>{};
  static bool _cachesCleared = false;

  static String requestUrl(String url) {
    if (!enabled || cacheBuster.isEmpty) return url;
    final uri = Uri.parse(url);
    return uri
        .replace(
          queryParameters: {...uri.queryParameters, 'debug': cacheBuster},
        )
        .toString();
  }

  static void probeOnce(String url, {String? label}) {
    if (!enabled || !kDebugMode || !_probed.add(url)) return;
    unawaited(_probe(url, label: label));
  }

  static Future<void> _probe(String url, {String? label}) async {
    if (clearCaches && !_cachesCleared) {
      _cachesCleared = true;
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await DefaultCacheManager().emptyCache();
      AppLogger.debug('IMAGE_CACHE_CLEARED', scope: 'image');
    }
    final uri = Uri.parse(url);
    AppLogger.debug(
      'IMAGE_REQUEST url=$url length=${url.length} absolute=${uri.hasAuthority} '
      'host=${uri.host} path=${uri.path} ${label ?? ''}',
      scope: 'image',
    );
    try {
      final response = await Dio().get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          validateStatus: (_) => true,
        ),
      );
      final bytes = Uint8List.fromList(response.data ?? const <int>[]);
      final magic = bytes
          .take(16)
          .map((v) => v.toRadixString(16).padLeft(2, '0'))
          .join();
      AppLogger.debug(
        'IMAGE_BYTES status=${response.statusCode} contentType=${response.headers.value('content-type')} '
        'contentLength=${response.headers.value('content-length')} bytes=${bytes.length} first16=$magic',
        scope: 'image',
      );
      final temp = await Directory.systemTemp.createTemp('versapack-image-');
      final file = File('${temp.path}/image.bin');
      await file.writeAsBytes(bytes, flush: true);
      try {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        AppLogger.debug(
          'IMAGE_CODEC_OK width=${frame.image.width} height=${frame.image.height} file=${file.path}',
          scope: 'image',
        );
        frame.image.dispose();
        codec.dispose();
      } catch (error, stackTrace) {
        AppLogger.error(
          'IMAGE_CODEC_FAILED url=$url file=${file.path}',
          error: error,
          stackTrace: stackTrace,
        );
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'IMAGE_DOWNLOAD_FAILED url=$url',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
