# イメージをmicroSDに焼く
公式のツールで焼くのが一番楽
https://www.raspberrypi.org/software/

# ssh, wifi(ssid, pass)を最初に設定しておく
(macで焼くとアンマウントされてる時があるので、micro SDを挿し直す)

`ssh` という名前のファイル(中身は空でOK)をboot直下へ
`wpa_supplicant.conf` という名前のファイル(中身は下記の通り、SSID,とPASSWORDを入れる)をboot直下へ

```wpa_supplicant.conf
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=JP

network={
    ssid="INPUT_YOUR_SSID"
    psk="INPUT_YOUR_PASSWORD"
}
```

# ラズパイにsshする
`arp -a | grep -E "(dc:a6:32|b8:27:eb|e4:5f:01)"`
とかするとラズパイらしきIPが調べられる。
macアドレスの候補は常に変わるかもしれないので注意。
真面目に最新を知りたかったら
`curl http://standards-oui.ieee.org/oui/oui.txt | grep "Raspberry"` 
などでmacアドレスの候補調べられる。

`ssh pi@raspberrypi.local` でも大丈夫だったりする
(自分はラズパイがいっぱいあるのでこれはやらないけど)

IPアドレスが分かったら `ssh pi@見つけたIP` でssh可能なはず。
(パスワード認証を求められる、piの初期パスワードは `raspberry` )

# その他の作業をする

```
scp setup.rb pi@見つけたIP:/tmp/
ssh pi@見つけたIP
```

```
sudo -iu root
mv /tmp/setup.rb ./
chdmod +x setup.rb
USERNAME=your_user_name PASSWORD=your_password HOSTNAME=your_host_name GITHUB=your_github_account IP=ip ETH_OR_WLAN=wlan0 PORT=ssh_port FIRST=true setup.rb
```

```
ssh your_user_name@fix_ip -p ssh_port
SECOND=true setup.rb
```

