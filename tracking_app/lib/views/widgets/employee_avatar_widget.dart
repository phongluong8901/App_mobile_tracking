import 'package:flutter/material.dart';
import '../../services/app_settings_service.dart';

class EmployeeAvatarWidget extends StatelessWidget {
  final double size;
  final double borderRadius;
  final VoidCallback? onTap;
  final bool showEditBadge;

  const EmployeeAvatarWidget({
    super.key,
    this.size = 44,
    this.borderRadius = 14,
    this.onTap,
    this.showEditBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettingsService.instance,
      builder: (context, _) {
        final settings = AppSettingsService.instance;
        final preset = settings.currentAvatarPreset;
        final customBytes = settings.customAvatarBytes;

        Widget avatarBox = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: preset.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [
              BoxShadow(
                color: preset.gradient.first.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: customBytes != null
                ? Image.memory(
                    customBytes,
                    fit: BoxFit.cover,
                    width: size,
                    height: size,
                  )
                : Icon(
                    preset.icon,
                    color: Colors.white,
                    size: size * 0.52,
                  ),
          ),
        );

        if (showEditBadge) {
          avatarBox = Stack(
            clipBehavior: Clip.none,
            children: [
              avatarBox,
              Positioned(
                right: -3,
                bottom: -3,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: settings.palette.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 11,
                  ),
                ),
              ),
            ],
          );
        }

        if (onTap != null) {
          return InkWell(
            borderRadius: BorderRadius.circular(borderRadius),
            onTap: onTap,
            child: avatarBox,
          );
        }
        return avatarBox;
      },
    );
  }
}

