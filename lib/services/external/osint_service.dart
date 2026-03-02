import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class OsintService {
  Future<String> runSearch(String target) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final vaultPath = prefs.getString('vault_path');
      if (vaultPath == null) throw Exception("Vault path not found.");

      // 1. Drop the Python script into the mapped volume
      final scriptFile = File('$vaultPath/data/osint/search.py');
      await scriptFile.writeAsString('''
import sys
import time

def scan(target):
    print(f"[*] INITIALIZING GUPTIK OSINT ENGINE...")
    time.sleep(1)
    print(f"[*] Target locked: {target}")
    print(f"[*] Querying databases...\\n")
    time.sleep(2)
    
    # Placeholder for actual tools like Holehe (Emails) or Sherlock (Usernames)
    print("[+] REPORT GENERATED")
    print("--------------------------------------------------")
    print(f"Target      : {target}")
    print("Risk Level  : LOW")
    print("Breaches    : 0 Known Data Leaks Found")
    print("Social      : No public profiles linked instantly")
    print("--------------------------------------------------")
    print("[*] Scan complete.")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        scan(sys.argv[1])
    else:
        print("[-] Error: No target provided.")
''');

      // 2. Execute the script INSIDE the running Python container
      final result = await Process.run(
        'docker',
        ['compose', 'exec', 'osint_python', 'python', 'search.py', target],
        workingDirectory: vaultPath,
      );

      if (result.exitCode != 0) {
        return "Error running script: ${result.stderr}";
      }

      return result.stdout.toString();
    } catch (e) {
      return "Execution Error: $e";
    }
  }
}