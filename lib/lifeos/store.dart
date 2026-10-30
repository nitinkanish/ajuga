import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

const lifeStoreKey = 'ajuga.lifeos.v1';

class LifeStore {
  Future<LifeDocument> load() async {
    final prefs = await SharedPreferences.getInstance();
    return LifeDocument.decode(prefs.getString(lifeStoreKey));
  }

  Future<void> save(LifeDocument document) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(lifeStoreKey, jsonEncode(document.toJson()));
  }

  Future<LifeDocument> update(LifeDocument Function(LifeDocument current) change) async {
    final next = change(await load()).copyWith(clearCache: true);
    await save(next);
    return next;
  }

  Future<void> deleteAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(lifeStoreKey);
  }
}
