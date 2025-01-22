import 'package:flutter/material.dart';

class SplashScr extends StatelessWidget{
  const SplashScr({super.key});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
          title: Text(
            'Rubix',
            style: Theme.of(context).textTheme.titleLarge!
            .copyWith(
              color: Theme.of(context).colorScheme.primaryContainer,
              fontWeight: FontWeight.bold
            ),
            ), 
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      )
    );
  }
}