import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CCPLogoWidget extends StatelessWidget {
  const CCPLogoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 130,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ṿng tṛn Cyan ? du?i
              Positioned(
                bottom: 0,
                right: 0,
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF00D2FF), Color(0xFF00F0FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 18),
                    ),
                  ),
                ),
              ),
              // Ṿng tṛn Blue ? trên
              Positioned(
                top: 0,
                left: 0,
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF0038FF), Color(0xFF009DFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: Container(
                    width: 70,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Text(
          "CCP Bank",
          style: GoogleFonts.poppins(
            fontSize: 35,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF000DC0),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          "Tài chính của mọi nhà",
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF000DC0),
          ),
        ),
      ],
    );
  }
}
