// This page will hold information and FAQs pertaining to the project
// importing libraries, pages, and packages

import 'package:flutter/material.dart';
import 'user_data_manager.dart';
import 'package:provider/provider.dart';

class Information extends StatelessWidget {
  const Information({super.key});

  @override
  Widget build(BuildContext context) {
    final userData = Provider.of<UserDataProvider>(context);
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
              'Information',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 25)
          ),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children:[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              margin: const EdgeInsetsDirectional.only(start: 5, end: 5),
              color: Colors.deepPurple,
              child:
              const Text(
                  'Our Mission',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontSize: 25)
              ),
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsetsDirectional.only(start: 5, end: 5),
              color: Colors.white,
              child:
              const Text(
                  'This project aims to...',
                  textAlign: TextAlign.start,
                  style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
                      fontSize: 20)
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              margin: const EdgeInsetsDirectional.only(start: 5, end: 5),
              color: Colors.deepPurple,
              child:
              const Text(
                  'How to Interpret Collected Data',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontSize: 25)
              ),
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsetsDirectional.only(start: 5, end: 5),
              color: Colors.white,
              child:
              const Text(
                  'Whenever you collect a measurement, you record upload speed,'
                      'download speed, latency, and jitters. So, what does this all mean?'
                      '\n'
                      'Your upload speed is how fast your device is sending data to the '
                      'internet. Your download speed is how fast your device is receiving '
                      'information from the internet.'
                      '\n'
                      'We measure these in megabits per second (Mbps). The higher this value, '
                      'the faster your connection is.'
                      '\n'
                      'Generally speaking, your upload speed is good if it is at least '
                      '10 Mbps. Your download speed should be at least 100 Mbps.',
                  textAlign: TextAlign.start,
                  style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
                      fontSize: 20)
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              margin: const EdgeInsetsDirectional.only(start: 5, end: 5),
              color: Colors.deepPurple,
              child:
              const Text(
                  'How to Collect a Measurement',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontSize: 25)
              ),
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsetsDirectional.only(start: 5, end: 5),
              color: Colors.white,
              child:
              const Text(
                  'Instructions go here.',
                  textAlign: TextAlign.start,
                  style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
                      fontSize: 20)
              ),
            ),
          ],
        )
    );
  }
}

