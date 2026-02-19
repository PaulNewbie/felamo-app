import 'package:felamo/screen/notifikasyon.dart';
import 'package:felamo/screen/parangal.dart';
import 'package:felamo/screen/ranggo.dart';
import 'package:felamo/screen/settings.dart';
import 'package:felamo/user/profile.dart';
import 'package:flutter/material.dart';

import 'dashboard.dart';

class CustomBottomBar extends StatelessWidget {
  final int currentIndex;
  final String firstName;
  final String sessionId;
  final int pointsReceived;
  final int current_streak;
  final int id;
  final int points;
  final String email;
  
  final void Function(int index) onTap;

  const CustomBottomBar({
    Key? key,
    required this.currentIndex,
    required this.firstName,
    required this.sessionId,
    required this.onTap,
    required this.pointsReceived,
    required this.current_streak,
    required this.id,
    required this.points,
    required this.email
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Changed to gradient background like in the image
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFD32F2F), // Lighter red
            Color(0xFFB71C1C), // Darker red
          ],
        ),
        borderRadius: BorderRadius.circular(35), // Curved like in image
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildBottomNavItem(
            context: context,
            icon: Icons.grade,
            index: 0,
            isActive: currentIndex == 0,
            targetScreen: TalaNgRanggoScreen(sessionId: sessionId,),
          ),
          _buildBottomNavItem(
            context: context,
            icon: Icons.diamond_outlined,
            index: 1,
            isActive: currentIndex == 1,
            targetScreen: MyWidget(sessionId: sessionId),
          ),
          _buildBottomNavItem(
            context: context,
            icon: Icons.home,
            index: 2, 
            isActive: currentIndex == 2,
            targetScreen: Dashboard(
              firstName: firstName,
              sessionid: sessionId,
              pointsReceived: pointsReceived,
              currentStreak: current_streak,
              id: id,
          
              email: email,
            ),
          ),
          _buildBottomNavItem(
            context: context,
            icon: Icons.notifications,
            index: 3,
            isActive: currentIndex == 3,
            targetScreen: Notifikasyon(sessionid: sessionId),
          ),
          _buildBottomNavItem(
            context: context,
            icon: Icons.miscellaneous_services,
            index: 4,
            isActive: currentIndex == 4,
            targetScreen: SettingsScreen(sessionId: sessionId, firstName: firstName, email: email )
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavItem({
    required BuildContext context,
    required IconData icon,
    required int index,
    required bool isActive,
    required Widget targetScreen,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => targetScreen),
        );
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          // Removed transparent color, now solid white
          color: Colors.white,
          shape: BoxShape.circle,
          // Added shadow to make icons pop like in the image
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: isActive ? const Color(0xFFB71C1C) : Colors.grey[600],
          size: 24,
        ),
      ),
    );
  }
}