#!/bin/bash
#
# CNAME 設定
#
# - サービス用 URL (FQDN) をサーバーの正式 FQDN (IP アドレスが自動更新される) に割り当てるときに利用
#
# - サービス用 URL の ドメイン (HOSTED_ZONE_ID) はパタメータで指定 (example.com という形で指定しない)
# - サービス用 URL の ホスト名はパタメータで指定
# - サーバーの正式 FQDN はパラメータで指定
#
# ドメイン・ホスト名
# - https://www.cman.jp/network/term/domain/
# CNAME
# - https://jprs.jp/glossary/index.php?ID=0212
# FQDN
# - https://atmarkit.itmedia.co.jp/aig/06network/fqdn.html
#
# - AWS CLI は設定済みの前提
#

# 引数チェック (数のみ)
# - https://bioinfo-dojo.net/2018/02/21/shellscript_args/#toc2
if [ $# != 3 ]; then
    echo >&2 "ERROR: Args count error."
    exit 1
fi

# HOSTED_ZONE_ID の確認方法は↓
# https://us-east-1.console.aws.amazon.com/route53/v2/hostedzones
# aws route53 list-hosted-zones
#HOSTED_ZONE_ID="Z3T2KC0KGMQA00"  # akoba.xyz
HOSTED_ZONE_ID=$1

# サービス用 URL の ホスト名 を引数で渡す
HOSTNAME=$2

# 正式名 (固定)
#CANONICAL_FQDN=rails-prod3.akoba.xyz
CANONICAL_FQDN=$3

# ドメイン取得
DOMAIN=$(aws route53 get-hosted-zone --id $HOSTED_ZONE_ID --query "HostedZone.Name" | tr -d '"')
# エラー処理は甘め。$? は tr コマンドの終了ステータスになる。
echo $?
echo $DOMAIN

# サービス用 URL (FQDN)
FQDN="$HOSTNAME.$DOMAIN"
echo $FQDN

tmpfile=$(mktemp)

cat <<EOF > $tmpfile
{
  "Comment": "UPSERT a record ",
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "$FQDN",
      "Type": "CNAME",
      "TTL": 300,
      "ResourceRecords": [{ "Value": "$CANONICAL_FQDN" }]
    }
  }]
}
EOF

aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --change-batch file://$tmpfile
if [ $? -ne 0 ]; then
    echo >&2 "ERROR: aws route53 command error."
    exit 1
fi
