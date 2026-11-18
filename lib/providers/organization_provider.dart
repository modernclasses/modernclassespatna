import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrganizationProvider extends ChangeNotifier {
  static const String _kInstituteNameKey = 'org_institute_name';
  static const String _kDirectorNameKey = 'org_director_name';
  static const String _kHelplinePhoneKey = 'org_helpline_phone';
  static const String _kOfficialEmailKey = 'org_official_email';
  static const String _kCampusLocationKey = 'org_campus_location';

  String _instituteName = "Modern Classes Patna";
  String _directorName = "Madhurendra Kumar Yadav";
  String _helplinePhone = "+91 6209016951";
  String _officialEmail = "madhurendrayadav06@gmail.com";
  String _campusLocation = "Musallahpur Hat / Boring Road, Patna";

  String get instituteName => _instituteName;
  String get directorName => _directorName;
  String get helplinePhone => _helplinePhone;
  String get officialEmail => _officialEmail;
  String get campusLocation => _campusLocation;

  OrganizationProvider() {
    _loadFromPreferences();
  }

  Future<void> _loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _instituteName = prefs.getString(_kInstituteNameKey) ?? _instituteName;
      _directorName = prefs.getString(_kDirectorNameKey) ?? _directorName;
      _helplinePhone = prefs.getString(_kHelplinePhoneKey) ?? _helplinePhone;
      _officialEmail = prefs.getString(_kOfficialEmailKey) ?? _officialEmail;
      _campusLocation = prefs.getString(_kCampusLocationKey) ?? _campusLocation;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> updateDetails({
    required String instituteName,
    required String directorName,
    required String helplinePhone,
    required String officialEmail,
    required String campusLocation,
  }) async {
    _instituteName = instituteName.trim();
    _directorName = directorName.trim();
    _helplinePhone = helplinePhone.trim();
    _officialEmail = officialEmail.trim();
    _campusLocation = campusLocation.trim();
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kInstituteNameKey, _instituteName);
      await prefs.setString(_kDirectorNameKey, _directorName);
      await prefs.setString(_kHelplinePhoneKey, _helplinePhone);
      await prefs.setString(_kOfficialEmailKey, _officialEmail);
      await prefs.setString(_kCampusLocationKey, _campusLocation);
    } catch (_) {}
  }
}
