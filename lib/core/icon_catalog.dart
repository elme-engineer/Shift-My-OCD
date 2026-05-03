import 'package:flutter/material.dart';

/// Curated icon set offered when adding an object.
const Map<String, IconData> kIconCatalog = {
  'door': Icons.door_front_door,
  'lock': Icons.lock_outline,
  'stove': Icons.local_fire_department_outlined,
  'oven': Icons.microwave_outlined,
  'iron': Icons.iron_outlined,
  'lights': Icons.lightbulb_outline,
  'window': Icons.window_outlined,
  'faucet': Icons.water_drop_outlined,
  'plug': Icons.power_outlined,
  'car': Icons.directions_car_outlined,
  'keys': Icons.key_outlined,
  'bag': Icons.work_outline,
  'pet': Icons.pets_outlined,
  'fridge': Icons.kitchen_outlined,
  'home': Icons.home_outlined,
};

IconData iconFor(String key) => kIconCatalog[key] ?? Icons.help_outline;