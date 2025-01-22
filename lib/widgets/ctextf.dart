import 'package:flutter/material.dart';

InputDecoration customInputDecoration(
     {required String hintText
     }) {
  return InputDecoration(
    enabledBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: Colors.white),
      borderRadius: BorderRadius.all(Radius.circular(5)),
    ),
    fillColor: Colors.white,
    filled: true,
    hintText: hintText,
  );
}
