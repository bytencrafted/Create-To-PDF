import 'dart:io';
import 'package:flutter/material.dart';

const _red = Color(0xFFE53935);
const _redTint = Color(0xFFFCE9E8);
const _text = Color(0xFF1A1B1F);
const _textDim = Color(0xFF6E7077);

/// Weiße Karte mit weichem Schatten und Haarlinien-Rand.
class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;

  const SurfaceCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

/// Große Aktions-Kachel (Kamera / Galerie / PDF / Werkzeuge).
class ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  const ActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? _red : Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: primary ? BorderSide.none : BorderSide(color: Colors.black.withOpacity(0.06)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary ? Colors.white.withOpacity(0.20) : _redTint,
                ),
                child: Icon(icon, size: 23, color: primary ? Colors.white : _red),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  color: primary ? Colors.white : _text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppTitle extends StatelessWidget {
  final String text;
  const AppTitle({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _red,
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Colors.white),
        ),
        const SizedBox(width: 11),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              letterSpacing: 0.1,
              color: _text,
            ),
          ),
        ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  final String text;
  const EmptyState({super.key, required this.text});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: _redTint),
              child: const Icon(Icons.note_add_outlined, size: 46, color: _red),
            ),
            const SizedBox(height: 18),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: _textDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ImageThumb extends StatelessWidget {
  final String path;
  const ImageThumb({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: Image.file(
        File(path),
        width: 50,
        height: 50,
        cacheWidth: 150,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => Container(
          width: 50,
          height: 50,
          color: const Color(0xFFEDEEF1),
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined, size: 20, color: _textDim),
        ),
      ),
    );
  }
}