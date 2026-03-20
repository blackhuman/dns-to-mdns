class DnsToMdns < Formula
  desc "DNS-to-mDNS Proxy - Resolves DNS queries via system mDNS/Bonjour"
  homepage "https://github.com/blackhuman/dns-to-mdns"
  url "https://github.com/blackhuman/dns-to-mdns/releases/download/v0.1.0/dns-to-mdns-macos.tar.gz"
  version "0.1.0"
  license "MIT"

  depends_on macos: :monterey

  def install
    bin.install "dns-to-mdns"
  end

  service do
    run [opt_bin/"dns-to-mdns", "-p", "8053"]
    keep_alive true
    working_dir HOMEBREW_PREFIX
    log_path var/"log/dns-to-mdns.log"
    error_log_path var/"log/dns-to-mdns-error.log"
  end

  test do
    system "#{bin}/dns-to-mdns", "--help"
  end
end
