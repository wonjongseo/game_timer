import 'package:flutter/material.dart';
import 'package:game_timer/main.dart';

class CustomButton extends StatelessWidget {
  const CustomButton(
      {super.key,
      required this.label,
      required this.onTap,
      this.verticalPadding = 10});
  final Function() onTap;
  final String label;
  final double verticalPadding;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: verticalPadding),
        decoration: BoxDecoration(
            color: appColor, borderRadius: BorderRadius.circular(12)),
        child: Center(
            child: Text(
          label,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 19),
        )),
      ),
    );
  }
}
