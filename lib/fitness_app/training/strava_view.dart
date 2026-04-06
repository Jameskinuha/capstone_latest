import 'package:best_flutter_ui_templates/fitness_app/fitness_app_theme.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class StravaView extends StatelessWidget {
  final AnimationController? animationController;
  final Animation<double>? animation;

  const StravaView({Key? key, this.animationController, this.animation})
      : super(key: key);

  Future<void> _launchStrava() async {
    const url = 'https://www.strava.com/mobile';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animationController!,
      builder: (BuildContext context, Widget? child) {
        return FadeTransition(
          opacity: animation!,
          child: Transform(
            transform: Matrix4.translationValues(
                0.0, 30 * (1.0 - animation!.value), 0.0),
            child: Padding(
              padding: const EdgeInsets.only(
                  left: 24, right: 24, top: 16, bottom: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: FitnessAppTheme.white,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8.0),
                      bottomLeft: Radius.circular(8.0),
                      bottomRight: Radius.circular(8.0),
                      topRight: Radius.circular(68.0)),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                        color: FitnessAppTheme.grey.withOpacity(0.2),
                        offset: const Offset(1.1, 1.1),
                        blurRadius: 10.0),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFC6100).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.directions_run,
                              color: Color(0xFFFC6100),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Strava Sync',
                            style: TextStyle(
                              fontFamily: FitnessAppTheme.fontName,
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                              color: FitnessAppTheme.darkerText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Monitor your outdoor activities by syncing with Strava. Track runs, rides, and more directly in your calorie burn history.',
                        style: TextStyle(
                          fontFamily: FitnessAppTheme.fontName,
                          fontSize: 14,
                          color: FitnessAppTheme.grey,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: InkWell(
                          onTap: _launchStrava,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFC6100),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.sync, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'Connect with Strava',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
