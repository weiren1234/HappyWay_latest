import 'package:flutter_test/flutter_test.dart';
import 'package:happyway/utils/validators.dart';

void main() {
  group('Email Validation Tests', () {
    test('Accepts valid multi-level and hyphenated institutional emails', () {
      expect(Validators.validateEmail('tanwr-wm23@student.tarc.edu.my'), isNull);
      expect(Validators.validateEmail('abc.def@gmail.com'), isNull);
      expect(Validators.validateEmail('user-123@company.com.my'), isNull);
      expect(Validators.validateEmail('traveler@happyway.my'), isNull);
      expect(Validators.validateEmail('john.doe+travel@sub.domain.co.uk'), isNull);
    });

    test('Rejects empty or whitespace email', () {
      expect(Validators.validateEmail(''), 'Please enter your email.');
      expect(Validators.validateEmail(null), 'Please enter your email.');
      expect(Validators.validateEmail('   '), 'Please enter your email.');
    });

    test('Rejects malformed emails', () {
      expect(Validators.validateEmail('plainaddress'), 'Please enter a valid email address.');
      expect(Validators.validateEmail('@missingusername.com'), 'Please enter a valid email address.');
      expect(Validators.validateEmail('user@.com'), 'Please enter a valid email address.');
      expect(Validators.validateEmail('user@domain'), 'Please enter a valid email address.');
      expect(Validators.validateEmail('user with space@domain.com'), 'Please enter a valid email address.');
    });
  });

  group('Password Validation Tests', () {
    test('Accepts valid passwords (6+ chars)', () {
      expect(Validators.validatePassword('secret123'), isNull);
      expect(Validators.validatePassword('123456'), isNull);
    });

    test('Rejects short passwords', () {
      expect(Validators.validatePassword('12345'), 'Password must be at least 6 characters.');
      expect(Validators.validatePassword(''), 'Please enter your password.');
      expect(Validators.validatePassword(null), 'Please enter your password.');
    });

    test('Validates confirm password matching', () {
      expect(Validators.validateConfirmPassword('secret123', 'secret123'), isNull);
      expect(Validators.validateConfirmPassword('secret123', 'otherpass'), 'Passwords do not match.');
      expect(Validators.validateConfirmPassword('', 'secret123'), 'Please confirm your password.');
    });
  });

  group('Display Name Validation Tests', () {
    test('Accepts valid display names', () {
      expect(Validators.validateDisplayName('Wei Ren'), isNull);
      expect(Validators.validateDisplayName('Tan'), isNull);
    });

    test('Rejects empty display names', () {
      expect(Validators.validateDisplayName(''), 'Please enter your display name.');
      expect(Validators.validateDisplayName('   '), 'Please enter your display name.');
      expect(Validators.validateDisplayName(null), 'Please enter your display name.');
    });
  });
}
