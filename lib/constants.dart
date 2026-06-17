import 'package:flutter/material.dart';
import 'main.dart';

// Theme colors (using MyApp colors)
const Color primaryMaroon = Color(0xFF0B2B26);
const Color backgroundLilac = Color(0xFFF2F0FA);

// Divisions of Bangladesh (used for the grid)
const List<String> divisions = [
  'Dhaka',
  'Chattogram',
  'Rajshahi',
  'Khulna',
  'Barishal',
  'Sylhet',
  'Rangpur',
  'Mymensingh',
];

// Emergency contacts for SOS screen
const Map<String, String> emergencyContacts = {
  'Police': '999',
  'Ambulance': '199',
  'Fire Service': '199',
  'Tourist Police': '01713-381182',
};