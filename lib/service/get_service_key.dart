import 'package:googleapis_auth/auth_io.dart';

class GetServerKey {
  Future<String> getServerKeyToken() async {
    final scopes = [
      'https://www.googleapis.com/auth/userinfo.email',
      'https://www.googleapis.com/auth/firebase.database',
      'https://www.googleapis.com/auth/firebase.messaging',
    ];
    
    final client = await clientViaServiceAccount(
        ServiceAccountCredentials.fromJson(
          {
            "type": "service_account",
            "project_id": "myproject-9638b",
            "private_key_id": "1b999ed36f879c401cbf3c0c17a22284dc1c71af",
            "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDJE0TMNy+dSTgg\nyY7pmfmUXxXFps2FV5ut7mJWm2zb4+8OGwZiAAmcIltgpYko56jp4wRu0eFc9CVv\nsVqUCTWHM6MVa1eHtVCDfD/yoW2oyhxHPrm3wEjwOO8rlY41gIt4A576PdJyN9YN\nz9CC5HFb0HEQ6LiJJ2aIK/cxxDs2n/+EhOr9VoAneZpfxn8PyMZamamYyWjl21T/\nvVPie7lzEbY+vCzD6tHFkQ5UDWhw7LBFqDJGTmbfrdpfmPGtook409cerPtRn0xk\nKvAQbrarh2MjL+Mn9TDE8MUeBYeUA3RQddQmkOhVEBXx5OeJqC8c7aS1rlyX4Umm\nw0cl3GHNAgMBAAECggEAZF7T9sSNZgwIkoVKa11K8j9MlO8gpDEJKxdVyzmma1Uq\nHXZsBztRkLituF6pStvou2dw7QijYE0W6twzBLZcG/Mwsx50APAHErtRCIKARMMu\nvnmXJxw6zH7/FFiBNj/GXtAf6XY2uIEavqY/xTbXRyeTaQdiJkSer9aSfCsiC6+K\nfalrz7cR6AjQ0zGAt9JMxn8j4KGpJ5XxcMd7Xf7xn1tSW9YfKiJnCqTOpVwpnxBW\nRkMuS+4XXCxDN6YXVMYNhPrs446GhruT0F6OPzEG8tNxPLL2HMizIgmD352VSvk5\n51cc/idRPaUdCG4pjBh4w5d7Bdfz4yLhMx+Ww1vMGQKBgQDLohxJA08+TKq2is9p\nrudbejHIfmZNcBeJXGFOvssGyg4xtcVmWKp4MVVpLwwEipW1eHMsAMk/6ROZKJhY\nlZboLw7vaQF7qJ2Si0yb0LkCCHHRF5bSciAijaQkBzhp6gaWoAOx2GYiDtYjDYmy\nGNz6/TzdFWVdIQzo4aUFuF2LHwKBgQD8yMH8ugp/+s7yIvtXWhCBjGCZSIuA7hRb\nkqMe15P3TV73rzn0wknvRUqk5JCWWSuByPRR2y+EQW6UAhuqja59KJECE9RkvyLa\nutjsvIvSsA5C1eYDjModxGLapNId9P95CNllM9sN2n/LAHCqia2p8US0zbI0Yvp4\nKvunDnmhkwKBgQCvHz4mCGOY10Qk8mGHqLQs9nxjyVhflluXdMv2dZySvSfR1lnq\nN6x66yph5+T07t3rD6g0moR4oxCIseG6pQL/sKCugeaVmx/QDF4YzjqdJfgD8r5x\nQ1ahgKA9n7wDUhDSbtBenRTQi2PbB2R4tmssqqYyF5lxqt+4U32g2roPzwKBgAXo\nu4Ao6S3sswG+B5oXJOOiYG+03m35IsixONbzuyXAzUOE+RnboNbTC9em8CpTk0zJ\nYcy4DvhMf0U+d18ZSMbsN9eQlxpzzWDHlWKTVcFrFCpDzcivddoUSStLRw4kOASg\nTFStTaWZQfuA2yFhbonWdgCz/kJzPd+pQZC6KeW5AoGAc+4jKLhDZOYd5+SzleB8\nl0cwRTzdBV0QA+D2gCoNlVpHLgWqOUqTJemj066oSW+ErWdYwKYyhWmEcevBryYH\nqAFYSgLYL7B5vZcVx1KCexvEA1louKfFTmZBcQ3tAbHbPmr475XSxE9SpyDvlRX8\nNllPix5ejOQzrzOJS6yseAw=\n-----END PRIVATE KEY-----\n",
            "client_email": "firebase-adminsdk-jbzpf@myproject-9638b.iam.gserviceaccount.com",
            "client_id": "101667158923658355383",
            "auth_uri": "https://accounts.google.com/o/oauth2/auth",
            "token_uri": "https://oauth2.googleapis.com/token",
            "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
            "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-jbzpf%40myproject-9638b.iam.gserviceaccount.com",
            "universe_domain": "googleapis.com"
          },
        ), scopes,);
    final accessServerKey= client.credentials.accessToken.data;
    return accessServerKey;
  }
}