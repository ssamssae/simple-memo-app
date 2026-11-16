import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:simple_memo_app/services/drive_backup_service.dart';

// T-261116-041 — 한줄일기 #148·할일요 #48 과 같은 Drive 로그인 기억.
// 예전에는 Drive 백업·복원을 누를 때마다 authenticate() 로 계정 고르기 창을 띄웠다.
// 이제 지난 로그인이 남아 있으면 조용히 이어 쓰고, 이미 받은 Drive 권한이면 권한 창도 없다.
// 「다른 Google 계정 쓰기」(signOut) 뒤에는 계정을 다시 고른다.
// 진짜 GoogleSignIn 을 쓰고, 그 아래 플랫폼만 가짜로 바꾼다.
void main() {
  late _FakeSignInPlatform platform;

  setUp(() {
    platform = _FakeSignInPlatform();
    GoogleSignInPlatform.instance = platform;
  });

  tearDown(() async {
    // 기억한 계정은 앱 실행 동안 남는다(정적). 다음 시험이 빈 상태로 시작하게 지운다.
    await DriveBackupService.signOut();
  });

  test('지난 로그인이 남아 있으면 계정 고르기 창 없이 그 계정을 쓴다', () async {
    platform.restored = _results('kept@example.com');

    expect(await DriveBackupService.authorizeForTest(), isNotNull);

    expect(platform.lightweightCalls, 1);
    expect(platform.authenticateCalls, 0);
  });

  test('되살릴 로그인이 없을 때만 계정 고르기 창을 띄운다', () async {
    expect(await DriveBackupService.authorizeForTest(), isNotNull);

    expect(platform.lightweightCalls, 1);
    expect(platform.authenticateCalls, 1);
  });

  test('조용한 로그인이 실패해도 계정 고르기 창으로 이어진다', () async {
    platform.lightweightError = const GoogleSignInException(
      code: GoogleSignInExceptionCode.clientConfigurationError,
    );

    expect(await DriveBackupService.authorizeForTest(), isNotNull);

    expect(platform.authenticateCalls, 1);
  });

  test('한 번 고른 계정은 앱이 켜져 있는 동안 다시 묻지 않는다', () async {
    await DriveBackupService.authorizeForTest();
    await DriveBackupService.authorizeForTest();

    expect(platform.authenticateCalls, 1);
    expect(platform.lightweightCalls, 1);
  });

  test('다른 Google 계정 쓰기(로그아웃) 뒤에는 계정을 다시 고른다', () async {
    platform.restored = _results('kept@example.com');
    await DriveBackupService.authorizeForTest();

    await DriveBackupService.signOut();
    platform.restored = null;
    await DriveBackupService.authorizeForTest();

    expect(platform.signOutCalls, 1);
    expect(platform.disconnectCalls, 0);
    expect(platform.authenticateCalls, 1);
  });

  test('기억된 로그인에 Drive 권한도 있으면 권한 창 없이 이어 쓴다', () async {
    platform.restored = _results('kept@example.com');

    await DriveBackupService.authorizeForTest();

    expect(platform.promptedAuthorizations, 0);
  });

  test('Drive 권한이 아직 없을 때만 권한 창을 띄운다', () async {
    platform.restored = _results('kept@example.com');
    platform.granted = false;

    expect(await DriveBackupService.authorizeForTest(), isNotNull);

    expect(platform.promptedAuthorizations, 1);
  });

  test('계정 고르기를 취소하면 권한 없음으로 끝난다', () async {
    platform.authenticateError = const GoogleSignInException(
      code: GoogleSignInExceptionCode.canceled,
    );

    expect(await DriveBackupService.authorizeForTest(), isNull);
  });
}

AuthenticationResults _results(String email) => AuthenticationResults(
  user: GoogleSignInUserData(email: email, id: email),
  authenticationTokens: const AuthenticationTokenData(idToken: null),
);

/// 구글에 연결하지 않는 로그인 플랫폼. GoogleSignInPlatform 을 extends 하면
/// 플랫폼 토큰 검사를 그대로 통과한다.
class _FakeSignInPlatform extends GoogleSignInPlatform {
  AuthenticationResults? restored;
  Object? lightweightError;
  Object? authenticateError;

  /// Drive 권한을 이미 받았는지. false 면 권한 창(prompt)을 거쳐야 토큰이 나온다.
  bool granted = true;

  int lightweightCalls = 0;
  int authenticateCalls = 0;
  int signOutCalls = 0;
  int disconnectCalls = 0;
  int promptedAuthorizations = 0;

  @override
  Future<void> init(InitParameters params) async {}

  @override
  Future<AuthenticationResults?>? attemptLightweightAuthentication(
    AttemptLightweightAuthenticationParameters params,
  ) {
    lightweightCalls++;
    final error = lightweightError;
    if (error != null) return Future<AuthenticationResults?>.error(error);
    return Future<AuthenticationResults?>.value(restored);
  }

  @override
  bool supportsAuthenticate() => true;

  @override
  Future<AuthenticationResults> authenticate(
    AuthenticateParameters params,
  ) async {
    authenticateCalls++;
    final error = authenticateError;
    if (error != null) throw error;
    return _results('picked@example.com');
  }

  @override
  bool authorizationRequiresUserInteraction() => false;

  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    ClientAuthorizationTokensForScopesParameters params,
  ) async {
    if (params.request.promptIfUnauthorized) {
      promptedAuthorizations++;
    } else if (!granted) {
      return null;
    }
    return const ClientAuthorizationTokenData(accessToken: 'test-access-token');
  }

  @override
  Future<ServerAuthorizationTokenData?> serverAuthorizationTokensForScopes(
    ServerAuthorizationTokensForScopesParameters params,
  ) async => null;

  @override
  Future<void> signOut(SignOutParams params) async {
    signOutCalls++;
  }

  @override
  Future<void> disconnect(DisconnectParams params) async {
    disconnectCalls++;
  }
}
