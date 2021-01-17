#! /usr/bin/ruby

# rootで実行して
USERNAME = ENV.fetch('USERNAME', nil) # 追加するユーザー名
PASSWORD = ENV.fetch('PASSWORD', nil) # パスワード
HOSTNAME = ENV.fetch('HOSTNAME', nil) # 変更するhost名、もともとはraspberrypi
GITHUB = ENV.fetch('GITHUB', nil) # githubの公開鍵を引っ張るのでアカウントを入れる, nilだと鍵を作って標準出力に吐く
IP = ENV.fetch('IP', nil) # 固定するIP
ETH_OR_WLAN = ENV.fetch('ETH_OR_WLAN', nil) # wlan0 eth0
PORT = ENV.fetch('PORT', nil) # 1024-49151, sshのPORT

# ルータのIP、ルーター設定するときに打つIP
ROUTER_IP = ENV.fetch('ROUTER_IP', '192.168.0.1')
# JST
TZ = ENV.fetch('TZ', 'Asia/Tokyo')
# 自動ログインを切ってpiを消す(自動ログインするアカウントを変更する形でも対応可能)
BOOT_MODE = ENV.fetch('BOOT_MODE', 'B1')


if ENV.fetch('FIRST', false) && [USERNAME, PASSWORD, HOSTNAME, IP, ETH_OR_WLAN, PORT, ROUTER_IP, TZ, BOOT_MODE].any?(&:nil?)
  puts("なんかたりないよ！")
  return
end

def wrapper(task_name)
  puts "-start- #{task_name}"
  yield
  puts "--end-- #{task_name}"
end

if ENV.fetch('FIRST', false) # 一周目、アレコレして、piを消せるようにする
  wrapper('# 新しいユーザーを追加してあれこれ') do
    # userを追加
    enc_pass = `echo "#{PASSWORD}" | openssl passwd -1 -stdin`.chomp
    `useradd #{USERNAME} -m -p '#{enc_pass}'`
    # groupを移管
    `groups pi | ruby -e 'puts gets.chomp.split[2..-1].join(",")' | xargs usermod #{USERNAME} -G`

    `mkdir /home/#{USERNAME}/.ssh`
    if GITHUB
      `curl https://github.com/#{GITHUB}.keys > /home/#{USERNAME}/.ssh/authorized_keys`
    else
      `ssh-keygen -q -t ed25519 -f /home/#{USERNAME}/.ssh/id_ed25519 -N ''`
      puts("EXPORT NEW SSH KEY START")
      `cat /home/#{USERNAME}/.ssh/id_ed25519`
      puts("EXPORT NEW SSH KEY  END ")
      `cat /home/#{USERNAME}/.ssh/id_ed25519.pub > /home/#{USERNAME}/.ssh/authorized_keys`
      `rm /home/#{USERNAME}/.ssh/id_ed25519.pub /home/#{USERNAME}/.ssh/id_ed25519`
    end
    `chown -R #{USERNAME}:#{USERNAME} /home/#{USERNAME}/.ssh`
  end

  wrapper('# raspi-config の更新') do
    # piでログインされないように変更
    `raspi-config nonint do_boot_behaviour #{BOOT_MODE}`
    # timezoneをJSTに変更
    `raspi-config nonint do_change_timezone #{TZ}`
    # host名変更
    `raspi-config nonint do_hostname #{HOSTNAME}`
  end

  # sshd_configの更新
  wrapper('# sshd_configの更新') do
    `cp /etc/ssh/sshd_config /tmp/`
    file_lines = File.open('/etc/ssh/sshd_config').read.split("\n")

    # SSHのポート変更、 Password Authでのsshを禁止
    replace_lines = {
      "#Port 22" => "Port #{PORT}",
      "#PubkeyAuthentication yes" => "PubkeyAuthentication yes",
      "#PasswordAuthentication yes" => "PasswordAuthentication no",
    }
    if (file_lines & replace_lines.keys).size != replace_lines.keys.size
      puts "ERROR /etc/ssh/sshd_config SKIP TO NEXT TASK"
      next
    end
    File.open('/etc/ssh/sshd_config', 'w') do |f|
      file_lines.each do |line|
        if replace_lines[line]
          f.puts replace_lines[line]
        else
          f.puts line
        end
      end
    end
    `diff /etc/ssh/sshd_config /tmp/sshd_config`
  end

  wrapper('# /etc/dhcpcd.confの更新') do
    `cp /etc/dhcpcd.conf /tmp`
    `echo "" >> /etc/dhcpcd.conf`
    # すでに追加してたら実行しない
    next if File.open('/etc/dhcpcd.conf').read.split("\n").include?("# SCRIPT ADDED THIS SETTING")

    [
      "# SCRIPT ADDED THIS SETTING",
      "interface #{ETH_OR_WLAN}",
      "static ip_address=#{IP}/24",
      "static routers=#{ROUTER_IP}",
      "static domain_name_servers=#{ROUTER_IP}",
    ].each do |line|
      `echo "#{line}" >> /etc/dhcpcd.conf`
    end
    `echo "" >> /etc/dhcpcd.conf`
  end

  wrapper('# 各種updata') do
    `apt-get update -y`
    `apt-get upgrade -y`
    `SKIP_WARNING=1 rpi-update`
  end

  `reboot now`
elsif ENV.fetch('SECOND', false)
  `userdel pi -r`
end
