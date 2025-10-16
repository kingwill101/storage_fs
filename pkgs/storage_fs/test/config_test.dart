import 'dart:io';
import 'package:storage_fs/storage_fs.dart';
import 'package:test/test.dart';

void main() {
  group('DiskConfig', () {
    test('can be created with required parameters', () {
      final config = DiskConfig(driver: 'local');

      expect(config.driver, equals('local'));
      expect(config.throw_, isFalse);
      expect(config.report, isFalse);
      expect(config.directorySeparator, equals('/'));
      expect(config.readOnly, isFalse);
    });

    test('can be created from map', () {
      final map = {
        'driver': 's3',
        'root': '/storage',
        'url': 'https://example.com',
        'throw': true,
        'visibility': 'public',
      };

      final config = DiskConfig.fromMap(map);

      expect(config.driver, equals('s3'));
      expect(config.root, equals('/storage'));
      expect(config.url, equals('https://example.com'));
      expect(config.throw_, isTrue);
      expect(config.visibility, equals('public'));
    });

    test('can be converted to map', () {
      final config = DiskConfig(driver: 'local', root: '/tmp', throw_: true);

      final map = config.toMap();

      expect(map['driver'], equals('local'));
      expect(map['root'], equals('/tmp'));
      expect(map['throw'], isTrue);
    });

    test('copyWith creates new instance with updated values', () {
      final original = DiskConfig(
        driver: 'local',
        root: '/path1',
        throw_: false,
      );

      final modified = original.copyWith(root: '/path2', throw_: true);

      expect(original.root, equals('/path1'));
      expect(original.throw_, isFalse);
      expect(modified.root, equals('/path2'));
      expect(modified.throw_, isTrue);
      expect(modified.driver, equals('local'));
    });

    test('equality works correctly', () {
      final config1 = DiskConfig(driver: 'local', root: '/tmp');
      final config2 = DiskConfig(driver: 'local', root: '/tmp');
      final config3 = DiskConfig(driver: 'local', root: '/var');

      expect(config1, equals(config2));
      expect(config1, isNot(equals(config3)));
    });

    test('hashCode is consistent', () {
      final config1 = DiskConfig(driver: 'local', root: '/tmp');
      final config2 = DiskConfig(driver: 'local', root: '/tmp');

      expect(config1.hashCode, equals(config2.hashCode));
    });

    test('handles read-only variations', () {
      final config1 = DiskConfig.fromMap({
        'driver': 'local',
        'read-only': true,
      });
      final config2 = DiskConfig.fromMap({'driver': 'local', 'readOnly': true});

      expect(config1.readOnly, isTrue);
      expect(config2.readOnly, isTrue);
    });
  });

  group('StorageConfig', () {
    test('can be created with required parameters', () {
      final config = StorageConfig(
        disks: {'local': DiskConfig(driver: 'local', root: '/tmp')},
      );

      expect(config.defaultDisk, equals('local'));
      expect(config.disks, hasLength(1));
      expect(config.cloudDisk, isNull);
    });

    test('can be created from map', () {
      final map = {
        'filesystems': {
          'default': 'primary',
          'cloud': 's3',
          'disks': {
            'primary': {'driver': 'local', 'root': '/storage'},
            's3': {'driver': 's3', 'root': '/bucket'},
          },
        },
      };

      final config = StorageConfig.fromMap(map);

      expect(config.defaultDisk, equals('primary'));
      expect(config.cloudDisk, equals('s3'));
      expect(config.disks, hasLength(2));
      expect(config.getDisk('primary')?.driver, equals('local'));
      expect(config.getDisk('s3')?.driver, equals('s3'));
    });

    test('can be created from map without filesystems wrapper', () {
      final map = {
        'default': 'local',
        'disks': {
          'local': {'driver': 'local'},
        },
      };

      final config = StorageConfig.fromMap(map);

      expect(config.defaultDisk, equals('local'));
      expect(config.disks, hasLength(1));
    });

    test('can be converted to map', () {
      final config = StorageConfig(
        defaultDisk: 'primary',
        cloudDisk: 's3',
        disks: {'primary': DiskConfig(driver: 'local', root: '/tmp')},
      );

      final map = config.toMap();

      expect(map['filesystems']['default'], equals('primary'));
      expect(map['filesystems']['cloud'], equals('s3'));
      expect(map['filesystems']['disks'], isA<Map>());
    });

    test('getDisk returns correct disk config', () {
      final localDisk = DiskConfig(driver: 'local', root: '/tmp');
      final config = StorageConfig(disks: {'local': localDisk});

      expect(config.getDisk('local'), same(localDisk));
      expect(config.getDisk('nonexistent'), isNull);
    });

    test('withDisk adds or updates disk', () {
      final config = StorageConfig(
        disks: {'local': DiskConfig(driver: 'local')},
      );

      final newDisk = DiskConfig(driver: 's3', root: '/bucket');
      final updated = config.withDisk('s3', newDisk);

      expect(updated.disks, hasLength(2));
      expect(updated.getDisk('s3'), equals(newDisk));
      expect(updated.getDisk('local'), isNotNull);
    });

    test('copyWith creates new instance', () {
      final original = StorageConfig(
        defaultDisk: 'local',
        disks: {'local': DiskConfig(driver: 'local')},
      );

      final modified = original.copyWith(
        defaultDisk: 'backup',
        cloudDisk: 's3',
      );

      expect(original.defaultDisk, equals('local'));
      expect(modified.defaultDisk, equals('backup'));
      expect(modified.cloudDisk, equals('s3'));
    });

    test('accepts DiskConfig instances in map', () {
      final diskConfig = DiskConfig(driver: 'local', root: '/tmp');
      final map = {
        'filesystems': {
          'disks': {'local': diskConfig},
        },
      };

      final config = StorageConfig.fromMap(map);

      expect(config.getDisk('local'), same(diskConfig));
    });
  });

  group('Storage Integration with Config Classes', () {
    test('can initialize with StorageConfig', () {
      final config = StorageConfig(
        disks: {
          'test': DiskConfig(driver: 'local', root: Directory.systemTemp.path),
        },
      );

      Storage.initialize(config);

      expect(Storage.getDefaultDriver(), equals('local'));
    });

    test('can initialize with Map', () {
      final map = {
        'filesystems': {
          'default': 'test',
          'disks': {
            'test': {'driver': 'local', 'root': Directory.systemTemp.path},
          },
        },
      };

      Storage.initialize(map);

      expect(Storage.getDefaultDriver(), equals('test'));
    });

    test('throws on invalid config type', () {
      expect(
        () => Storage.initialize('invalid'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
