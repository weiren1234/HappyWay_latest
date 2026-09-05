import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/destination_image_info.dart';
import '../services/destination_image_service.dart';
import '../theme/app_colors.dart';

class DestinationImageView extends StatefulWidget {
  final String? name;
  final String? state;
  final String? locationId;
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool showAttribution;
  final String? heroTag;

  const DestinationImageView({
    super.key,
    this.name,
    this.state,
    this.locationId,
    this.imageUrl,
    this.width,
    this.height = 180,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.showAttribution = false,
    this.heroTag,
  });

  @override
  State<DestinationImageView> createState() => _DestinationImageViewState();
}

class _DestinationImageViewState extends State<DestinationImageView> {
  DestinationImageInfo? _imageInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant DestinationImageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name ||
        oldWidget.locationId != widget.locationId ||
        oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    final destName = widget.name ?? '';
    final destState = widget.state;
    final locId = widget.locationId;
    final explicitUrl = widget.imageUrl;

    if (explicitUrl != null && explicitUrl.startsWith('assets/')) {
      if (mounted) {
        setState(() {
          _imageInfo = DestinationImageInfo(
            imageUrl: explicitUrl,
            cachedAt: DateTime.now(),
            isLocalAsset: true,
            isVerified: true,
          );
          _isLoading = false;
        });
      }
      return;
    }

    final info = await DestinationImageService().resolveImage(
      name: destName,
      state: destState,
      locationId: locId,
      explicitImageUrl: explicitUrl,
    );

    if (mounted) {
      setState(() {
        _imageInfo = info;
        _isLoading = false;
      });
    }
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: AppColors.surfaceGlass(context),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accentCyan,
          ),
        ),
      ),
    );
  }

  Widget _buildNeutralArtwork(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.backgroundCardDark,
                  AppColors.weatherBlue.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.8),
                ]
              : [
                  const Color(0xFFF1F5F9),
                  AppColors.weatherBlue.withValues(alpha: 0.1),
                  const Color(0xFFE2E8F0),
                ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceGlass(context),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderGlass(context)),
              ),
              child: const Icon(
                Icons.location_on_rounded,
                size: 28,
                color: AppColors.accentCyan,
              ),
            ),
            if (widget.name != null && widget.name!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  widget.name!,
                  style: TextStyle(
                    color: AppColors.secondaryText(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_isLoading) {
      content = _buildPlaceholder(context);
    } else if (_imageInfo == null || _imageInfo!.imageUrl.isEmpty) {
      content = _buildNeutralArtwork(context);
    } else if (_imageInfo!.isLocalAsset) {
      content = Image.asset(
        _imageInfo!.imageUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) => _buildNeutralArtwork(context),
      );
    } else {
      content = CachedNetworkImage(
        imageUrl: _imageInfo!.imageUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        placeholder: (context, url) => _buildPlaceholder(context),
        errorWidget: (context, url, error) => _buildNeutralArtwork(context),
      );
    }

    if (widget.heroTag != null) {
      content = Hero(
        tag: widget.heroTag!,
        child: content,
      );
    }

    if (widget.borderRadius != null) {
      content = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: content,
      );
    }

    if (widget.showAttribution &&
        _imageInfo != null &&
        _imageInfo!.photographer != null &&
        !_imageInfo!.isLocalAsset) {
      content = Stack(
        children: [
          content,
          Positioned(
            bottom: 6,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.glassBorderLight, width: 0.5),
              ),
              child: Text(
                'Photo by ${_imageInfo!.photographer!} on Pexels',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 9,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return content;
  }
}
