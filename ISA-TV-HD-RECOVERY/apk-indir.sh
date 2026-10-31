#!/data/data/com.termux/files/usr/bin/bash

REPO="thechampisher/cfglhlslekrlrfovkvlflffk"
DOWNLOAD="$HOME/storage/downloads"

mkdir -p "$DOWNLOAD"

RUN_ID=$(gh run list --repo "$REPO" --workflow android.yml \
  --status success --limit 1 --json databaseId \
  --jq '.[0].databaseId')

if [ -z "$RUN_ID" ] || [ "$RUN_ID" = "null" ]; then
  echo "Başarılı APK derlemesi bulunamadı."
  exit 1
fi

TEMP=$(mktemp -d)

gh run download "$RUN_ID" --repo "$REPO" \
  --name thechampisher-apk --dir "$TEMP" || exit 1

APK=$(find "$TEMP" -name '*.apk' -type f | head -n 1)

if [ -z "$APK" ]; then
  echo "APK dosyası bulunamadı."
  rm -rf "$TEMP"
  exit 1
fi

DEST="$DOWNLOAD/ISA-TV-HD-$RUN_ID.apk"
cp "$APK" "$DEST"
rm -rf "$TEMP"

echo "APK indirildi:"
echo "$DEST"
