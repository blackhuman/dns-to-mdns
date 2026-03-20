# Homebrew Formula & macOS Service for dns-to-mdns

This directory contains the Homebrew formula and launchctl service configuration for dns-to-mdns.

## Quick Start

### Option 1: Using Homebrew Services (Recommended)

1. **Install the formula:**
   ```bash
   ./install-formula.sh
   ```

2. **Start the service:**
   ```bash
   brew services start dns-to-mdns
   ```

3. **Check status:**
   ```bash
   brew services list
   ```

4. **View logs:**
   ```bash
   tail -f /usr/local/var/log/dns-to-mdns.log
   ```

5. **Stop the service:**
   ```bash
   brew services stop dns-to-mdns
   ```

### Option 2: Manual launchctl Service

1. **Install dns-to-mdns binary** (ensure it's in your PATH)

2. **Run the installation script:**
   ```bash
   ./install-service.sh
   ```

3. **Check status:**
   ```bash
   launchctl list | grep com.dns-to-mdns
   ```

4. **View logs:**
   ```bash
   tail -f /tmp/dns-to-mdns.log
   ```

5. **Stop the service:**
   ```bash
   launchctl unload -w ~/Library/LaunchAgents/com.dns-to-mdns.plist
   ```

## Uninstall

To completely remove the service:

```bash
./uninstall-service.sh
```

## Files

- `dns-to-mdns.rb` - Homebrew formula definition
- `com.dns-to-mdns.plist` - Launchctl service manifest
- `install-formula.sh` - Automated Homebrew installation script
- `install-service.sh` - Manual launchctl service installation script
- `uninstall-service.sh` - Service removal script

## Configuration

### Custom Port

The default port is 8053. To change it:

**For Homebrew:**
Edit the `service do` block in `dns-to-mdns.rb` and change the port number, then reinstall:
```ruby
service do
  run [opt_bin/"dns-to-mdns", "-p", "YOUR_PORT"]
  # ... rest of config
end
```

**For manual service:**
Edit `com.dns-to-mdns.plist` and modify the `ProgramArguments` array:
```xml
<array>
    <string>/path/to/dns-to-mdns</string>
    <string>-p</string>
    <string>YOUR_PORT</string>
</array>
```

Then reload the service.

## Troubleshooting

### Service won't start

1. Check if the binary is installed:
   ```bash
   which dns-to-mdns
   ```

2. Verify the binary works:
   ```bash
   dns-to-mdns --help
   ```

3. Check logs for errors:
   - Homebrew: `/usr/local/var/log/dns-to-mdns-error.log`
   - Manual: `/tmp/dns-to-mdns-error.log`

### Permission issues

If you encounter permission errors, ensure:
- Scripts are executable: `chmod +x *.sh`
- Binary has execute permissions

### Conflicting services

Make sure no other instance of dns-to-mdns is running before starting the service.
