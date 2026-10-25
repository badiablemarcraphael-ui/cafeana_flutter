// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firebase_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$firebaseAuthHash() => r'8f84097cccd00af817397c1715c5f537399ba780';

/// Provides the [FirebaseAuth] singleton.
///
/// Copied from [firebaseAuth].
@ProviderFor(firebaseAuth)
final firebaseAuthProvider = AutoDisposeProvider<FirebaseAuth>.internal(
  firebaseAuth,
  name: r'firebaseAuthProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$firebaseAuthHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FirebaseAuthRef = AutoDisposeProviderRef<FirebaseAuth>;
String _$firestoreHash() => r'597b1a9eb96f2fae51f5b578f4b5debe4f6d30c6';

/// Provides the [FirebaseFirestore] singleton.
///
/// Copied from [firestore].
@ProviderFor(firestore)
final firestoreProvider = AutoDisposeProvider<FirebaseFirestore>.internal(
  firestore,
  name: r'firestoreProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$firestoreHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FirestoreRef = AutoDisposeProviderRef<FirebaseFirestore>;
String _$authStateChangesHash() => r'7e2230d665098f97101510d80be5c9dd82d44903';

/// Stream of the currently signed-in [User], or `null` if signed out.
///
/// Copied from [authStateChanges].
@ProviderFor(authStateChanges)
final authStateChangesProvider = AutoDisposeStreamProvider<User?>.internal(
  authStateChanges,
  name: r'authStateChangesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$authStateChangesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AuthStateChangesRef = AutoDisposeStreamProviderRef<User?>;
String _$userProfileHash() => r'c39b437666b04023a4fd13d428275d182e9ad54c';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// Stream of the [UserProfile] document for the given Firebase Auth [uid].
///
/// Emits `null` while the document does not exist yet.
///
/// Copied from [userProfile].
@ProviderFor(userProfile)
const userProfileProvider = UserProfileFamily();

/// Stream of the [UserProfile] document for the given Firebase Auth [uid].
///
/// Emits `null` while the document does not exist yet.
///
/// Copied from [userProfile].
class UserProfileFamily extends Family<AsyncValue<UserProfile?>> {
  /// Stream of the [UserProfile] document for the given Firebase Auth [uid].
  ///
  /// Emits `null` while the document does not exist yet.
  ///
  /// Copied from [userProfile].
  const UserProfileFamily();

  /// Stream of the [UserProfile] document for the given Firebase Auth [uid].
  ///
  /// Emits `null` while the document does not exist yet.
  ///
  /// Copied from [userProfile].
  UserProfileProvider call(String uid) {
    return UserProfileProvider(uid);
  }

  @override
  UserProfileProvider getProviderOverride(
    covariant UserProfileProvider provider,
  ) {
    return call(provider.uid);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'userProfileProvider';
}

/// Stream of the [UserProfile] document for the given Firebase Auth [uid].
///
/// Emits `null` while the document does not exist yet.
///
/// Copied from [userProfile].
class UserProfileProvider extends AutoDisposeStreamProvider<UserProfile?> {
  /// Stream of the [UserProfile] document for the given Firebase Auth [uid].
  ///
  /// Emits `null` while the document does not exist yet.
  ///
  /// Copied from [userProfile].
  UserProfileProvider(String uid)
    : this._internal(
        (ref) => userProfile(ref as UserProfileRef, uid),
        from: userProfileProvider,
        name: r'userProfileProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$userProfileHash,
        dependencies: UserProfileFamily._dependencies,
        allTransitiveDependencies: UserProfileFamily._allTransitiveDependencies,
        uid: uid,
      );

  UserProfileProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.uid,
  }) : super.internal();

  final String uid;

  @override
  Override overrideWith(
    Stream<UserProfile?> Function(UserProfileRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: UserProfileProvider._internal(
        (ref) => create(ref as UserProfileRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        uid: uid,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<UserProfile?> createElement() {
    return _UserProfileProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UserProfileProvider && other.uid == uid;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, uid.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin UserProfileRef on AutoDisposeStreamProviderRef<UserProfile?> {
  /// The parameter `uid` of this provider.
  String get uid;
}

class _UserProfileProviderElement
    extends AutoDisposeStreamProviderElement<UserProfile?>
    with UserProfileRef {
  _UserProfileProviderElement(super.provider);

  @override
  String get uid => (origin as UserProfileProvider).uid;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
