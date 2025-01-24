import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rubix/screens/AuthScr.dart';
import 'package:rubix/screens/donor/leader.dart';
import 'package:rubix/screens/donor/myDonScr.dart';
import 'package:rubix/screens/donor/myPurchase.dart';
import 'package:rubix/screens/donor/shopScr.dart';
import 'package:rubix/screens/drawScr.dart';
import 'package:rubix/screens/recepient/mapScr.dart';
import 'package:rubix/screens/recepient/myreqScr.dart';
import 'package:rubix/screens/recepient/reqScr.dart';
import 'package:rubix/widgets/bottomnav.dart';
String? userId;
String? emailId;
String? usernamee;

class TabScr extends StatefulWidget {
  @override
  State<TabScr> createState() => _TabScrState();
}

class _TabScrState extends State<TabScr> {
  User? userid = FirebaseAuth.instance.currentUser;
  int currInd = 0;
  bool isInstitute = true;
  String fullName = 'Loading...';
  String email = '';
  String role = '';
  String emailID = '';
  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        userId = user.uid;
        
        final instituteDoc = await FirebaseFirestore.instance
            .collection('donors')
            .doc(user.uid)
            .get();

        if (instituteDoc.exists) {
          final data = instituteDoc.data() as Map<String, dynamic>;
          setState(() {
            fullName = data['fullName'] ?? 'No Name';
            email = data['email'] ?? 'No Email';
            usernamee = data['fullName'] ?? 'No Name';
            emailId = data['email'] ?? 'No Email';
            role = 'donor';
            emailID = user.uid;
          });
        } else {
          
          final userDoc = await FirebaseFirestore.instance
              .collection('recepients')
              .doc(user.uid)
              .get();

          if (userDoc.exists) {
            final data = userDoc.data() as Map<String, dynamic>;
            setState(() {
              userId = user.uid;
              fullName = data['fullName'] ?? 'No Name';
              email = data['email'] ?? 'No Email';
              usernamee = data['fullName'] ?? 'No Name';
              emailId = data['email'] ?? 'No Email';
              role = 'recepient';
            });
          } else {
            setState(() {
              fullName = 'No User Data';
              role = 'unknown';
            });
          }
        }
      }
    } catch (e) {
      setState(() {
        fullName = 'Error loading data';
        role = 'unknown';
      });
    }
  }

  Future<void> checkUserType() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('donors')
          .doc(user.uid)
          .get();
      setState(() {
        isInstitute = userDoc.exists;
      });
    }
  }

 

  void selTab(int index) {
    setState(() {
      currInd = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    String actText = 'Food';
   Widget? actScr;

    switch (currInd) {
      case 0:
        if (role == 'donor') {
          actScr = DonationShopScreen();
        } else {
          actScr = AvailableDonationsScreen(currentUserId: userid!.uid, currentUserEmail: userId!, currentUserName: usernamee!);
        }
        actText = 'Home';
        break;
      case 1:
        if (role == 'donor') {
          actScr = MyDonationsScreen(currentUserId: userid!.uid);
        } else {
          actScr = LeaderboardScreen();
        }
        actText = 'My Activity';
        break;  
      case 2:
        if (role == 'recepient'){ 
        actScr = DonationsMapScreen();
        }
        else{
          actScr = LeaderboardScreen();
        }
        break;  
    }
  

    return WillPopScope(
      onWillPop: () async {
        if (currInd != 0) {
          setState(() {
            currInd = 0;
          });
          return false;
        } else {
          return true;
        }
      },
      child: SafeArea(
        child: Scaffold(
          drawer: Drawer(
            child: DrawerScreen()
          ),
          body:Stack(
          children: [
            // Main Screen Content
            Padding(
              padding: EdgeInsets.fromLTRB(0, 0, 0, 64),
              child: actScr!,
            ),

            // Floating Menu Button to Open Drawer
            Builder(
              builder: (context) => Positioned(
                top: 16,
                left: 16,
                child: GestureDetector(
                  onTap: () => Scaffold.of(context).openDrawer(),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.menu,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Navigation Bar
            Positioned(
              bottom: 3,
              left: 25,
              right: 25,
              child: BottomNavBar(
                currentIndex: currInd,
                onTap: selTab,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}}