file = File.open('/etc/wpa_supplicant/wpa_supplicant.conf').read.split("\n")
ssid = file.find { |str| str.match(/\A\s+ssid="(.+)"\z/)} && $1
psk = file.find { |str| str.match(/\A\s+psk="(.+)"\z/)} && $1
hash = `sudo sh -c 'wpa_passphrase "#{ssid}" "#{psk}"'`.chomp.split("\n").find { |str| str.match(/\A\s+psk=(.+)\z/)} && $1

if hash && file.any? { |line| line.match?(/psk="(.+)"/) }
  File.open('/etc/wpa_supplicant/wpa_supplicant.conf', 'w') do |f|
    file.each do |fi|
      if fi.match?('psk=')
        f.puts(fi.sub(/(".+")/, hash))
      else
        f.puts(fi)
      end
    end
  end
end
