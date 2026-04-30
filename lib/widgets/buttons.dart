import 'package:flutter/material.dart';

class AppButtons extends StatelessWidget {
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;
  final String text;
  double? textSize;
  IconData? icon;
  String? imagePath;
  double buttonHeight;
  double buttonLength;
  bool? isIcon;
  double? iconSize;
  final VoidCallback? onTap;

  AppButtons({
    Key? key,
    required this.textColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.text,
    this.icon,
    this.imagePath,
    required this.buttonHeight,
    required this.buttonLength,
    this.isIcon = false,
    this.iconSize,
    this.textSize,
    this.onTap
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: buttonLength,
        height: buttonHeight,
        decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
                color: borderColor,
                width: 3.5
            )
        ),
        child: Center(
          child: isIcon == true && (icon != null || imagePath != null)
              ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (imagePath != null)
                Image.asset(
                  imagePath!,
                  width: iconSize ?? 0.25,
                  height: iconSize ?? 0.25,
                )
              else if (icon != null)
                Icon(
                  icon,
                  color: textColor,
                  size: iconSize ?? 0.25,
                ),
              const SizedBox(height: 8),
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    fontSize: textSize ?? 20),
              ),
            ],
          )
              : Text(
            text,
            style: TextStyle(color: textColor),
          ),
        ),
      ),
    );
  }
}

